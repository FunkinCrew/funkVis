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
    var peakLines:FlxTypedGroup<FlxSprite>;
    var analyzer:SpectralAnalyzer;

    public function new(audioClip:AudioClip, barCount:Int = 8)
    {
        super();

        analyzer = new SpectralAnalyzer(barCount, audioClip, 0.005, 30);
        grpBars = new FlxTypedGroup<FlxSprite>();
		add(grpBars);
        peakLines = new FlxTypedGroup<FlxSprite>();
        add(peakLines);

		for (i in 0...barCount)
		{
			var spr = new FlxSprite((i / barCount) * FlxG.width, 0).makeGraphic(Std.int((1 / barCount) * FlxG.width) - 4, FlxG.height, 0x55ff0000);
            spr.origin.set(0, FlxG.height);
			grpBars.add(spr);
            spr = new FlxSprite((i / barCount) * FlxG.width, 0).makeGraphic(Std.int((1 / barCount) * FlxG.width) - 4, 1, 0xaaff0000);
            peakLines.add(spr);
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
            grpBars.members[i].scale.y = levels[i].value;
            peakLines.members[i].y = FlxG.height - (levels[i].peak * FlxG.height);
        }
        super.draw();
    }
}
