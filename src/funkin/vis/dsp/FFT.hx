package funkin.vis.dsp;

import haxe.ds.Vector;

/**
 * A Radix-2 FFT that turns a frame of audio samples into a magnitude spectrum.
 * 
 * @see https://github.com/osakared/grig.audio/blob/main/src/grig/audio/FFT.hx
 */
class FFT
{
	@:noCompletion
	private static final TWO_PI:Float = 2 * Math.PI;

	@:noCompletion
	private final frameSize:Int;

	@:noCompletion
	private final halfSize:Int;

	@:noCompletion
	private final windowTable:Vector<Float>;

	@:noCompletion
	private final bitReversal:Vector<Int>;

	@:noCompletion
	private final twiddleReal:Vector<Float>;

	@:noCompletion
	private final twiddleImag:Vector<Float>;

	@:noCompletion
	private final splitReal:Vector<Float>;

	@:noCompletion
	private final splitImag:Vector<Float>;

	@:noCompletion
	private final real:Vector<Float>;

	@:noCompletion
	private final imag:Vector<Float>;

	@:noCompletion
	private final magnitudes:Array<Float>;

	/**
	 * Initializes an FFT object.
	 * 
	 * @param frameSize The number of samples per frame. Must be a power of two and at least 4.
	 */
	public function new(frameSize:Int = 512):Void
	{
		if (frameSize < 4 || (frameSize & (frameSize - 1)) != 0)
		{
			throw 'FFT size must be a power of two >= 4 (got $frameSize)';
		}

		this.frameSize = frameSize;
		this.halfSize = frameSize >> 1;
		this.windowTable = new Vector<Float>(frameSize);
		this.bitReversal = new Vector<Int>(halfSize);
		this.twiddleReal = new Vector<Float>(halfSize);
		this.twiddleImag = new Vector<Float>(halfSize);
		this.splitReal = new Vector<Float>((halfSize >> 1) + 1);
		this.splitImag = new Vector<Float>((halfSize >> 1) + 1);
		this.real = new Vector<Float>(halfSize);
		this.imag = new Vector<Float>(halfSize);
		this.magnitudes = [for (_ in 0...halfSize) 0];

		generateTables();
	}

	/**
	 * Calculates the magnitude spectrum of a frame of samples.
	 * 
	 * @param data The samples to analyse. Only the first `frameSize` are read.
	 * @return The magnitudes of bins 1 to `frameSize / 2`. The same array is reused on every call, so copy it to keep a frame.
	 */
	public function calcFreq(data:Vector<Float>):Array<Float>
	{
		final quarterSize:Int = halfSize >> 1;

		for (index in 0...halfSize)
		{
			final target:Int = bitReversal[index];
			final sampleIndex:Int = index << 1;

			real[target] = data[sampleIndex] * windowTable[sampleIndex];
			imag[target] = data[sampleIndex + 1] * windowTable[sampleIndex + 1];
		}

		doFFT();

		final scale:Float = 2.0 / frameSize;

		for (bin in 1...quarterSize)
		{
			final lowReal:Float = real[bin];
			final lowImag:Float = imag[bin];
			final mirrorReal:Float = real[halfSize - bin];
			final mirrorImag:Float = imag[halfSize - bin];
			final evenReal:Float = (lowReal + mirrorReal) * 0.5;
			final evenImag:Float = (lowImag - mirrorImag) * 0.5;
			final diffReal:Float = (lowReal - mirrorReal) * 0.5;
			final diffImag:Float = (lowImag + mirrorImag) * 0.5;
			final cosine:Float = splitReal[bin];
			final sine:Float = splitImag[bin];
			final rotatedReal:Float = cosine * diffImag + sine * diffReal;
			final rotatedImag:Float = sine * diffImag - cosine * diffReal;
			final binReal:Float = evenReal + rotatedReal;
			final binImag:Float = evenImag + rotatedImag;
			final mirrorBinReal:Float = evenReal - rotatedReal;
			final mirrorBinImag:Float = evenImag - rotatedImag;

			magnitudes[bin - 1] = scale * Math.sqrt(binReal * binReal + binImag * binImag);
			magnitudes[halfSize - bin - 1] = scale * Math.sqrt(mirrorBinReal * mirrorBinReal + mirrorBinImag * mirrorBinImag);
		}

		final bin:Int = quarterSize;
		final lowReal:Float = real[bin];
		final lowImag:Float = imag[bin];
		final mirrorReal:Float = real[halfSize - bin];
		final mirrorImag:Float = imag[halfSize - bin];
		final diffReal:Float = (lowReal - mirrorReal) * 0.5;
		final diffImag:Float = (lowImag + mirrorImag) * 0.5;
		final cosine:Float = splitReal[bin];
		final sine:Float = splitImag[bin];
		final binReal:Float = (lowReal + mirrorReal) * 0.5 + (cosine * diffImag + sine * diffReal);
		final binImag:Float = (lowImag - mirrorImag) * 0.5 + (sine * diffImag - cosine * diffReal);

		magnitudes[bin - 1] = scale * Math.sqrt(binReal * binReal + binImag * binImag);
		magnitudes[halfSize - 1] = Math.abs(real[0] - imag[0]) / frameSize;

		return magnitudes;
	}

	@:noCompletion
	private function generateTables():Void
	{
		for (i in 0...frameSize)
		{
			windowTable[i] = 1 - 0.85 * Math.cos(i * (TWO_PI / frameSize));
		}

		var bitCount:Int = 0;

		while ((1 << bitCount) < halfSize)
		{
			bitCount++;
		}

		for (i in 0...halfSize)
		{
			var remaining:Int = i;
			var reversedValue:Int = 0;

			for (_ in 0...bitCount)
			{
				reversedValue = (reversedValue << 1) | (remaining & 1);
				remaining >>= 1;
			}

			bitReversal[i] = reversedValue;
		}

		var halfBlock:Int = 1;

		while (halfBlock < halfSize)
		{
			for (offset in 0...halfBlock)
			{
				final angle:Float = TWO_PI * offset / (2 * halfBlock);

				twiddleReal[halfBlock + offset] = Math.cos(angle);

				twiddleImag[halfBlock + offset] = -Math.sin(angle);
			}

			halfBlock <<= 1;
		}

		for (bin in 0...splitReal.length)
		{
			final angle:Float = TWO_PI * bin / frameSize;

			splitReal[bin] = Math.cos(angle);

			splitImag[bin] = -Math.sin(angle);
		}
	}

	@:noCompletion
	private function doFFT():Void
	{
		if (halfSize < 4)
		{
			final firstReal:Float = real[0];
			final firstImag:Float = imag[0];
			final secondReal:Float = real[1];
			final secondImag:Float = imag[1];

			real[0] = firstReal + secondReal;
			imag[0] = firstImag + secondImag;
			real[1] = firstReal - secondReal;
			imag[1] = firstImag - secondImag;

			return;
		}

		var index:Int = 0;

		while (index < halfSize)
		{
			final x0Real:Float = real[index];
			final x0Imag:Float = imag[index];
			final x1Real:Float = real[index + 1];
			final x1Imag:Float = imag[index + 1];
			final x2Real:Float = real[index + 2];
			final x2Imag:Float = imag[index + 2];
			final x3Real:Float = real[index + 3];
			final x3Imag:Float = imag[index + 3];
			final sum01Real:Float = x0Real + x1Real;
			final sum01Imag:Float = x0Imag + x1Imag;
			final diff01Real:Float = x0Real - x1Real;
			final diff01Imag:Float = x0Imag - x1Imag;
			final sum23Real:Float = x2Real + x3Real;
			final sum23Imag:Float = x2Imag + x3Imag;
			final diff23Real:Float = x2Real - x3Real;
			final diff23Imag:Float = x2Imag - x3Imag;

			real[index] = sum01Real + sum23Real;
			imag[index] = sum01Imag + sum23Imag;
			real[index + 2] = sum01Real - sum23Real;
			imag[index + 2] = sum01Imag - sum23Imag;
			real[index + 1] = diff01Real + diff23Imag;
			imag[index + 1] = diff01Imag - diff23Real;
			real[index + 3] = diff01Real - diff23Imag;
			imag[index + 3] = diff01Imag + diff23Real;

			index += 4;
		}

		var halfBlock:Int = 4;

		while (halfBlock < halfSize)
		{
			final blockSize:Int = halfBlock << 1;

			var blockStart:Int = 0;

			while (blockStart < halfSize)
			{
				for (offset in 0...halfBlock)
				{
					final weightReal:Float = twiddleReal[halfBlock + offset];
					final weightImag:Float = twiddleImag[halfBlock + offset];
					final lowerIndex:Int = blockStart + offset;
					final upperIndex:Int = lowerIndex + halfBlock;
					final upperReal:Float = real[upperIndex];
					final upperImag:Float = imag[upperIndex];
					final rotatedReal:Float = weightReal * upperReal - weightImag * upperImag;
					final rotatedImag:Float = weightReal * upperImag + weightImag * upperReal;
					final lowerReal:Float = real[lowerIndex];
					final lowerImag:Float = imag[lowerIndex];

					real[lowerIndex] = lowerReal + rotatedReal;
					imag[lowerIndex] = lowerImag + rotatedImag;
					real[upperIndex] = lowerReal - rotatedReal;
					imag[upperIndex] = lowerImag - rotatedImag;
				}

				blockStart += blockSize;
			}

			halfBlock = blockSize;
		}
	}
}
