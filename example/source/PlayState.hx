package;

import flixel.FlxG;
import flixel.FlxState;
import openfl.display.FPS;

class PlayState extends FlxState
{
	override function create():Void
	{
		FlxG.autoPause = false;

		FlxG.mouse.useSystemCursor = true;

		FlxG.game.addChild(new FPS(10, 10, 0xFFFFFFFF));

		FlxG.game.focusLostFramerate = 60;

		FlxG.sound.playMusic('assets/medlyForAGamer.ogg');

		@:privateAccess
		add(new Visualizer(FlxG.sound.music._source));

		super.create();
	}

	override function update(elapsed:Float):Void
	{
		if (FlxG.keys.justPressed.SPACE)
		{
			if (FlxG.sound.music.playing)
			{
				FlxG.sound.music.pause();
			}
			else
			{
				FlxG.sound.music.resume();
			}
		}

		super.update(elapsed);
	}
}
