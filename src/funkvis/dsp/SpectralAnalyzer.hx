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
	public var fftN(default, set):Int = 4096;
    var maxDelta:Float;
    var peakHold:Int;
    var blackmanWindow = new Array<Float>();
    // public var overlap:Float = 0.1;
    public var smoothing:Float = 0.5;
    public var minFreq:Float = 30;
    public var maxFreq:Float = 20000;
    public var minDb:Float = -80;
    public var maxDb:Float = -20;

    function set_fftN(value:Int):Int
    {
        return FFT.nextPow2(value);
    }
    
    public function new(barCount:Int, audioClip:AudioClip, maxDelta:Float = 0.01, peakHold:Int = 30)
    {
        this.audioClip = audioClip;
        this.maxDelta = maxDelta;
        this.peakHold = peakHold;
        maxFreq = Math.min(maxFreq, audioClip.audioBuffer.sampleRate / 2);

        calcBars(barCount, peakHold);

        resizeBlackmanWindow(fftN);

    }

    function resizeBlackmanWindow(size:Int)
    {
        blackmanWindow.resize(size);
        for (i in 0...size) {
            blackmanWindow[i] = calculateFlatTopWindow(i, size);
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
    public function getLevels(debugMode:Bool, ?elapsed:Float):Array<Bar>
    {
        var levels = new Array<Bar>();

        var index:Int = audioClip.currentFrame;
        var indices:Array<Int> = [index];
        var halfStride:Int = Std.int(fftN / 2);
        var stride:Int = Std.int(fftN * smoothing);
        // if (index - halfStride > 0) indices = [index - halfStride];
        if (audioClip.audioBuffer.data.length > index + halfStride) indices = [index + stride];
        var amplitudesSet = new Array<Array<Float>>();

        var prevLevels:Array<Float> = previousSTFT;
        var sameAsPrev:Bool = false;

        for (index in indices) {
            var amplitudes = stft(index, elapsed);
            // sameAsPrev = amplitudes == prevLevels;
            if (debugMode) {
                writeCSV('amplitudes$index.csv', amplitudes);
            }
            amplitudesSet.push(amplitudes);
        }

        // if (sameAsPrev) {
        //     var smoothedAmplitudes = applyEMASmoothing(prevSmoothedSTFT, previousSTFT, smoothing);
        //     amplitudesSet = [smoothedAmplitudes];
        //     prevSmoothedSTFT = smoothedAmplitudes;
        // }

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


            value = 20 * LogHelper.log10(value); // gets converted to decibels
            value = normalizedB(value);

            // slew limiting
            var lastValue = bar.recentValues.lastValue;
            var delta = clamp(value - lastValue, -1 * maxDelta, maxDelta);
            // value = lastValue + delta;
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
        var scaleMin:Float = Scaling.freqScaleLog(minFreq);
        var stride = Scaling.freqScaleLog(maxFreq) - scaleMin;

        for (i in 0...barCount)
        {
            var freqLo:Float = Scaling.invFreqScaleLog(scaleMin + (i * stride) / barCount);
            var freqHi:Float = Scaling.invFreqScaleLog(scaleMin + ((i+1) * stride) / barCount);
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

    static function calculateFlatTopWindow(n:Int, fftN:Int):Float {
        var A0:Float = 1.0;
        var A1:Float = 1.93;
        var A2:Float = 1.29;
        var A3:Float = 0.388;
        var A4:Float = 0.032;
        var factor:Float = Math.PI * n / (fftN - 1);
    
        return A0
               - A1 * Math.cos(2 * factor)
               + A2 * Math.cos(4 * factor)
               - A3 * Math.cos(6 * factor)
               + A4 * Math.cos(8 * factor);
    }

    function freqRangeFilter(i:Int, s:Float)
    {
        final f = binToFreq(i);
        final binSizeHz = audioClip.audioBuffer.sampleRate / fftN;
        return f > minFreq - binSizeHz && f < maxFreq + binSizeHz ? s : Math.NEGATIVE_INFINITY;
    }

    function average(input:Array<Float>):Float
    {
        return input.fold((a, b) -> return a + b, 0) / input.length;
    }

    var currentAudioBlock:Int = 0;
    var previousSTFT:Array<Float> = [0.0];
    var prevSmoothedSTFT:Array<Float> = [0.0];
    // computes an STFT frame, starting at the given index within input samples
	function stft(c:Int, elapsed:Float):Array<Float>
    {   
        var windowSize:Int = Std.int(audioClip.audioBuffer.sampleRate * elapsed);
        if (c > currentAudioBlock * windowSize)
            currentAudioBlock++;
        else
            return previousSTFT;
        
        resizeBlackmanWindow(windowSize);
        var updatedSTFT = [
            for (n in 0...windowSize)
                c + (n * 2) < Std.int(audioClip.audioBuffer.data.length) ? audioClip.audioBuffer.data[Std.int(c + (n * 2))] / 65536.0 : 0 ]
                .mapi((n, x) -> x * blackmanWindow[n])
                .rfft()
                .mapi((ind, z) -> {
                    // do this in one loop/map, instead of two
                    var smoothingInput = freqRangeFilter(ind, z.scale(1 / audioClip.audioBuffer.sampleRate).magnitude);
                    var previousValue = (ind < previousSTFT.length) ? previousSTFT[ind] : 0.0;

                    return doEMASmooth(smoothingInput, previousValue, smoothing);
                });
            // var smoothedSTFT:Array<Float> = applyEMASmoothing(previousSTFT, updatedSTFT, smoothing);
            
        previousSTFT = updatedSTFT;
        return updatedSTFT;
    }

    function interpolate(amplitudes:Array<Float>, bin:Int, ratio:Float)
    {
        var value = amplitudes[bin] + (bin < amplitudes.length - 1 ? (amplitudes[bin + 1] - amplitudes[bin]) * ratio : Math.NEGATIVE_INFINITY);
        return Math.isNaN(value) ? Math.NEGATIVE_INFINITY : value;
    }

    public static function applyEMASmoothing(previousSTFT:Array<Float>, updatedSTFT:Array<Float>, smoothingFactor:Float):Array<Float> {
        var smoothedSTFT = new Array<Float>();
    
        for (i in 0...updatedSTFT.length) {
            var previousValue = (i < previousSTFT.length) ? previousSTFT[i] : 0.0;
            var currentValue = updatedSTFT[i];
    
            var smoothedValue = doEMASmooth(currentValue, previousValue, smoothingFactor);
            smoothedSTFT.push(Math.isNaN(smoothedValue) ? 0.0 : smoothedValue);
        }
    
        return smoothedSTFT;
    }

    // Runs an EMA smooth on a single input value, using a single previous input
    public static function doEMASmooth(input:Float, previousInput:Float, smoothingFactor:Float):Float
    {
        if (smoothingFactor < 0 || smoothingFactor > 1) {
            clamp(smoothingFactor, 0, 1);
        }
        return smoothingFactor * previousInput + (1 - smoothingFactor) * Math.abs(input);
    }
    

    function normalizedB(value:Float)
    {
        var maxValue = maxDb;
        var minValue = minDb;

        // return FlxMath.remapToRange(value, minValue, maxValue, 0, 1);
        return clamp((value - minValue) / (maxValue - minValue), 0, 1);
    }
}
