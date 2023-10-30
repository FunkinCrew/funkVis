package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
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

class PlayState extends FlxState
{
	var musicSrc:AudioSource;
	var data:lime.utils.UInt16Array;

	var debugText:FlxText;

	override public function create()
	{
		super.create();

		FlxG.sound.playMusic("assets/music/shoreline.ogg");

		@:privateAccess
		musicSrc = cast FlxG.sound.music._channel.__source;

		data = cast musicSrc.buffer.data;

		var visualizer = new Visualizer(new AudioClip(musicSrc));
		add(visualizer);

		debugText = new FlxText(0, 0, 0, "test", 24);
		// add(debugText);
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
