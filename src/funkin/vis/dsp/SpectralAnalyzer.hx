package funkin.vis.dsp;

import haxe.io.Bytes;
import lime.utils.UInt8Array;
import flixel.FlxG;
import flixel.math.FlxMath;
import funkin.vis._internal.html5.AnalyzerNode;
import funkin.vis.audioclip.frontends.LimeAudioClip;
import grig.audio.FFT;
import grig.audio.FFTVisualization;
import lime.media.AudioSource;

#if lime_vorbis
import lime.media.vorbis.VorbisFile;
#end

using grig.audio.lime.UInt8ArrayTools;

typedef Bar =
{
    var value:Float;
    var peak:Float;
}

typedef BarObject =
{
	var binLo:Int;
	var binHi:Int;
    var freqLo:Float;
    var freqHi:Float;
    var recentValues:RecentPeakFinder;
}

enum MathType
{
    Round;
    Floor;
    Ceil;
    Cast;
}

class SpectralAnalyzer
{
    public var minDb(default, set):Float = -70;
    public var maxDb(default, set):Float = -20;
    public var fftN(default, set):Int = 4096;
    public var minFreq:Float = 50;
    public var maxFreq:Float = 22000;
    // Awkwardly, we'll have to interfaces for now because there's too much platform specific stuff we need
    private var audioSource:AudioSource;
    private var audioClip:AudioClip;
	private var barCount:Int;
    private var maxDelta:Float;
    private var peakHold:Int;
    var fftN2:Int = 2048;
    #if web
    private var htmlAnalyzer:AnalyzerNode;
    private var bars:Array<BarObject> = [];
    #else
    private var fft:FFT;
	private var vis = new FFTVisualization();
    private var barHistories = new Array<RecentPeakFinder>();
    private var blackmanWindow = new Array<Float>();
    #end
    private var _logGraphCache:Array<Int> = [];
    private var _mixedCache:Array<Float> = [];
    #if lime_vorbis
    private var vorbisBuffer:UInt8Array;
    #end

    private function freqToBin(freq:Float, mathType:MathType = Round):Int
    {
        var bin = freq * fftN2 / audioClip.audioBuffer.sampleRate;
        return switch (mathType) {
            case Round: Math.round(bin);
            case Floor: Math.floor(bin);
            case Ceil: Math.ceil(bin);
            case Cast: Std.int(bin);
        }
    }

    function normalizedB(value:Float)
    {
        var maxValue = maxDb;
        var minValue = minDb;

        return clamp((value - minValue) / (maxValue - minValue), 0, 1);
    }

    function calcBars(barCount:Int, peakHold:Int)
    {
        #if web
        bars = [];
        var logStep = (LogHelper.log10(maxFreq) - LogHelper.log10(minFreq)) / (barCount);

        var scaleMin:Float = Scaling.freqScaleLog(minFreq);
        var scaleMax:Float = Scaling.freqScaleLog(maxFreq);

        var curScale:Float = scaleMin;

        // var stride = (scaleMax - scaleMin) / bands;

        for (i in 0...barCount)
        {
            var curFreq:Float = Math.pow(10, LogHelper.log10(minFreq) + (logStep * i));

            var freqLo:Float = curFreq;
            var freqHi:Float = Math.pow(10, LogHelper.log10(minFreq) + (logStep * (i + 1)));

            var binLo = freqToBin(freqLo, Floor);
            var binHi = freqToBin(freqHi);

            bars.push(
                {
                    binLo: binLo,
                    binHi: binHi,
                    freqLo: freqLo,
                    freqHi: freqHi,
                    recentValues: new RecentPeakFinder(peakHold)
                });
        }

        if (bars[0].freqLo < minFreq)
        {
            bars[0].freqLo = minFreq;
            bars[0].binLo = freqToBin(minFreq, Floor);
        }

        if (bars[bars.length - 1].freqHi > maxFreq)
        {
            bars[bars.length - 1].freqHi = maxFreq;
            bars[bars.length - 1].binHi = freqToBin(maxFreq, Floor);
        }
        #else
        if (barCount > barHistories.length) {
            barHistories.resize(barCount);
        }
        for (i in 0...barCount) {
            if (barHistories[i] == null) barHistories[i] = new RecentPeakFinder();
        }
        #end
    }

    function resizeBlackmanWindow(size:Int)
    {
        #if !web
        if (blackmanWindow.length == size) return;
        blackmanWindow.resize(size);
        for (i in 0...size) {
            blackmanWindow[i] = calculateBlackmanWindow(i, size);
        }
        #end
    }

	public function new(audioSource:AudioSource, barCount:Int, maxDelta:Float = 0.01, peakHold:Int = 30)
	{
        this.audioSource = audioSource;
		this.audioClip = new LimeAudioClip(audioSource);
		this.barCount = barCount;
        this.maxDelta = maxDelta;
        this.peakHold = peakHold;

        #if web
        htmlAnalyzer = new AnalyzerNode(audioClip);
        #else
        fft = new FFT(fftN);
        #end

        calcBars(barCount, peakHold);
        resizeBlackmanWindow(fftN);
	}

	public function getLevels(?levels:Array<Bar>):Array<Bar>
	{
        if(levels == null) levels = new Array<Bar>();
        #if web
        var amplitudes:Array<Float> = htmlAnalyzer.getFloatFrequencyData();

        for (i in 0...bars.length) {
            var bar = bars[i];
            var binLo = bar.binLo;
            var binHi = bar.binHi;

            var value:Float = minDb;
            for (j in (binLo + 1)...(binHi)) {
                value = Math.max(value, amplitudes[Std.int(j)]);
            }

            // this isn't for clamping, it's to get a value
            // between 0 and 1!
            value = normalizedB(value);
            bar.recentValues.push(value);
            var recentPeak = bar.recentValues.peak;

            if(levels[i] != null)
            {
                levels[i].value = value;
                levels[i].peak = recentPeak;
            }
            else levels.push({value: value, peak: recentPeak});
        }

        return levels;
        #else
        var numOctets = Std.int(audioClip.audioBuffer.bitsPerSample / 8);
		var wantedLength = fftN * numOctets * audioClip.audioBuffer.channels;
		var startFrame = audioClip.currentFrame;

        if (startFrame < 0)
        {
            return levels = [for (bar in 0...barCount) {value: 0, peak: 0}];
        }

        startFrame -= startFrame % numOctets;

        var endFrame:Int = min(startFrame + wantedLength, audioClip.audioBuffer.length);

        #if lime_vorbis
        if (audioClip.streamed)
        {
            @:privateAccess
            var vorbisFile = audioSource.buffer.__srcVorbisFile;

            // reading from VorbisFile will automatically move the position
            // which causes issues with playback, so we keep old time to go back to it
            var prevPos = vorbisFile.pcmTell();

            vorbisFile.pcmSeek(Std.int(startFrame / (numOctets + audioClip.audioBuffer.channels)));

            // calling this updates the vorbisBuffer array
            readVorbisFileBuffer(vorbisFile, wantedLength); 

            vorbisFile.pcmSeek(prevPos);

            getSignal(vorbisBuffer, audioClip.audioBuffer.bitsPerSample);
        }
        else
        #end
        {
            var segment:UInt8Array = audioSource.buffer.data.subarray(startFrame, endFrame);
            getSignal(segment, audioClip.audioBuffer.bitsPerSample);
        }

		if (audioSource.buffer.channels > 1) {
            var wantedArrayLength = Std.int(_buffer.length / audioSource.buffer.channels);
            if (_mixedCache.length != wantedArrayLength)
			    _mixedCache.resize(wantedArrayLength);

			for (i in 0..._mixedCache.length) {
				_mixedCache[i] = 0.0;
				for (c in 0...audioSource.buffer.channels) {
					_mixedCache[i] += 0.7 * _buffer[i*audioSource.buffer.channels+c];
				}
                _mixedCache[i] *= blackmanWindow[i];
			}
			//_buffer = _mixedCache;
		}

		var range = 16;
        var freqs = fft.calcFreq(_mixedCache);

		_logGraphCache = vis.makeLogGraph(freqs, barCount + 1, Math.floor(maxDb - minDb), range, _logGraphCache);

        /*if (_logGraphCache.length - 1 > barHistories.length) {
            barHistories.resize(_logGraphCache.length - 1);
        }*/
        // levels.resize(_logGraphCache.length-1);

        for (i in 0..._logGraphCache.length-1) {

            if (barHistories[i] == null) barHistories[i] = new RecentPeakFinder();
            var recentValues = barHistories[i];
            var value = _logGraphCache[i] / range;

            // slew limiting
            var lastValue = recentValues.lastValue;
            if (maxDelta > 0.0) {
                var delta = clamp(value - lastValue, -1 * maxDelta, maxDelta);
                value = lastValue + delta;
            }
            recentValues.push(value);

            var recentPeak = recentValues.peak;

            if(levels[i] != null)
            {
                levels[i].value = value;
                levels[i].peak = recentPeak;
            }
            else levels[i] = {value: value, peak: recentPeak};
        }
        return levels;
        #end
	}

    // Prevents a memory leak by reusing array
    var _buffer:Array<Float> = [];
	function getSignal(data:lime.utils.UInt8Array, bitsPerSample:Int):Array<Float>
    {
        switch(bitsPerSample)
        {
            case 8:
                _buffer.resize(data.length);
                for (i in 0...data.length)
                    _buffer[i] = data[i] / 128.0;

            case 16:
                _buffer.resize(Std.int(data.length / 2));
                for (i in 0..._buffer.length)
                    _buffer[i] = data.getInt16(i * 2) / 32767.0;

            case 24:
                _buffer.resize(Std.int(data.length / 3));
                for (i in 0..._buffer.length)
                    _buffer[i] = data.getInt24(i * 3) / 8388607.0;

            case 32:
                _buffer.resize(Std.int(data.length / 4));
                for (i in 0..._buffer.length)
                    _buffer[i] = data.getInt32(i * 4) / 2147483647.0;

            default: trace('Unknown integer audio format');
        }
        return _buffer;
    }

    #if lime_vorbis
    // Pretty much copied from
    // https://github.com/openfl/lime/blob/develop/src/lime/_internal/backend/native/NativeAudioSource.hx#L212
    function readVorbisFileBuffer(vorbisFile:VorbisFile, length:Int):UInt8Array
    {
        if (vorbisBuffer == null || vorbisBuffer.length != length)
            vorbisBuffer = new UInt8Array(length);

        var read:Int = 0;
        var total:Int = 0;
        var readMax:Int = 4096;

        while (total < length)
        {
            readMax = 4096;

            if (readMax > length - total)
            {
                readMax = length - total;
            }

            read = vorbisFile.read(vorbisBuffer.buffer, total, readMax);

            if (read > 0)
            {
                total += read;
            }
            else
            {
                break;
            }
        }

        return vorbisBuffer;
    }
    #end

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

    function set_minDb(value:Float):Float
    {
        minDb = value;

        #if web
        htmlAnalyzer.minDecibels = value;
        #end

        return value;
    }

    function set_maxDb(value:Float):Float
    {
        maxDb = value;

        #if web
        htmlAnalyzer.maxDecibels = value;
        #end

        return value;
    }

    function set_fftN(value:Int):Int
    {
        fftN = value;
        var pow2 = FFT.nextPow2(value);
        fftN2 = Std.int(pow2 / 2);

        #if web
        htmlAnalyzer.fftSize = pow2;
        #else
        fft = new FFT(value);
        #end

        calcBars(barCount, peakHold);
        resizeBlackmanWindow(fftN);
        return pow2;
    }
}
