package funkVis.dsp;

import funkVis.AudioBuffer;
import funkVis.Scaling;

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
	var peak:Array<Float>;
	var hold:Int;
	var value:Float;
}

/**
 * Helper class that can be used to create visualizations for playing audio streams
 */
class SpectralAnalyzer
{
    var bars:Array<BarObject> = [];
    var buffer:AudioBuffer;
	final fftN = 4096;
    
    public function new(barCount:Int, buffer:AudioBuffer)
    {
        calcBars(barCount);
        this.buffer = buffer;
    }

    function calcBars(barCount:Int)
    {
        // var barWidth:Float = FlxG.width / barCount;

        // var initX:Float = 0;
        var maxFreq:Float = 14000;
        var minFreq:Float = 30;

        var scaleMin:Float = Scaling.freqScaleBark(minFreq);
        // var unitWidth = FlxG.width / (Scaling.freqScaleBark(maxFreq) - scaleMin);
        var stride = Scaling.freqScaleBark(maxFreq) - scaleMin;

        // var posX:Float = 0;
        for (i in 0...barCount)
        {
            // i / barCount * (Scaling.freqScaleBark(maxFreq) - scaleMin)
            var freqLo:Float = Scaling.invFreqScaleBark(scaleMin + i * stride);
            var freqHi:Float = Scaling.invFreqScaleBark(scaleMin + (i+1) * stride);
            var freq:Float = (freqHi + freqLo) / 2.0;

            // var freqLo:Float = Scaling.invFreqScaleBark(scaleMin + posX / unitWidth);
            // var freq:Float = Scaling.invFreqScaleBark(scaleMin + (posX + barWidth / 2) / unitWidth);
            // var freqHi:Float = Scaling.invFreqScaleBark(scaleMin + (posX + barWidth) / unitWidth);

            var binAndRatioLo:Array<Float> = calcRatio(Std.int(freqLo));
            var binAndRatioHi:Array<Float> = calcRatio(Std.int(freqHi));

            bars.push({
                // posX: initX + posX,
                freq: freq,
                freqLo: freqLo,
                freqHi: freqHi,
                binLo: Std.int(binAndRatioLo[0]),
                binHi: Std.int(binAndRatioHi[0]),
                ratioLo: binAndRatioLo[1],
                ratioHi: binAndRatioHi[1],
                peak: [0, 0],
                hold: 0,
                value: 0
            });

            // posX += barWidth;
        }
    }

    function calcRatio(freq):Array<Float>
    {
        var bin = freqToBin(freq, 'floor'); // find closest FFT bin
        var lower = binToFreq(bin);
        var upper = binToFreq(bin + 1);
        var ratio = LogHelper.log2(freq / lower) / LogHelper.log2(upper / lower);
        return [bin, ratio];
    }

    function freqToBin(freq, mathType:String = 'round'):Int
    {
        var bin = freq * fftN / buffer.sampleRate;
        if (mathType == 'round')
            return Math.round(bin);
        else if (mathType == 'floor')
            return Math.floor(bin);
        else if (mathType == 'ceil')
            return Math.ceil(bin);
        else
            return Std.int(bin);
    }

    function binToFreq(bin)
		return bin * buffer.sampleRate / fftN;
}