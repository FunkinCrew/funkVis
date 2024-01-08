package funkVis.dsp;

import funkVis.AudioClip;
import funkVis.Scaling;

using Lambda;
using Math;
using funkVis.dsp.FFT;

typedef BarObject =
{
	var binLo:Int;
	var binHi:Int;
	var ratio:Float;
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
    var blackmanWindow = new Array<Float>();
    var minFreq:Float = 30;
    var maxFreq:Float = 14000;
    
    public function new(barCount:Int, audioClip:AudioClip, maxDelta:Float = 0.01, peakHold:Int = 30)
    {
        this.audioClip = audioClip;
        this.maxDelta = maxDelta;
        this.peakHold = peakHold;
        maxFreq = Math.min(maxFreq, audioClip.audioBuffer.sampleRate / 2);

        calcBars(barCount, peakHold);

        blackmanWindow.resize(fftN);
        for (i in 0...fftN) {
            blackmanWindow[i] = calculateBlackmanWindow(i, fftN);
        }
    }

    static inline function clamp(val:Float, min:Float, max:Float):Float
    {
        return val <= min ? min : val >= max ? max : val;
    }

    private static function writeCSV(name:String, data:Array<Float>)
    {
        var output = sys.io.File.write(name, false);
        output.writeString(data.join("\n"));
        output.close();
    }

    // For second stage, make this return a second set of recent peaks
    public function getLevels(debugMode:Bool):Array<Bar>
    {
        var levels = new Array<Bar>();

        var index:Int = audioClip.currentFrame;
        var indices:Array<Int> = [index];
        var halfStride:Int = Std.int(fftN / 2);
        if (index - halfStride > 0) indices.push(index - halfStride);
        if (audioClip.audioBuffer.data.length > index + halfStride) indices.push(index + halfStride);
        var amplitudesSet = new Array<Array<Float>>();

        for (index in indices) {
            var amplitudes = stft(index);
            if (debugMode) {
                writeCSV('amplitudes$index.csv', amplitudes);
            }
            amplitudesSet.push(amplitudes);
        }

        for (i in 0...bars.length) {
            var bar = bars[i];
            var binLo = bar.binLo;
            var binHi = bar.binHi;
            var ratio = bar.ratio;

            var value:Float = Math.NEGATIVE_INFINITY;

            for (amplitudes in amplitudesSet) {
                for (j in binLo...(binHi+1)) {
                    // value = Math.max(value, amplitudes[binLo+i]);
                    value = Math.max(value, interpolate(amplitudes, binLo+i, ratio));
                }
            }

            value = 10 * LogHelper.log10(value); // gets converted to decibels
            value = normalizedB(value);

            // slew limiting
            var lastValue = bar.recentValues.lastValue;
            var delta = clamp(value - lastValue, -1 * maxDelta, maxDelta);
            value = lastValue + delta;
            bar.recentValues.push(value);

            var recentPeak = bar.recentValues.peak;

            levels.push({value: value, peak: recentPeak});
        }

        if (debugMode) {
            writeCSV('levels.csv', [for (level in levels) level.value]);
        }

        return levels;
    }

    function calcBars(barCount:Int, peakHold:Int)
    {
        var scaleMin:Float = Scaling.freqScaleBark(minFreq);
        var stride = Scaling.freqScaleBark(maxFreq) - scaleMin;

        for (i in 0...barCount)
        {
            var freqLo:Float = Scaling.invFreqScaleBark(scaleMin + (i * stride) / barCount);
            var freqHi:Float = Scaling.invFreqScaleBark(scaleMin + ((i+1) * stride) / barCount);
            var freq:Float = (freqHi + freqLo) / 2.0;

            var binLo = freqToBin(freqLo, Floor);
            var binHi = freqToBin(freqHi, Floor);

            var ratio = LogHelper.log2(freq / freqLo) / LogHelper.log2(freqHi / freqLo);

            bars.push({
                binLo: binLo,
                binHi: binHi,
                ratio: ratio,
                recentValues: new RecentPeakFinder(peakHold)
            });
        }

        trace(bars);
        // trace([for (bar in bars) {binHi: bar.binHi, binLo: bar.binLo}]);
    }

    function freqToBin(freq:Float, mathType:MathType = Round):Int
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

    static function calculateBlackmanWindow(n:Int, fftN:Int)
		return 0.42 - 0.50 * Math.cos(2 * Math.PI * n / (fftN - 1)) + 0.08 * Math.cos(4 * Math.PI * n / (fftN - 1));

    function freqRangeFilter(i:Int, s:Float)
    {
        final f = binToFreq(i);
        final binSizeHz = audioClip.audioBuffer.sampleRate / fftN;
        return f > minFreq - binSizeHz && f < maxFreq + binSizeHz ? s : Math.NEGATIVE_INFINITY;
    }

    // computes an STFT frame, starting at the given index within input samples
	function stft(c:Int):Array<Float>
    {
        return [
            for (n in 0...fftN)
                c + n < Std.int(audioClip.audioBuffer.data.length) ? audioClip.audioBuffer.data[Std.int(c + n)] / 65536.0 : 0
        ].mapi((n, x) -> x * blackmanWindow[n]).rfft().map(z -> z.scale(1 / audioClip.audioBuffer.sampleRate).magnitude).mapi(freqRangeFilter);
    }

    function interpolate(amplitudes:Array<Float>, bin:Int, ratio:Float)
    {
        var value = amplitudes[bin] + (bin < amplitudes.length - 1 ? (amplitudes[bin + 1] - amplitudes[bin]) * ratio : Math.NEGATIVE_INFINITY);
        return Math.isNaN(value) ? Math.NEGATIVE_INFINITY : value;
    }

    function normalizedB(value:Float)
    {
        var maxValue = -20;
        var minValue = -40;

        // return FlxMath.remapToRange(value, minValue, maxValue, 0, 1);
        return clamp((value - minValue) / (maxValue - minValue), 0, 1);
    }
}