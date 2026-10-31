package funkin.vis.dsp;

/** Keeps a rolling history of recent values and tracks the highest one. */
class RecentPeakFinder
{
	/** Highest of the recent values. */
	public var peak(default, null):Float = 0;

	/** The most recently pushed value. */
	public var lastValue(get, never):Float;

	@:noCompletion
	private var buffer:Array<Float>;

	@:noCompletion
	private var index:Int;

	/**
	 * Initializes a RecentPeakFinder object.
	 * 
	 * @param length The number of recent values to remember.
	 */
	public function new(length:Int = 30):Void
	{
		buffer = [for (_ in 0...length) 0.0];
		index = 0;
	}

	/**
	 * Pushes a value into the history and updates the peak.
	 * 
	 * @param value The value to push.
	 */
	public function push(value:Float):Void
	{
		buffer[index] = value;

		peak = value > peak ? value : Lambda.fold(buffer, Math.max, buffer[0]);

		index = index + 1 == buffer.length ? 0 : index + 1;
	}

	@:noCompletion
	private function get_lastValue():Float
	{
		return index == 0 ? buffer[buffer.length - 1] : buffer[index - 1];
	}
}
