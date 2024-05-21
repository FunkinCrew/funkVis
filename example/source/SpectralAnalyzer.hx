package;

import flixel.FlxG;
import flixel.math.FlxMath;
import grig.audio.FFTVisualization;
import lime.media.AudioSource;

using grig.audio.lime.UInt8ArrayTools;

class SpectralAnalyzer
{
    public var currentFrame(get, never):Int;
	public var numChannels(get, never):Int;
	private var audioSource:lime.media.AudioSource;
	private static final n:Int = 512;
	private var vis = new FFTVisualization();
	private var barCount:Int;

	public function new(audioSource:lime.media.AudioSource, barCount:Int)
	{
		this.audioSource = audioSource;
		this.barCount = barCount;
		// this.audioBuffer = new AudioBuffer(data, audioSource.buffer.sampleRate);
	}

	public function getLevels():Array<Float>
	{
		var signal = new Array<Float>();
		signal.resize(n);

		var wantedLength = n * Std.int(audioSource.buffer.bitsPerSample / 8) * numChannels;
		var startFrame = currentFrame;
		var segment = audioSource.buffer.data.subarray(startFrame, Visualizer.min(startFrame + wantedLength, audioSource.buffer.data.length - startFrame));
		var signal = segment.toInterleaved(audioSource.buffer.bitsPerSample);

		if (numChannels > 1) {
			var mixed = new Array<Float>();
			mixed.resize(Std.int(signal.length / numChannels));
			for (i in 0...mixed.length) {
				mixed[i] = 0.0;
				for (c in 0...numChannels) {
					mixed[i] += signal[i*numChannels+c];
				}
			}
			signal = mixed;
		}

		// trace(signal);

		var range = 256;
		var bars = vis.makeLogGraph(signal, barCount, 40, range);

		return [for (bar in bars) bar / range];
	}

	private function get_currentFrame():Int
	{
		return Std.int(FlxMath.remapToRange(FlxG.sound.music.time, 0, FlxG.sound.music.length, 0, audioSource.buffer.data.length / 2));
	}

	private inline function get_numChannels():Int
	{
		return audioSource.buffer.channels;
	}
}