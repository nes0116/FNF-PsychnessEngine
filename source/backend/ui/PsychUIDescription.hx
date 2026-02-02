package backend.ui;

class PsychUIDescription extends FlxSpriteGroup
{
	public var bg:FlxSprite;
	public var text:FlxText;

	public var description(default, set):String = '';

	public function new(x:Float, y:Float, description:String)
	{
		super(x, y);

		bg = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		bg.alpha = 0.75;
		add(bg);

		text = new FlxText(5, 5, 0, '');
		text.applyMarkup(description, [new FlxTextFormatMarkerPair(new FlxTextFormat(0xFFFF0000, false, false), "{warn}")]);
		add(text);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
	}

	public function resize(width:Int, height:Int)
	{
		bg.setGraphicSize(width, height);
		bg.updateHitbox();
		text.x = bg.x + width / 2 - text.width / 2;
		text.y = bg.y + height / 2 - text.height / 2;
	}

	function set_description(v:String)
	{
		text.applyMarkup(v, [new FlxTextFormatMarkerPair(new FlxTextFormat(0xFFFF0000, false, false), "{warn}")]);
		resize(Std.int(text.width + 10), Std.int(text.height + 10));
		return (description = v);
	}
}
