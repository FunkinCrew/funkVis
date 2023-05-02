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

		FlxG.sound.playMusic(AssetPaths.shoreline__ogg);

		@:privateAccess
		musicSrc = cast FlxG.sound.music._channel.__source;

		data = cast musicSrc.buffer.data;

		trace(musicSrc.buffer.sampleRate);

		trace("finished samples!!");
		// trace(arr.length);
		// trace(arr);

		grpBars = new FlxTypedGroup<FlxSprite>();
		add(grpBars);

		var barCount:Int = 64;

		for (i in 0...barCount)
		{
			var spr:FlxSprite = new FlxSprite((i / barCount) * FlxG.width, 0).makeGraphic(Std.int((1 / barCount) * FlxG.width) - 4, 100, FlxColor.RED);
			grpBars.add(spr);
		}

		freqStuff = getFreqStuff(musicSrc.buffer.sampleRate);

		// trace(freqStuff.notes.length);
		// trace(freqStuff.span);
		debugText = new FlxText(0, 0, 0, "test", 24);
		add(debugText);
	}

	// todo
	// create this melody every frame, and only for the length of a frame (x amount of fftN samples or whateva)
	// dynamic bars and shiiit)

	function getFreqStuff(fs:Float):Array<Melody>
	{
		final fftN = 4096;
		final overlap = 0.5;
		final hop = Std.int(fftN * (1 - overlap));

		final a0 = 0.50; // => Hann(ing) window
		final window = (n:Int) -> a0 - (1 - a0) * Math.cos(2 * Math.PI * n / fftN);

		// helpers
		final binSizeHz = fs / fftN;
		final indexToFreq = (k:Int) -> 1.0 * k * binSizeHz; // we need the '1.0' to avoid overflows
		final indexToTime = (n:Int) -> n / fs;

		// computes an STFT frame, starting at the given index within input samples
		final stft = function(c:Int)
		{
			return [
				for (n in 0...fftN)
					c + n < Std.int(data.length / 4) ? data[Std.int((c + n) * 4)] : 0.0
			].mapi((n, x) -> x * window(n)).rfft().map(z -> z.scale(1 / fs).magnitude);
		}

		var melody = new Array<Note>();
		var c = 0;

		var melodyList:Array<Melody> = [];

		while (c < data.length / 4)
		{
			final freqs = stft(c);
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

			// trace(melody);

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

	override public function update(elapsed:Float)
	{
		for (ind => bar in grpBars.members)
		{
			var remappedIndex:Int = Std.int(FlxMath.remapToRange(FlxG.sound.music.time, 0, FlxG.sound.music.length, 0, freqStuff.length));

			// a function to run ind through that will convert / remap it to get the proper frequency, taking into account exponential growth of music frequencies
			var freq:Float = Math.pow(10, (ind / grpBars.members.length) * 4) * 20;

			var remappedFreq:Int = Std.int(FlxMath.remapToRange(freq, 0, Math.pow(10, 4) * 20, 0, freqStuff[remappedIndex].notes.length));

			var curIndex = freqStuff[remappedIndex].notes[remappedFreq].amplitude;

			maxHeight = Math.max(maxHeight, curIndex);

			var scaleShit = FlxMath.remapToRange(curIndex, -100, 0, 0, 1);

			bar.scale.y = scaleShit;
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
}
