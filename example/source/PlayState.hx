package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxe.io.BytesInput;
import haxe.io.Input;
import haxe.io.UInt16Array;
import lime.media.AudioSource;
import lime.media.vorbis.VorbisFile;
import lime.utils.Int16Array;
import sys.io.File;
import funkVis.Scaling;
import funkVis.LogHelper;
import funkVis.dsp.SpectralAnalyzer;

using Lambda;
using Math;
using funkVis.dsp.FFT;
using funkVis.dsp.Signal;

// typedef Note =
// {
// 	final pitch:Float;
// 	final amplitude:Float;
// }

// typedef Melody =
// {
// 	final notes:Array<Note>;
// 	final span:Int;
// }

class PlayState extends FlxState
{
	var spr:FlxSprite;
	var musicSrc:AudioSource;
	var data:lime.utils.UInt16Array;

	var debugText:FlxText;

	// var bars:Array<BarObject> = [];
	var grpBars:FlxTypedGroup<FlxSprite>;
	// var freqStuff:Array<Melody>;

	static inline var barCount:Int = 8;

	// var energy:EnergyObj;

	var analyzer:SpectralAnalyzer;

	override public function create()
	{
		super.create();

		FlxG.sound.playMusic("assets/music/shoreline.ogg");

		@:privateAccess
		musicSrc = cast FlxG.sound.music._channel.__source;

		data = cast musicSrc.buffer.data;

		analyzer = new SpectralAnalyzer(barCount, new funkVis.AudioBuffer(data, musicSrc.buffer.sampleRate));

		grpBars = new FlxTypedGroup<FlxSprite>();
		add(grpBars);

		// energy = {
		// 	val: 0,
		// 	peak: 0,
		// 	hold: 0
		// };

		// calcBars();

		for (i in 0...barCount)
		{
			var spr:FlxSprite = new FlxSprite((i / barCount) * FlxG.width, 0).makeGraphic(Std.int((1 / barCount) * FlxG.width) - 4, 1, FlxColor.RED);
			grpBars.add(spr);
		}

		debugText = new FlxText(0, 0, 0, "test", 24);
		// add(debugText);
	}

	// todo
	// create this melody every frame, and only for the length of a frame (x amount of fftN samples or whateva)
	// dynamic bars and shiiit)
	// identical to getFreqStuff, but returns a single melody

	// function getFreqRealtime(fs:Float, index:Int):Melody
	// {
	// 	var melody:Melody = {notes: [], span: hop};

	// 	final freqs = stft(index, fftN, fs);
	// 	for (k => s in freqs)
	// 	{
	// 		// convert amplitude to decibels
	// 		melody.notes.push({pitch: indexToFreq(k), amplitude: 20 * LogHelper.log10(s / 32768)});
	// 	}

	// 	return melody;
	// }

	// function freqToBin(freq, mathType:String = 'round'):Int
	// {
	// 	var bin = freq * fftN / fs;
	// 	if (mathType == 'round')
	// 		return Math.round(bin);
	// 	else if (mathType == 'floor')
	// 		return Math.floor(bin);
	// 	else if (mathType == 'ceil')
	// 		return Math.ceil(bin);
	// 	else
	// 		return Std.int(bin);
	// }

	// function binToFreq(bin)
	// 	return bin * fs / fftN;

	var amplitudes(get, default):Array<Float> = [];
	var ampIndex:Int = 0;

	function get_amplitudes():Array<Float>
	{
		var index:Int = Std.int(FlxMath.remapToRange(FlxG.sound.music.time, 0, FlxG.sound.music.length, 0, data.length / 2));
		if (ampIndex == index)
			return amplitudes;
		else
			ampIndex = index;

		var lilamp = [];
		final freqs = stft(index, fftN, fs);

		for (k => s in freqs)
			lilamp.push(s);

		amplitudes = lilamp;

		return lilamp;
	}

	// function getFreqStuff(fs:Float):Array<Melody>
	// {
	// 	var melody = new Array<Note>();
	// 	var c = 0;

	// 	var melodyList:Array<Melody> = [];

	// 	while (c < data.length / 4)
	// 	{
	// 		final freqs = stft(c, fftN, fs);

	// 		for (k => s in freqs)
	// 			melody.push({pitch: indexToFreq(k), amplitude: 20 * LogHelper.log10(s / 32768)});
			

	// 		melodyList.push({notes: melody, span: hop});
	// 		melody = [];
	// 		c += hop;
	// 	}

	// 	for (i in melodyList)
	// 		trace(i.notes[1000]);
	// 	return melodyList;
	// }

	var max:Float = 0;
	var maxHeight:Float = 0;
	var prevIndex:Int = 0;

	override function draw()
	{
		var currentEnergy:Float = 0;

		for (i in 0...bars.length)
		{
			var bar = bars[i];
			var freq = bar.freq;
			var binLo = bar.binLo;
			var binHi = bar.binHi;
			var ratioLo = bar.ratioLo;
			var ratioHi = bar.ratioHi;

			trace(bar);

			var barHeight:Float = Math.max(interpolate(binLo, ratioLo), interpolate(binHi, ratioHi));
			// check additional bins (unimplemented?)
			// check additional bins (if any) for this bar and keep the highest value
			for (j in binLo + 1...binHi)
			{
				if (amplitudes[j] > barHeight)
					barHeight = amplitudes[j];
			}

			trace(barHeight);

			barHeight = 20 * LogHelper.log10(barHeight / 32768); // gets converted to decibels
			barHeight = normalizedB(barHeight);
			trace(barHeight);
			// barHeight += 100;
			bar.value = barHeight;
			currentEnergy += barHeight;

			// using 0 right now for channel
			if (bar.peak[0] > 0)
			{
				bar.hold--;
				// if hold is negative, it becomes the "acceleration" for peak drop
				if (bar.hold < 0)
					bar.peak[0] += bar.hold / 200;
			}

			if (barHeight >= bar.peak[0])
			{
				bar.peak[0] = barHeight;
				bar.hold = 30; // set peak hold time to 30 frames (0.5s)
			}

			var peak = bar.peak[0];
			var posX = bar.posX;
			if (peak > 0 && posX >= 0 && posX < FlxG.width)
			{
				grpBars.members[i].scale.y = barHeight * 600;
			}

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
		super.draw();
	}

	function normalizedB(value:Float)
	{
		var clamp = (val:Float, min, max) -> val <= min ? min : val >= max ? max : val;

		var maxValue = -30;
		var minValue = -65;

		// return FlxMath.remapToRange(value, minValue, maxValue, 0, 1);
		return clamp((value - minValue) / (maxValue - minValue), 0, 1);
	}

	function interpolate(bin, ratio:Float)
	{
		var value = amplitudes[bin] + (bin < amplitudes.length - 1 ? (amplitudes[bin + 1] - amplitudes[bin]) * ratio : 0);
		return Math.isNaN(value) ? -Math.NEGATIVE_INFINITY : value;
	}

	override public function update(elapsed:Float)
	{
		// var remappedIndex:Int = Std.int(FlxMath.remapToRange(FlxG.sound.music.time, 0, FlxG.sound.music.length, 0, data.length / 2));

		// if (prevIndex != remappedIndex)
		// {
		// 	prevIndex = remappedIndex;

		// 	var melody:Melody = getFreqRealtime(fs, remappedIndex);
		// 	for (ind => bar in grpBars.members)
		// 	{
		// 		// a function to run ind through that will convert / remap it to get the proper frequency, taking into account exponential growth of music frequencies
		// 		// var freq:Float = (Math.pow(10, ((ind / grpBars.members.length) * 4)) * 2);

		// 		var min:Float = 20;
		// 		var max:Float = 20000;
		// 		var linearFactor:Float = 10;

		// 		var exponentialPart:Float = Math.pow(10, (4 * ind / grpBars.members.length)) * 2;

		// 		var linearPart:Float = linearFactor * ind;
		// 		var correctionFactor:Float = max / (max + linearFactor * grpBars.members.length);
		// 		var scalingFactor:Float = (max - min) / max;
		// 		var highpassFreq = (exponentialPart + linearPart) * correctionFactor * scalingFactor + min;
		// 		var barkFreq = freqScaleBark(exponentialPart);
		// 		// var freqNext:Float = Math.pow(10, (Math.min(((ind + 1) / grpBars.members.length), 1) * 4)) * 22;

		// 		var remappedFreq:Int = Std.int(FlxMath.remapToRange(barkFreq, 0, freqScaleBark(Math.pow(10, 4) * 2), 0, melody.notes.length));
		// 		// var remappedFreqNext:Int = Std.int(FlxMath.remapToRange(freqNext, 0, Math.pow(10, 4) * 22, 0, melody.notes.length));

		// 		// var slicedNotes = melody.notes.slice(remappedFreq, remappedFreqNext);

		// 		if (melody.notes[remappedFreq] == null)
		// 			remappedFreq = melody.notes.length - 1;

		// 		// averages out the ranges
		// 		var curIndex:Float = melody.notes[remappedFreq].amplitude;

		// 		// for (note in slicedNotes)
		// 		// curIndex += note.amplitude;

		// 		// curIndex /= slicedNotes.length;

		// 		var minShit:Float = -100;
		// 		var maxShit:Float = -30;

		// 		curIndex = Math.max(curIndex, minShit);
		// 		curIndex = Math.min(curIndex, maxShit);

		// 		var scaleShit = FlxMath.remapToRange(curIndex, minShit, maxShit, 0, 1);

		// 		// bar.scale.y = FlxMath.lerp(bar.scale.y, scaleShit, 0.5);
		// 	}
		// }

		var curIndex = Math.floor(musicSrc.buffer.sampleRate * (FlxG.sound.music.time / 1000));
		// trace(curIndex / (data.length * 2));
		// trace(FlxG.sound.music.time / FlxG.sound.music.length);
		max = Math.max(max, data[curIndex]);
		debugText.text = "";
		// refactor below code to use addDebugText function
		addDebugText(max / 2);
		addDebugText(musicSrc.buffer.sampleRate);
		addDebugText(data[curIndex]);
		addDebugText(FlxG.sound.music.time / FlxG.sound.music.length);
		addDebugText(curIndex / (data.length / 4));
		addDebugText((data.length / 4) / musicSrc.buffer.sampleRate);
		addDebugText(FlxG.sound.music.length / 1000);
		super.update(elapsed);
	}

	function addDebugText(text:Dynamic)
	{
		debugText.text += "\n";
		debugText.text += "" + text;
	}

	// function calcRatio(freq):Array<Float>
	// {
	// 	var bin = freqToBin(freq, 'floor'); // find closest FFT bin
	// 	var lower = binToFreq(bin);
	// 	var upper = binToFreq(bin + 1);
	// 	var ratio = LogHelper.log2(freq / lower) / LogHelper.log2(upper / lower);
	// 	return [bin, ratio];
	// }

	// write a nice lil comment block here that nicely shows that below is the FFT type section of code lol
	// FFT STUFF BELOW
	// FFT STUFF BELOW
	// the songs sample rate... set to 44100 for now
	var fs:Float = 44100;
	final fftN = 4096;
	final overlap = 0.5;
	var hop(get, never):Int;

	function get_hop():Int
	{
		return Std.int(fftN * (1 - overlap));
	}

	final a0 = 0.50; // => Hann(ing) window

	/**
	 * FFT window function
	 * @param n idk what this is lol
	 */
	function window(n:Int)
		return a0 - (1 - a0) * Math.cos(2 * Math.PI * n / fftN);

	function blackmanWindow(n:Int)
		return 0.42 - a0 * Math.cos(2 * Math.PI * n / (fftN - 1)) + 0.08 * Math.cos(4 * Math.PI * n / (fftN - 1));

	// helpers
	var binSizeHz(get, never):Float;

	function get_binSizeHz():Float
		return fs / fftN;

	function indexToFreq(k:Int)
		return 1.0 * k * binSizeHz; // we need the '1.0' to avoid overflows

	function indexToTime(n:Int)
		return n / fs;

	// computes an STFT frame, starting at the given index within input samples
	function stft(c:Int, fftN:Int = 4096, fs:Float)
	{
		return [
			for (n in 0...fftN)
				c + n < Std.int(data.length) ? data[Std.int((c + n))] : 0.0
		].mapi((n, x) -> x * blackmanWindow(n)).rfft().map(z -> z.scale(1 / fs).magnitude);
	}
}

typedef BarObject =
{
	var posX:Float;
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

// typedef EnergyObj =
// {
// 	var val:Float;
// 	var peak:Float;
// 	var hold:Float;
// }
