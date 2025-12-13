package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import haxe.io.BytesInput;
import haxe.io.Input;
import haxe.io.UInt16Array;
import lime.media.AudioSource;
import lime.utils.Int16Array;
import openfl.utils.Assets;

#if STREAM
import lime.media.vorbis.VorbisFile;
import lime.media.AudioBuffer;
import openfl.media.Sound;
#end

using StringTools;

class PlayState extends FlxState
{
	var musicSrc:AudioSource;
	var data:lime.utils.UInt16Array;

	var debugText:FlxText;

	var musicList:Array<String> = [];

	override public function create()
	{
		super.create();

		// musicList = fillMusicList("assets/music/musicList.txt");

		#if STREAM
		var vorbis = VorbisFile.fromFile("assets/music/catStuck.ogg");
		var buffer = AudioBuffer.fromVorbisFile(vorbis);
		FlxG.sound.playMusic(Sound.fromAudioBuffer(buffer));
		#else
		FlxG.sound.playMusic("assets/music/catStuck.ogg");
		#end

		@:privateAccess
		musicSrc = cast #if (openfl < "9.3.2") FlxG.sound.music._channel.__source #else FlxG.sound.music._channel.__audioSource #end;

		data = cast musicSrc.buffer.data;

		var visualizer = new Visualizer(musicSrc);
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
		// max = Math.max(max, data[curIndex]);
		debugText.text = "";
		// refactor below code to use addDebugText function
		// addDebugText(max / 2);
		// addDebugText(musicSrc.buffer.sampleRate);
		// addDebugText(data[curIndex]);
		// addDebugText(FlxG.sound.music.time / FlxG.sound.music.length);
		// addDebugText(curIndex / (data.length / 4));
		// addDebugText((data.length / 4) / musicSrc.buffer.sampleRate);
		// addDebugText(FlxG.sound.music.length / 1000);
		super.update(elapsed);

		if (FlxG.keys.justPressed.SPACE)
		{
			#if instrument
			// instrument.coverage.Coverage.endCoverage(); // when measuring coverage
			instrument.profiler.Profiler.endProfiler(); // when profiling
			#end
		}
	}

	function addDebugText(text:Dynamic)
	{
		debugText.text += "\n";
		debugText.text += "" + text;
	}

	/**
	 * Returns an array of song names to use for music list
	 * @param listPath file path to the txt file
	 * @return An array of song names from the txt file
	 */
	function fillMusicList(listPath:String):Array<String>
	{
		return Assets.getText(listPath).split("\n").map(str -> str.trim());
	}
}
