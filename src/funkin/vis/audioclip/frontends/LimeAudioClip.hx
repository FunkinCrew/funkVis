package funkin.vis.audioclip.frontends;

import haxe.Int64;
import flixel.FlxG;
import flixel.math.FlxMath;
import funkin.vis.AudioBuffer;
import lime.media.AudioSource;

/**
 * Implementation of AudioClip for Lime.
 * On OpenFL you will want SoundChannel.__source (with @:privateAccess)
 * For Flixel, you will want to get the FlxSound._channel.__source
 *
 * Note: On one of the recent OpenFL versions (9.3.2)
 * __source was renamed to __audioSource
 * https://github.com/openfl/openfl/commit/eec48a
 *
 */
class LimeAudioClip implements funkin.vis.AudioClip
{
	public var audioBuffer(default, null):AudioBuffer;
    public var currentFrame(get, never):Int;
	public var source:Dynamic;
	public var streamed:Bool;

	public function new(audioSource:AudioSource)
	{
		var limeBuffer = audioSource.buffer;
		var data:lime.utils.UInt16Array = cast limeBuffer.data;

		#if web
		streamed = false;

		var sampleRate:Float = limeBuffer.src._sounds[0]._node.context.sampleRate;
		var length:Int = audioSource.length;
		var bitsPerSample:Int = 32;
		var channels:Int = 2;
		#else
		var sampleRate:Float = 0;
		var length:Int = 0;
		var bitsPerSample:Int = 0;
		var channels:Int = 0;

		#if lime_vorbis
		// If we have a ref to a VorbisFile it should be safe to assume
		// this is a streamed sound!
		@:privateAccess
		if (limeBuffer.__srcVorbisFile != null)
		{
			streamed = true;

			var vorbisFile = limeBuffer.__srcVorbisFile;
			var vorbisInfo = vorbisFile.info();
			
			sampleRate = vorbisInfo.rate;
			bitsPerSample = 16;
			length = Std.int(Int64.toInt(vorbisFile.pcmTotal()) * vorbisInfo.channels * (bitsPerSample / 8));
			channels = vorbisInfo.channels;
		}
		else
		#end
		{
			streamed = false;

			sampleRate = limeBuffer.sampleRate;
			bitsPerSample = limeBuffer.bitsPerSample;
			length = limeBuffer.data.length;
			channels = limeBuffer.channels;
		}
		#end

		this.audioBuffer = new AudioBuffer(data, sampleRate, length, bitsPerSample, channels);
		this.source = audioSource.buffer.src;
	}

	private function get_currentFrame():Int
	{
		var value = Std.int(FlxMath.remapToRange(FlxG.sound.music.time, 0, FlxG.sound.music.length, 0, audioBuffer.length));

		if (value < 0)
			return -1;

		return value;
	}
}
