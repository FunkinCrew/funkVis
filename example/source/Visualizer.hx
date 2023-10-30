package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxColor;
import funkVis.AudioClip;
import funkVis.dsp.SpectralAnalyzer;

class Visualizer extends FlxGroup
{
    var grpBars:FlxTypedGroup<FlxSprite>;
    var analyzer:SpectralAnalyzer;

    public function new(audioClip:AudioClip, barCount:Int = 8)
    {
        super();

        analyzer = new SpectralAnalyzer(barCount, audioClip, 0.001);
        grpBars = new FlxTypedGroup<FlxSprite>();
		add(grpBars);

		for (i in 0...barCount)
		{
			var spr = new FlxSprite((i / barCount) * FlxG.width, 0).makeGraphic(Std.int((1 / barCount) * FlxG.width) - 4, 1, FlxColor.RED);
			grpBars.add(spr);
		}
    }

    static inline function min(x:Int, y:Int):Int
    {
        return x > y ? y : x;
    }

    override function draw()
    {
        var levels = analyzer.getLevels();

        for (i in 0...min(grpBars.members.length, levels.length)) {
            grpBars.members[i].scale.y = levels[i] * FlxG.height;
            grpBars.members[i].y = FlxG.height - grpBars.members[i].height;
        }

        super.draw();
    }
}
