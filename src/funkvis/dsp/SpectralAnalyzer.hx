package funkVis.dsp;

import funkVis.AudioClip;
import funkVis.Scaling;

using Lambda;
using Math;
using funkVis.dsp.FFT;

typedef BarObject =
{
	// var posX:Float;
	var freq:Float;
	var freqLo:Float;
	var freqHi:Float;
	var binLo:Int;
	var binHi:Int;
	var ratioLo:Float;
	var ratioHi:Float;
	// var peak:Array<Float>;
	// var hold:Int;
	// var value:Float;
    var recentValues:RecentPeakFinder;
}

typedef BinRatio =
{
    var bin:Float;
    var ratio:Float;
}

typedef Bar =
{
    var value:Float;
    var peak:Float;
}

enum MathType
{
    Round;
    Floor;
    Ceil;
    Cast;
}

/**
 * Helper class that can be used to create visualizations for playing audio streams
 */
class SpectralAnalyzer
{
    var bars:Array<BarObject> = [];
    var audioClip:AudioClip;
	final fftN = 4096;
    var maxDelta:Float;
    var peakHold:Int;
    
    public function new(barCount:Int, audioClip:AudioClip, maxDelta:Float = 0.01, peakHold:Int = 30)
    {
        this.audioClip = audioClip;
        this.maxDelta = maxDelta;
        this.peakHold = peakHold;
        calcBars(barCount, peakHold);
    }

    static inline function clamp(val:Float, min:Float, max:Float):Float
    {
        return val <= min ? min : val >= max ? max : val;
    }

    // For second stage, make this return a second set of recent peaks
    public function getLevels():Array<Bar>
    {
        var levels = new Array<Bar>();
        // var currentEnergy:Float = 0;

		for (i in 0...bars.length)
		{
			var bar = bars[i];
			var freq = bar.freq;
			var binLo = bar.binLo;
			var binHi = bar.binHi;
			var ratioLo = bar.ratioLo;
			var ratioHi = bar.ratioHi;

			// trace(bar);
            var index:Int = audioClip.currentFrame;
            var indices:Array<Int> = [index];

            var halfStride:Int = Std.int(fftN / 2);
            if (index - halfStride > 0) indices.push(index - halfStride);
            if (audioClip.audioBuffer.data.length > index + halfStride) indices.push(index + halfStride);

            var value:Float = 0;
            for (index in indices) {
                var amplitudes = stft(index);
                var interpolated:Float = Math.max(interpolate(amplitudes, binLo, ratioLo), interpolate(amplitudes, binHi, ratioHi));
                value = Math.max(interpolated, value);

                for (j in binLo + 1...binHi) {
                    if (amplitudes[j] > value)
                        value = amplitudes[j];
                }
            }

            value = 20 * LogHelper.log10(value / 32768); // gets converted to decibels
            value = normalizedB(value);

            // value += 100;
			// bar.value = value;
			// currentEnergy += value;

			// using 0 right now for channel
			// if (bar.peak[0] > 0)
			// {
			// 	bar.hold--;
			// 	// if hold is negative, it becomes the "acceleration" for peak drop
			// 	if (bar.hold < 0)
			// 		bar.peak[0] += bar.hold / 200;
			// }

			// if (value >= bar.peak[0])
			// {
			// 	bar.peak[0] = value;
			// 	bar.hold = 30; // set peak hold time to 30 frames (0.5s)
			// }

			// var peak = bar.peak[0];

            // slew limiting
            var lastValue = bar.recentValues.lastValue;
            var delta = clamp(value - lastValue, -1 * maxDelta, maxDelta);
            value = lastValue + delta;
            bar.recentValues.push(value);

            var recentPeak = bar.recentValues.peak;

            levels.push({value: value, peak: recentPeak});

			// energy.val = currentEnergy / (bars.length << 0);
			// if (energy.val >= energy.peak)
			// {
			// 	energy.peak = energy.val;
			// 	energy.hold = 30;
			// }
			// else
			// {
			// 	if (energy.hold > 0)
			// 		energy.hold--;
			// 	else if (energy.peak > 0)
			// 		energy.peak *= (30 + energy.hold--) / 30;
			// }
		}

        trace(levels);
        return levels;
    }

    function calcBars(barCount:Int, peakHold:Int)
    {
        var maxFreq:Float = 14000;
        var minFreq:Float = 30;

        var scaleMin:Float = Scaling.freqScaleBark(minFreq);
        var stride = Scaling.freqScaleBark(maxFreq) - scaleMin;

        for (i in 0...barCount)
        {
            var freqLo:Float = Scaling.invFreqScaleBark(scaleMin + (i * stride) / barCount);
            var freqHi:Float = Scaling.invFreqScaleBark(scaleMin + ((i+1) * stride) / barCount);
            var freq:Float = (freqHi + freqLo) / 2.0;

            var binAndRatioLo = calcRatio(Std.int(freqLo));
            var binAndRatioHi = calcRatio(Std.int(freqHi));

            bars.push({
                freq: freq,
                freqLo: freqLo,
                freqHi: freqHi,
                binLo: Std.int(binAndRatioLo.bin),
                binHi: Std.int(binAndRatioHi.bin),
                ratioLo: binAndRatioLo.ratio,
                ratioHi: binAndRatioHi.ratio,
                // peak: [0, 0],
                // hold: 0,
                recentValues: new RecentPeakFinder(peakHold)
                // value: 0
            });
        }
    }

    function calcRatio(freq):BinRatio
    {
        var bin = freqToBin(freq, Floor); // find closest FFT bin
        var lower = binToFreq(bin);
        var upper = binToFreq(bin + 1);
        var ratio = LogHelper.log2(freq / lower) / LogHelper.log2(upper / lower);
        return {bin: bin, ratio: ratio};
    }

    function freqToBin(freq, mathType:MathType = Round):Int
    {
        var bin = freq * fftN / audioClip.audioBuffer.sampleRate;
        return switch (mathType) {
            case Round: Math.round(bin);
            case Floor: Math.floor(bin);
            case Ceil: Math.ceil(bin);
            case Cast: Std.int(bin);
        }
    }

    function binToFreq(bin)
		return bin * audioClip.audioBuffer.sampleRate / fftN;

	// function getAmplitudes(ampIndex:Int):Array<Float>
	// {
	// 	// var index:Int = audioClip.currentFrame;
	// 	return [s for (k => s in stft(ampIndex, fftN))];
	// }

    // TODO pre-calculate this as an array and do simd array multiplication
    function blackmanWindow(n:Int)
		return 0.42 - 0.50 * Math.cos(2 * Math.PI * n / (fftN - 1)) + 0.08 * Math.cos(4 * Math.PI * n / (fftN - 1));

    // computes an STFT frame, starting at the given index within input samples
	function stft(c:Int):Array<Float>
    {
        return [
            for (n in 0...fftN)
                c + n < Std.int(audioClip.audioBuffer.data.length) ? audioClip.audioBuffer.data[Std.int(c + n)] : 0.0
        ].mapi((n, x) -> x * blackmanWindow(n)).rfft().map(z -> z.scale(2.0 / fftN).real);
    }

    function interpolate(amplitudes:Array<Float>, bin:Int, ratio:Float)
    {
        var value = amplitudes[bin] + (bin < amplitudes.length - 1 ? (amplitudes[bin + 1] - amplitudes[bin]) * ratio : 0);
        return Math.isNaN(value) ? 0 : value;
    }

    function normalizedB(value:Float)
    {
        var maxValue = -30;
        var minValue = -65;

        // return FlxMath.remapToRange(value, minValue, maxValue, 0, 1);
        return clamp((value - minValue) / (maxValue - minValue), 0, 1);
    }
}