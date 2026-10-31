package funkin.vis.dsp;

/** A spectrum bar's frequency range and history. */
@:structInit
class BarObject
{
	/** First FFT bin of the bar. */
	public var binLo:Int;

	/** Last FFT bin of the bar. */
	public var binHi:Int;

	/** Lowest frequency of the bar, in Hz. */
	public var freqLo:Float;

	/** Highest frequency of the bar, in Hz. */
	public var freqHi:Float;

	/** Recent values used to find the bar's peak. */
	public var recentValues:RecentPeakFinder;
}
