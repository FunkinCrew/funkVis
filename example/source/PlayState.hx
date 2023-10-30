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
import funkVis.AudioBuffer;
import funkVis.Scaling;
import funkVis.LogHelper;
import funkVis.dsp.SpectralAnalyzer;

class AudioClip implements funkVis.AudioClip
{
	public var audioBuffer(default, null):AudioBuffer;
    public var currentFrame(get, never):Int;

	public function new(audioSource:AudioSource)
	{
		var data:lime.utils.UInt16Array = cast audioSource.buffer.data;
		this.audioBuffer = new AudioBuffer(data, audioSource.buffer.sampleRate);
	}

	private function get_currentFrame():Int
	{
		return Std.int(FlxMath.remapToRange(FlxG.sound.music.time, 0, FlxG.sound.music.length, 0, audioBuffer.data.length / 2));
	}
}

class PlayState extends FlxState
{
	var spr:FlxSprite;
	var musicSrc:AudioSource;
	var data:lime.utils.UInt16Array;

	var debugText:FlxText;

	var grpBars:FlxTypedGroup<FlxSprite>;

	static inline var barCount:Int = 8;

	var analyzer:SpectralAnalyzer;

	override public function create()
	{
		super.create();

		FlxG.sound.playMusic("assets/music/shoreline.ogg");

		@:privateAccess
		musicSrc = cast FlxG.sound.music._channel.__source;

		data = cast musicSrc.buffer.data;

		analyzer = new SpectralAnalyzer(barCount, new AudioClip(musicSrc), 0.001);

		grpBars = new FlxTypedGroup<FlxSprite>();
		add(grpBars);

		for (i in 0...barCount)
		{
			var spr:FlxSprite = new FlxSprite((i / barCount) * FlxG.width, 0).makeGraphic(Std.int((1 / barCount) * FlxG.width) - 4, 1, FlxColor.RED);
			grpBars.add(spr);
		}

		debugText = new FlxText(0, 0, 0, "test", 24);
		// add(debugText);
	}

	static inline function min(x:Int, y:Int):Int
	{
		return x > y ? y : x;
	}

	override function draw()
	{
		var levels = analyzer.getLevels();

		for (i in 0...min(grpBars.members.length, levels.length)) {
			grpBars.members[i].scale.y = levels[i] * 600;
		}

		super.draw();
	}

	var max:Float = 0;

	override public function update(elapsed:Float)
	{
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
