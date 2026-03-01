package funkin.vis.audioclip.frontends;

import flixel.FlxG;
import flixel.math.FlxMath;
import lime.media.AudioContextType;
import lime.media.AudioSource;
import lime.media.AudioManager;

#if lime_funkin
import lime.utils.Float32Array;
#elseif !js
import lime.utils.ArrayBufferView.ArrayBufferIO;
#end

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
	public var audioSource:AudioSource;
	public var channels(get, never):Int;
	public var sampleRate(get, never):Int;

	public function new(audioSource:AudioSource)
	{
		this.audioSource = audioSource;
	}

	inline function get_channels():Int
	{
		#if (js && html5 && howlerjs)
		if (audioSource.buffer != null && audioSource.buffer.channels > 0) return audioSource.buffer.channels;
		return 2;
		#else
		return audioSource.buffer != null ? audioSource.buffer.channels : 0;
		#end
	}

	inline function get_sampleRate():Int
	{
		#if (js && html5 && howlerjs)
		if (audioSource.buffer != null && audioSource.buffer.sampleRate > 0) return audioSource.buffer.sampleRate;
		else if (AudioManager.context != null && AudioManager.context.type == AudioContextType.WEB) return Std.int(AudioManager.context.web.sampleRate);
		return 44100;
		#else
		return audioSource.buffer != null ? audioSource.buffer.sampleRate : 0;
		#end
	}

	// Prevents a memory leak by reusing array
	var _buffer:Array<Float> = [];

	#if lime_funkin
	var _array:Float32Array;

	public function getTimeDomainData(fftN:Int):Array<Float>
	{
		// Allocate it first!
		if (fftN > _buffer.length) _buffer.resize(fftN);

		if (_array == null || fftN > _array.length) _array = new Float32Array(fftN);

		var len = audioSource.getFloatTimeDomainData(_array, fftN);

		for (i in 0...len) _buffer[i] = _array[i];
		for (i in len...fftN) _buffer[i] = 0;
		return _buffer;
	}
	#elseif !js
	public function getTimeDomainData(fftN:Int):Array<Float>
	{
		// Allocate it first!
		if (fftN > _buffer.length) _buffer.resize(fftN);

		inline function empty()
		{
			for (i in 0...fftN) _buffer[i] = 0;
			return _buffer;
		}

		var audioBuffer = audioSource.buffer;
		if (audioBuffer == null) return empty();

		var byteRate:Int = audioBuffer.bitsPerSample >> 3;
		var currentFrame:Int = (Std.int(audioSource.currentTime / 1000 * audioBuffer.sampleRate) - fftN) * audioBuffer.channels * byteRate;

		if (currentFrame <= 0) return empty();

		var valueSize:Int = 1 << (audioBuffer.bitsPerSample - 1);
		var buffer = audioBuffer.data.buffer, pos = 0, v = 0, c = 0;

		inline function idiv(num:Int, denom:Int):Int
		{
			return #if (cpp && !cppia) cpp.NativeMath.idiv(num, denom) #else Std.int(num / denom) #end;
		}

		while (pos < fftN)
		{
			switch (byteRate)
			{
				case 2: v = idiv(ArrayBufferIO.getInt16(buffer, currentFrame), audioBuffer.channels);
				case 3:
					v = ArrayBufferIO.getUint16(buffer, currentFrame) | (buffer.get(currentFrame + 2) << 16);
					if (v & 0x800000 != 0) v -= 0x1000000;
					v = idiv(v, audioBuffer.channels);
				case 4: v = idiv(ArrayBufferIO.getInt32(buffer, currentFrame), audioBuffer.channels);
				default: v = idiv(ArrayBufferIO.getInt8(buffer, currentFrame), audioBuffer.channels);
			}

			c++;
			if (c == audioBuffer.channels)
			{
				_buffer[pos++] = v / valueSize;
				c = v = 0;
			}

			currentFrame += byteRate;
			if (currentFrame >= buffer.length)
			{
				for (i in pos...fftN) _buffer[i] = 0;
				break;
			}
		}

		return _buffer;
	}
	#else
	public function getTimeDomainData(fftN:Int):Array<Float>
	{
		throw "Your not supposed to use this in js!";
	}
	#end
}
