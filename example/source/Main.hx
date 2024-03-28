package;

import flixel.FlxGame;
import openfl.display.Sprite;
import openfl.display.FPS;

class Main extends Sprite
{
	public function new()
	{
		super();
		addChild(new FlxGame(0, 0, PlayState, 144, 144));
		addChild(new FPS(5, 5, 0xFFFFFFFF));
	}
}
