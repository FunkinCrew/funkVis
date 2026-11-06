package funkin.vis.dsp;

import haxe.ds.Vector;

import lime.media.AudioSource;
#if (lime_cffi && lime_miniaudio && !macro)
import lime.media.miniaudio.MAAudioRingBuffer;
import lime.media.miniaudio.MAAudioRingBufferConfig;
import lime.media.miniaudio.MAHelpers;
import lime.utils.Bytes;
import lime.utils.Float32Array;
#elseif (js && html5 && lime_howlerjs)
import js.html.audio.AnalyserNode;
import js.html.audio.AudioBufferSourceNode;
import js.html.audio.GainNode;
import js.lib.Float32Array;

import lime.media.howlerjs.Howl;
import lime.media.howlerjs.Howler;
#end

/** Analyzes the audio of an `AudioSource` and turns it into spectrum bars. */
class SpectralAnalyzer
{
	#if (lime_cffi && lime_miniaudio && !macro)
	@:noCompletion
	private static final RING_BUFFER_FRAME_MULTIPLIER:Int = 4;
	#end

	@:noCompletion
	private static final LOG_GRAPH_RANGE:Int = 16;

	/** Number of samples per analysis frame. Must be a power of two and at least 4. */
	public var fftN(default, set):Int = 2048;

	/** Lower end of the decibel range. */
	public var minDb:Float = -70;

	/** Upper end of the decibel range. */
	public var maxDb:Float = -20;

	/** Lowest frequency shown by the first bar, in Hz. */
	public var minFreq:Float = 50;

	/** Highest frequency shown by the last bar, in Hz. */
	public var maxFreq:Float = 22000;

	/** Keeps the last levels while the audio isn't playing. */
	public var holdLevels:Bool = true;

	@:noCompletion
	private var audioSource:AudioSource;

	@:noCompletion
	private var barCount:Int;

	@:noCompletion
	private var maxDelta:Float;

	@:noCompletion
	private var peakHold:Int;

	@:noCompletion
	private var fft:FFT;

	@:noCompletion
	private var vis:Visualization;

	@:noCompletion
	private var barHistories:Array<RecentPeakFinder>;

	@:noCompletion
	private var samples:Vector<Float>;

	@:noCompletion
	private var sampleRate:Float = 44100;

	@:noCompletion
	private var spectrumStale:Bool = true;

	@:noCompletion
	private var silenced:Bool = false;

	@:noCompletion
	private var logGraphCache:Array<Int> = [];

	@:noCompletion
	private var levelsCache:Array<Bar> = [];

	#if (lime_cffi && lime_miniaudio && !macro)
	@:noCompletion
	private var ringBufferConfig:MAAudioRingBufferConfig;

	@:noCompletion
	private var ringBuffer:MAAudioRingBuffer;

	@:noCompletion
	private var readBuffer:Float32Array;

	@:noCompletion
	private var monoCache:Vector<Float>;

	@:noCompletion
	private var writeIndex:Int = 0;
	#elseif (js && html5 && lime_howlerjs)
	@:noCompletion
	private var howl:Howl;

	@:noCompletion
	private var analyzer:AnalyserNode;

	@:noCompletion
	private var timeBuffer:Float32Array;
	#end

	/**
	 * Initializes a SpectralAnalyzer object.
	 * 
	 * @param audioSource The audio source to analyze.
	 * @param barCount The number of bars to produce.
	 * @param maxDelta The maximum amount a bar's value can change per update. Use `0` to disable the limit.
	 * @param peakHold The number of recent updates each bar's peak is tracked over.
	 */
	public function new(audioSource:AudioSource, barCount:Int, maxDelta:Float = 0.01, peakHold:Int = 30)
	{
		if (audioSource == null || audioSource.buffer == null)
		{
			throw "The audio source needs to have an valid audio buffer";
		}

		this.audioSource = audioSource;
		this.barCount = barCount;
		this.maxDelta = maxDelta;
		this.peakHold = peakHold;

		vis = new Visualization();

		barHistories = [];

		#if (js && html5 && lime_howlerjs)
		howl = @:privateAccess audioSource.buffer.__srcHowl;

		sampleRate = Howler.ctx.sampleRate;

		analyzer = new AnalyserNode(Howler.ctx);

		if (audioSource.playing)
		{
			connectAnalyzer();
		}

		howl.on("play", connectAnalyzer);
		#end

		rebuild();

		calcBars(barCount);
	}

	/**
	 * Gets the current level of every bar.
	 * 
	 * @param levels (Optional) The array to fill. When omitted, an internal array is reused between calls.
	 * @return The bars, ordered from the lowest frequency to the highest.
	 */
	public function getLevels(?levels:Array<Bar>):Array<Bar>
	{
		return computeLevels(levels ?? levelsCache);
	}

	/** Frees the audio resources used by the analyzer. */
	public function dispose():Void
	{
		#if (lime_cffi && lime_miniaudio && !macro)
		if (ringBuffer != null)
		{
			audioSource.removePreRingBuffer(ringBuffer);
			ringBuffer.uninit();
			ringBuffer = null;
		}

		readBuffer = null;
		#elseif (js && html5 && lime_howlerjs)
		if (howl != null)
		{
			howl.off("play", connectAnalyzer);
		}

		if (analyzer != null)
		{
			analyzer.disconnect();
			analyzer = null;
		}

		timeBuffer = null;
		#end
	}

	@:noCompletion
	private function computeLevels(levels:Array<Bar>):Array<Bar>
	{
		#if (lime_cffi && lime_miniaudio && !macro)
		if (ringBuffer == null)
		{
			return levels;
		}
		#elseif (js && html5 && lime_howlerjs)
		if (analyzer == null)
		{
			return levels;
		}
		#end

		captureSamples();

		if (spectrumStale)
		{
			final binHz:Float = sampleRate / fftN;

			logGraphCache = vis.makeLogGraph(fft.calcFreq(samples), barCount + 1, Std.int(maxDb - minDb), LOG_GRAPH_RANGE, logGraphCache, minFreq / binHz,
				maxFreq / binHz);

			spectrumStale = false;
		}

		for (i in 0...logGraphCache.length - 1)
		{
			var history:RecentPeakFinder = barHistories[i] ??= new RecentPeakFinder(peakHold);

			var value:Float = logGraphCache[i] / LOG_GRAPH_RANGE;

			if (maxDelta > 0)
			{
				final diff:Float = value - history.lastValue;

				if (diff < -maxDelta)
				{
					value = history.lastValue - maxDelta;
				}
				else if (diff > maxDelta)
				{
					value = history.lastValue + maxDelta;
				}
			}

			history.push(value);

			var bar:Bar = levels[i];

			if (bar != null)
			{
				bar.value = value;
				bar.peak = history.peak;
			}
			else
			{
				levels[i] = {value: value, peak: history.peak};
			}
		}

		return levels;
	}

	@:noCompletion
	private function captureSamples():Void
	{
		#if (lime_cffi && lime_miniaudio && !macro)
		final availableFrames:Int = ringBuffer.get_length_in_pcm_frames();

		if (availableFrames <= 0)
		{
			if (holdLevels || silenced || audioSource.playing)
			{
				return;
			}

			clearSamples();

			return;
		}

		silenced = false;

		final configSize:Int = ringBufferConfig.sizeInFrames;

		final framesToRead:Int = availableFrames > configSize ? configSize : availableFrames;

		ringBuffer.read_pcm_frames(#if cpp cpp.Pointer.ofArray(readBuffer.buffer.getData()) #else null #end, framesToRead);

		pushFrames(framesToRead);

		reorderRingBufferToSamples();

		spectrumStale = true;
		#elseif (js && html5 && lime_howlerjs)
		if (!audioSource.playing)
		{
			if (holdLevels || silenced)
			{
				return;
			}

			clearSamples();

			return;
		}

		silenced = false;

		analyzer.getFloatTimeDomainData(timeBuffer);

		final src:Float32Array = timeBuffer;
		final dst:Vector<Float> = samples;

		for (i in 0...fftN)
		{
			dst[i] = src[i];
		}

		spectrumStale = true;
		#end
	}

	@:noCompletion
	private function clearSamples():Void
	{
		#if (lime_cffi && lime_miniaudio && !macro)
		for (i in 0...fftN)
		{
			monoCache[i] = 0;
		}

		reorderRingBufferToSamples();
		#elseif (js && html5 && lime_howlerjs)
		for (i in 0...fftN)
		{
			samples[i] = 0;
		}
		#end

		silenced = true;

		spectrumStale = true;
	}

	@:noCompletion
	private function rebuild():Void
	{
		fft = new FFT(fftN);
		samples = new Vector<Float>(fftN, 0);
		spectrumStale = true;

		#if (lime_cffi && lime_miniaudio && !macro)
		createRingBuffer();
		#elseif (js && html5 && lime_howlerjs)
		analyzer.fftSize = fftN;
		timeBuffer = new Float32Array(fftN);
		#end
	}

	@:noCompletion
	private function calcBars(barCount:Int):Void
	{
		if (barCount > barHistories.length)
		{
			barHistories.resize(barCount);
		}

		for (i in 0...barCount)
		{
			barHistories[i] ??= new RecentPeakFinder(peakHold);
		}
	}

	#if (lime_cffi && lime_miniaudio && !macro)
	@:noCompletion
	private function createRingBuffer():Void
	{
		if (audioSource != null)
		{
			if (ringBuffer != null)
			{
				audioSource.removePreRingBuffer(ringBuffer);
				ringBuffer.uninit();
				ringBuffer = null;
			}

			sampleRate = audioSource.buffer.sampleRate;

			final sizeInFrames:Int = fftN * RING_BUFFER_FRAME_MULTIPLIER;

			ringBufferConfig = MAAudioRingBufferConfig.init(F32, audioSource.buffer.channels, audioSource.buffer.sampleRate, sizeInFrames);
			ringBuffer = MAAudioRingBuffer.init(ringBufferConfig);
			readBuffer = new Float32Array(Bytes.alloc(ringBufferConfig.sizeInFrames * ringBufferConfig.channels * MAHelpers.get_bytes_per_sample(F32)));
			monoCache = new Vector<Float>(fftN, 0);
			writeIndex = 0;

			audioSource.addPreRingBuffer(ringBuffer);
		}
	}

	@:noCompletion
	private function pushFrames(frames:Int):Void
	{
		final take:Int = frames > fftN ? fftN : frames;
		final channels:Int = ringBufferConfig.channels;
		final src:Float32Array = readBuffer;
		final dst:Vector<Float> = monoCache;
		final size:Int = fftN;

		var index:Int = (frames - take) * channels;
		var w:Int = writeIndex;

		if (channels == 2)
		{
			for (_ in 0...take)
			{
				dst[w] = (src[index] + src[index + 1]) * 0.5;

				index += 2;

				if (++w == size)
					w = 0;
			}
		}
		else if (channels == 1)
		{
			for (_ in 0...take)
			{
				dst[w] = src[index];

				index++;

				if (++w == size)
					w = 0;
			}
		}
		else
		{
			for (_ in 0...take)
			{
				var mixed:Float = 0;

				for (c in 0...channels)
				{
					mixed += src[index + c];
				}

				dst[w] = mixed / channels;

				index += channels;

				if (++w == size)
					w = 0;
			}
		}

		writeIndex = w;
	}

	@:noCompletion
	private function reorderRingBufferToSamples():Void
	{
		final tail:Int = fftN - writeIndex;

		Vector.blit(monoCache, writeIndex, samples, 0, tail);

		Vector.blit(monoCache, 0, samples, tail, writeIndex);
	}
	#elseif (js && html5 && lime_howlerjs)
	@:noCompletion
	private function connectAnalyzer():Void
	{
		if (analyzer != null)
		{
			final sound:Dynamic = untyped howl._soundById(audioSource.__backend.handle);

			if (sound != null && sound._node != null)
			{
				final gainNode:GainNode = untyped sound._node;

				if (gainNode != null)
				{
					final bufferSource:AudioBufferSourceNode = untyped gainNode.bufferSource;

					if (bufferSource != null)
					{
						bufferSource.connect(analyzer);
					}
					else
					{
						gainNode.connect(analyzer);
					}
				}
			}
		}
	}
	#end

	@:noCompletion
	private function set_fftN(value:Int):Int
	{
		if (value == fftN)
		{
			return value;
		}

		fftN = value;

		rebuild();

		return value;
	}
}
