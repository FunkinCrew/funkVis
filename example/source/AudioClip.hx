package;

import flixel.FlxG;
import flixel.math.FlxMath;
import funkVis.AudioBuffer;
import lime.media.AudioSource;

class AudioClip implements funkVis.AudioClip
{
	public var audioBuffer(default, null):AudioBuffer;
    public var currentFrame(get, never):Int;
	public var source:Dynamic;

	public function new(audioSource:AudioSource)
	{
		var data:lime.utils.UInt16Array = cast audioSource.buffer.data;
		
		#if web
		var sampleRate:Float = audioSource.buffer.src._sounds[0]._node.context.sampleRate;
		#else
		var sampleRate = audioSource.buffer.sampleRate;
		#end

		trace("audio clip samplerate " + sampleRate);
		this.audioBuffer = new AudioBuffer(data, sampleRate);
		this.source = audioSource.buffer.src;
	}

	private function get_currentFrame():Int
	{
		var dataLength:Int = 0;

		#if web
		dataLength = source.length;
		#else
		dataLength = audioBuffer.data.length;
		#end

		return Std.int(FlxMath.remapToRange(FlxG.sound.music.time, 0, FlxG.sound.music.length, 0, dataLength / 2));
	}
}