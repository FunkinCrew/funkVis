package funkin.vis.audioclip.frontends;

import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.sound.FlxSound;
import funkin.vis.AudioBuffer;
import lime.media.AudioSource;
import funkin.vis.dsp.SpectralAnalyzer;

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
	public var audioSource(default, null):AudioSource;
	public var audioBuffer(default, null):AudioBuffer;
	public var currentFrame(get, never):Int;
	public var source:Dynamic;
	public var soundInstance(default, set):FlxSound;

	public function new(?soundInstance:FlxSound)
	{
		if (soundInstance == null)
			this.soundInstance = FlxG.sound.music;
		else
			this.soundInstance = soundInstance;
	}

	function set_soundInstance(value:FlxSound):FlxSound
	{
		this.soundInstance = value;
		this.audioSource = getSoundChannelSource(value);
		var data:lime.utils.UInt16Array = cast audioSource.buffer.data;

		#if web
		var sampleRate:Float = audioSource.buffer.src._sounds[0]._node.context.sampleRate;
		#else
		var sampleRate = audioSource.buffer.sampleRate;
		#end

		this.audioBuffer = new AudioBuffer(data, sampleRate);
		this.source = audioSource.buffer.src;

		return value;
	}

	private function get_currentFrame():Int
	{
		var dataLength:Int = 0;

		#if web
		dataLength = source.length;
		#else
		dataLength = audioBuffer.data.length;
		#end

		return Std.int(FlxMath.remapToRange(soundInstance.time, 0, soundInstance.length, 0, dataLength));
	}

	/**
	 * Gets an FlxSound audio source, mainly used for visualisers.
	 *
	 * @param input The byte data.
	 * @return The playable sound, or `null` if loading failed.
	 */
	public static function getSoundChannelSource(input:FlxSound):AudioSource
	{
	  #if (openfl < "9.3.2") @:privateAccess
	  return input._channel.__source;
	  // if (input._channel.__source != null)
	  #else
	  @:privateAccess
	  return input._channel.__audioSource;
	  // if (input._channel.__audioSource != null) return input._channel.__audioSource;
	  #end
	  return null;
	}
}
