package backend.ui;

class PsychUISpriteGroup extends FlxSpriteGroup
{
	public var descriptionBox:PsychUIDescription;
	public var description(default, set):String = '';

	public function new(x:Float, y:Float)
	{
		super(x, y);

		descriptionBox = new PsychUIDescription(0, 0, description);
		descriptionBox.visible = false;
	}

	var _overlapTimer:Float = 0;

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (FlxG.mouse.overlaps(this, camera))
			_overlapTimer += elapsed;
		else
			_overlapTimer = 0;

		if (_overlapTimer > 0.4 && !(FlxG.mouse.overlaps(this, camera) && FlxG.mouse.justPressed))
		{
			if (description.length < 1)
				return;

			if (!FlxG.state.members.contains(descriptionBox))
			{
				FlxG.state.add(descriptionBox);
				descriptionBox.cameras = cameras;
			}

			if (!descriptionBox.visible)
			{
				descriptionBox.x = FlxG.mouse.screenX < FlxG.width / 2 ? FlxG.mouse.screenX + 15 : FlxG.mouse.screenX - descriptionBox.width - 15;
				descriptionBox.y = FlxG.mouse.screenY + 15;
			}

			descriptionBox.visible = true;
		}
		else
		{
			descriptionBox.visible = false;
			if (FlxG.state.members.contains(descriptionBox))
				FlxG.state.remove(descriptionBox);
		}
	}

	function set_description(v:String)
	{
		descriptionBox.description = v;
		return (description = v);
	}
}
