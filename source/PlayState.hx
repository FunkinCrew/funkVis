package;

import flixel.FlxSprite;
import flixel.FlxState;

class PlayState extends FlxState
{
	var spr:FlxSprite;

	override public function create()
	{
		super.create();

		spr = new FlxSprite(0, 0);
		spr.makeGraphic(100, 100, 0xff0000ff);
		add(spr);
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);
	}
}
