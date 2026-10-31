package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import funkin.vis.dsp.SpectralAnalyzer;
import lime.media.AudioSource;

class Visualizer extends FlxGroup
{
	var grpBars:FlxTypedGroup<FlxSprite>;
	var analyzer:SpectralAnalyzer;
	var displayedValues:Array<Float> = [];

	public function new(audioSource:AudioSource, barCount:Int = 32)
	{
		super();

		analyzer = new SpectralAnalyzer(audioSource, barCount, 0.1, 10);

		grpBars = new FlxTypedGroup<FlxSprite>();
		add(grpBars);

		for (i in 0...barCount)
		{
			displayedValues[i] = 0.0;

			var spr = new FlxSprite((i / barCount) * FlxG.width, 0).makeGraphic(Std.int((1 / barCount) * FlxG.width) - 4, FlxG.height, 0x771E3A8A);
			spr.origin.set(0, FlxG.height);
			grpBars.add(spr);
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		var levels = analyzer.getLevels();
		var len = Std.int(Math.min(grpBars.members.length, levels.length));
		var lerpSpeed:Float = Math.min(1.0, elapsed * 16.0);

		for (i in 0...len)
		{
			displayedValues[i] = FlxMath.lerp(displayedValues[i], levels[i].value, lerpSpeed);
			grpBars.members[i].scale.y = displayedValues[i];
		}
	}

	override function destroy():Void
	{
		if (analyzer != null)
		{
			analyzer.dispose();
			analyzer = null;
		}

		super.destroy();
	}
}
