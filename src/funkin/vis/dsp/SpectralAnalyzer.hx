package funkin.vis.dsp;

import flixel.FlxG;
import flixel.math.FlxMath;
import grig.audio.FFT;
import grig.audio.FFTVisualization;
import lime.media.AudioSource;

using grig.audio.lime.UInt8ArrayTools;

typedef Bar =
{
    var value:Float;
    var peak:Float;
}

class SpectralAnalyzer
{
    public var currentFrame(get, never):Int;
	public var numChannels(get, never):Int;
	private var audioSource:lime.media.AudioSource;
	private static final fftN:Int = 512;
    private var fft = new FFT(fftN);
	private var vis = new FFTVisualization();
	private var barCount:Int;
    private var barHistories = new Array<RecentPeakFinder>();
    private var maxDelta:Float;
    private var peakHold:Int;
    private var blackmanWindow = new Array<Float>();

	public function new(audioSource:lime.media.AudioSource, barCount:Int, maxDelta:Float = 0.01, peakHold:Int = 30)
	{
		this.audioSource = audioSource;
		this.barCount = barCount;
        this.maxDelta = maxDelta;
        this.peakHold = peakHold;

        blackmanWindow.resize(fftN);
        for (i in 0...fftN) {
            blackmanWindow[i] = calculateBlackmanWindow(i, fftN);
        }
	}

	public function getLevels():Array<Bar>
	{
        var numOctets = Std.int(audioSource.buffer.bitsPerSample / 8);
		var wantedLength = fftN * numOctets * numChannels;
		var startFrame = currentFrame;
        var offset = startFrame % numOctets;
        if (offset != 0) {
            startFrame -= offset;
        }
		var segment = audioSource.buffer.data.subarray(startFrame, min(startFrame + wantedLength, audioSource.buffer.data.length));
		var signal = segment.toInterleaved(audioSource.buffer.bitsPerSample);

		if (numChannels > 1) {
			var mixed = new Array<Float>();
			mixed.resize(Std.int(signal.length / numChannels));
			for (i in 0...mixed.length) {
				mixed[i] = 0.0;
				for (c in 0...numChannels) {
					mixed[i] += signal[i*numChannels+c];
                    break;
				}
                mixed[i] *= blackmanWindow[i];
			}
			signal = mixed;
		}

		// trace(signal);

		var range = 16;
        var freqs = fft.calcFreq(signal);
		var bars = vis.makeLogGraph(freqs, barCount, 40, range);

        if (bars.length > barHistories.length) {
            barHistories.resize(bars.length);
        }

        var levels = new Array<Bar>();
        levels.resize(bars.length);
        for (i in 0...bars.length) {
            if (barHistories[i] == null) barHistories[i] = new RecentPeakFinder();
            var recentValues = barHistories[i];
            var value = bars[i] / range;

            // slew limiting
            var lastValue = recentValues.lastValue;
            if (maxDelta > 0.0) {
                var delta = clamp(value - lastValue, -1 * maxDelta, maxDelta);
                value = lastValue + delta;
            }
            recentValues.push(value);

            var recentPeak = recentValues.peak;

            levels[i] = {value: value, peak: recentPeak};
        }
        return levels;
	}

	private function get_currentFrame():Int
	{
		return Std.int(FlxMath.remapToRange(FlxG.sound.music.time, 0, FlxG.sound.music.length, 0, audioSource.buffer.data.length));
	}

	private inline function get_numChannels():Int
	{
		return audioSource.buffer.channels;
	}

    @:generic
    static inline function clamp<T:Float>(val:T, min:T, max:T):T
    {
        return val <= min ? min : val >= max ? max : val;
    }

    static function calculateBlackmanWindow(n:Int, fftN:Int)
    {
		return 0.42 - 0.50 * Math.cos(2 * Math.PI * n / (fftN - 1)) + 0.08 * Math.cos(4 * Math.PI * n / (fftN - 1));
    }

    @:generic
    static public inline function min<T:Float>(x:T, y:T):T
    {
        return x > y ? y : x;
    }
}
