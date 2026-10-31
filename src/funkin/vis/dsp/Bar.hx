package funkin.vis.dsp;

/** A spectrum bar. */
@:structInit
class Bar
{
	/** Current level, from 0.0 to 1.0. */
	public var value:Float;

	/** Recent peak of `value`, from 0.0 to 1.0. */
	public var peak:Float;
}
