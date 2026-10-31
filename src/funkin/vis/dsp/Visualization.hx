package funkin.vis.dsp;

import haxe.ds.Vector;

/**
 * Converts FFT magnitudes into logarithmically spaced bar heights.
 * 
 * @see https://github.com/osakared/grig.audio/blob/main/src/grig/audio/FFTVisualization.hx
 */
class Visualization
{
	@:noCompletion
	private static inline final DB_PER_LN:Float = 8.685889638065035;

	@:noCompletion
	private var cachedBands:Int = -1;

	@:noCompletion
	private var cachedBins:Int = -1;

	@:noCompletion
	private var cachedLow:Float = -1;

	@:noCompletion
	private var cachedHigh:Float = -1;

	@:noCompletion
	private var lowIndices:Vector<Int>;

	@:noCompletion
	private var highIndices:Vector<Int>;

	@:noCompletion
	private var lowWeights:Vector<Float>;

	@:noCompletion
	private var highWeights:Vector<Float>;

	@:noCompletion
	private var gain:Float = 1;

	@:noCompletion
	private var internalGraph:Array<Int> = [];

	/** Initializes a Visualization object. */
	public function new():Void
	{
		// There isnt anything to initialize.
	}

	/**
	 * Converts FFT magnitudes into logarithmically spaced bar heights.
	 * 
	 * @param magnitudes The magnitudes returned by `FFT.calcFreq()`.
	 * @param bands The number of bars to produce.
	 * @param dbRange The decibel range below full scale (0 dB) that is mapped onto `0` to `intRange`.
	 * @param intRange The maximum bar height.
	 * @param graph (Optional) The array to fill. When omitted, an internal array is reused between calls.
	 * @param lowBin The bin number where the first bar starts, where `1` is the first bin after DC.
	 * @param highBin The bin number where the last bar ends, or `0` for the top of the spectrum.
	 * @return The bar heights, each from `0` to `intRange`.
	 */
	public function makeLogGraph(magnitudes:Array<Float>, bands:Int, dbRange:Int, intRange:Int, ?graph:Array<Int>, lowBin:Float = 1,
			highBin:Float = 0):Array<Int>
	{
		final bins:Int = magnitudes.length;

		var low:Float = lowBin < 1 ? 1 : lowBin;
		var high:Float = (highBin <= 0 || highBin > bins) ? bins : highBin;

		if (low > bins - 1)
		{
			low = bins - 1;
		}

		if (high < low + 1)
		{
			high = low + 1;
		}

		if (cachedBands != bands || cachedBins != bins || cachedLow != low || cachedHigh != high)
		{
			prepare(bands, bins, low, high);
		}

		if (graph == null)
		{
			graph = internalGraph;
		}

		if (graph.length != bands)
		{
			graph.resize(bands);
		}

		final invDb:Float = 1 / dbRange;
		final top:Float = intRange;

		for (bandIndex in 0...bands)
		{
			var lowIndex:Int = lowIndices[bandIndex];
			final highIndex:Int = highIndices[bandIndex];
			var magnitudeSum:Float = 0;

			if (highIndex < lowIndex)
			{
				magnitudeSum = magnitudes[highIndex] * lowWeights[bandIndex];
			}
			else
			{
				if (lowIndex > 0)
				{
					magnitudeSum += magnitudes[lowIndex - 1] * lowWeights[bandIndex];
				}

				while (lowIndex < highIndex)
				{
					magnitudeSum += magnitudes[lowIndex];
					lowIndex++;
				}

				if (highIndex < bins)
				{
					magnitudeSum += magnitudes[highIndex] * highWeights[bandIndex];
				}
			}

			magnitudeSum *= gain;

			if (magnitudeSum <= 0)
			{
				graph[bandIndex] = 0;
				continue;
			}

			final val:Float = (1 + (Math.log(magnitudeSum) * DB_PER_LN) * invDb) * top;

			graph[bandIndex] = val > 0 ? (val < top ? Std.int(val) : intRange) : 0;
		}

		return graph;
	}

	private function prepare(bands:Int, bins:Int, low:Float, high:Float):Void
	{
		if (lowIndices == null || lowIndices.length != bands)
		{
			lowIndices = new Vector<Int>(bands);
			highIndices = new Vector<Int>(bands);
			lowWeights = new Vector<Float>(bands);
			highWeights = new Vector<Float>(bands);
		}

		final frequencyRatio:Float = high / low;

		for (bandIndex in 0...bands)
		{
			final startPosition:Float = low * Math.pow(frequencyRatio, bandIndex / bands) - 0.5;
			final endPosition:Float = low * Math.pow(frequencyRatio, (bandIndex + 1) / bands) - 0.5;
			final startIndex:Int = Math.ceil(startPosition);
			final endIndex:Int = Math.floor(endPosition);

			lowIndices[bandIndex] = startIndex;
			highIndices[bandIndex] = endIndex;

			if (endIndex < startIndex)
			{
				lowWeights[bandIndex] = endPosition - startPosition;
				highWeights[bandIndex] = 0;
			}
			else
			{
				lowWeights[bandIndex] = startIndex > 0 ? startIndex - startPosition : 0;
				highWeights[bandIndex] = endIndex < bins ? endPosition - endIndex : 0;
			}
		}

		gain = bands / 12;
		cachedBands = bands;
		cachedBins = bins;
		cachedLow = low;
		cachedHigh = high;
	}
}
