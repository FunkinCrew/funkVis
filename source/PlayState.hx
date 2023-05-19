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

using Lambda;
using Math;
using dsp.FFT;
using dsp.Signal;

typedef Note =
{
	final pitch:Float;
	final amplitude:Float;
}

typedef Melody =
{
	final notes:Array<Note>;
	final span:Int;
}

class PlayState extends FlxState
{
	var spr:FlxSprite;
	var musicSrc:AudioSource;
	var data:lime.utils.UInt16Array;

	var debugText:FlxText;

	var grpBars:FlxTypedGroup<FlxSprite>;
	var freqStuff:Array<Melody>;

	override public function create()
	{
		super.create();

		FlxG.sound.playMusic("assets/music/copyrightlol/chai.ogg");

		@:privateAccess
		musicSrc = cast FlxG.sound.music._channel.__source;

		data = cast musicSrc.buffer.data;

		trace(musicSrc.buffer.sampleRate);
		fs = musicSrc.buffer.sampleRate;

		grpBars = new FlxTypedGroup<FlxSprite>();
		add(grpBars);

		var barCount:Int = 128;

		for (i in 0...barCount)
		{
			var spr:FlxSprite = new FlxSprite((i / barCount) * FlxG.width, 0).makeGraphic(Std.int((1 / barCount) * FlxG.width) - 4, 300, FlxColor.RED);
			grpBars.add(spr);
		}

		// freqStuff = getFreqStuff(musicSrc.buffer.sampleRate);

		// trace(freqStuff.notes.length);
		// trace(freqStuff.span);
		debugText = new FlxText(0, 0, 0, "test", 24);
		// add(debugText);
	}

	// todo
	// create this melody every frame, and only for the length of a frame (x amount of fftN samples or whateva)
	// dynamic bars and shiiit)
	// identical to getFreqStuff, but returns a single melody

	function getFreqRealtime(fs:Float, index:Int):Melody
	{
		var melody:Melody = {notes: [], span: hop};

		final freqs = stft(index, fftN, fs);
		for (k => s in freqs)
		{
			// convert amplitude to decibels
			// Math.log10 isn't available
			// creates a log10 function using Math.log, since it returns euler's number
			var log10 = function(x:Float):Float
			{
				return Math.log(x) / Math.log(10);
			};

			melody.notes.push({pitch: indexToFreq(k), amplitude: 20 * log10(s / 32768)});
		}

		return melody;
	}

	function getFreqStuff(fs:Float):Array<Melody>
	{
		var melody = new Array<Note>();
		var c = 0;

		var melodyList:Array<Melody> = [];

		while (c < data.length / 4)
		{
			final freqs = stft(c, fftN, fs);
			// trace(indexToTime(c));
			// trace(freqs.length);

			// for (k => s in freqs)
			// trace('${indexToTime(c)}; ${indexToFreq(k)}; ${s}');

			// trace('\n');

			// final peaks = freqs.findPeaks();
			// final pi = peaks[peaks.map(i -> freqs[i]).maxi()];

			// trace(indexToFreq(pi));
			// trace("\t" + freqs[pi]);
			for (k => s in freqs)
			{
				// convert amplitude to decibels
				// Math.log10 isn't available
				// creates a log10 function using Math.log, since it returns euler's number
				var log10 = function(x:Float):Float
				{
					return Math.log(x) / Math.log(10);
				};

				melody.push({pitch: indexToFreq(k), amplitude: 20 * log10(s / 32768)});
			}

			melodyList.push({notes: melody, span: hop});
			melody = [];

			// melody.push({pitch: indexToFreq(pi), amplitude: freqs[pi]});
			c += hop;
		}

		// trace('${melody} - ${hop}');
		for (i in melodyList)
			trace(i.notes[1000]);
		return melodyList;

		// trace("swag");
	}

	var max:Float = 0;
	var maxHeight:Float = 0;
	var prevIndex:Int = 0;

	override public function update(elapsed:Float)
	{
		var remappedIndex:Int = Std.int(FlxMath.remapToRange(FlxG.sound.music.time, 0, FlxG.sound.music.length, 0, data.length / 2));

		if (prevIndex != remappedIndex)
		{
			prevIndex = remappedIndex;

			var melody:Melody = getFreqRealtime(fs, remappedIndex);
			for (ind => bar in grpBars.members)
			{
				// a function to run ind through that will convert / remap it to get the proper frequency, taking into account exponential growth of music frequencies
				var freq:Float = (Math.pow(10, ((ind / grpBars.members.length) * 5)) * 2);
				// var freqNext:Float = Math.pow(10, (Math.min(((ind + 1) / grpBars.members.length), 1) * 4)) * 22;

				var remappedFreq:Int = Std.int(FlxMath.remapToRange(freq, 0, (Math.pow(10, 5) * 2), 0, melody.notes.length));
				// var remappedFreqNext:Int = Std.int(FlxMath.remapToRange(freqNext, 0, Math.pow(10, 4) * 22, 0, melody.notes.length));

				// var slicedNotes = melody.notes.slice(remappedFreq, remappedFreqNext);

				if (melody.notes[remappedFreq] == null)
					remappedFreq = melody.notes.length - 1;

				// averages out the ranges
				var curIndex:Float = melody.notes[remappedFreq].amplitude;

				// for (note in slicedNotes)
				// curIndex += note.amplitude;

				// curIndex /= slicedNotes.length;

				var minShit:Float = -65;
				var maxShit:Float = -30;

				curIndex = Math.max(curIndex, minShit);
				curIndex = Math.min(curIndex, maxShit);

				var scaleShit = FlxMath.remapToRange(curIndex, minShit, maxShit, 0, 1);

				bar.scale.y = scaleShit;
			}
		}

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

	// write a nice lil comment block here that nicely shows that below is the FFT type section of code lol
	// FFT STUFF BELOW
	// FFT STUFF BELOW
	// the songs sample rate... set to 44100 for now
	var fs:Float = 44100;
	final fftN = 4096;
	final overlap = 0.0;
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
