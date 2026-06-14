package states;

class ModsMenuState extends MusicBeatState
{
	var bg:FlxSprite;
	var grpSongs:FlxTypedGroup<Alphabet> = new FlxTypedGroup<Alphabet>();

	var descBox:FlxSprite;
	var descText:FlxText;

	var modsList:ModsList = null;

	override function create()
	{
		modsList = Mods.parseList();

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);
		bg.screenCenter();

		add(grpSongs);

		for (folder in Mods.getModDirectories())
		{
			if (folder.trim().length > 0
				&& FileSystem.exists(Paths.mods(folder))
				&& FileSystem.isDirectory(Paths.mods(folder))
				&& !Mods.ignoreModFolders.contains(folder.toLowerCase())
				&& !modsList.all.contains(folder))
			{
				modsList.all.push(folder);
			}
		}

		modsList.all.sort((a, b) ->
		{
			var aLower = a.toLowerCase();
			var bLower = b.toLowerCase();
			return aLower < bLower ? -1 : aLower > bLower ? 1 : 0;
		});

		for (i => m in modsList.all)
		{
			var text:Alphabet = new Alphabet(90, 320, m, true);
			text.isMenuItem = true;
			text.targetY = i;

			text.color = text.text == Mods.currentModDirectory ? FlxColor.LIME : FlxColor.WHITE;

			text.scaleX = Math.min(1, 980 / text.width);
			text.snapToPosition();

			grpSongs.add(text);
		}

		for (i => m in grpSongs.members)
		{
			if (m.text == Mods.currentModDirectory)
			{
				curMod = i;
				for (num => item in grpSongs.members)
					item.targetY = num - curMod;
				break;
			}
		}

		for (i => m in grpSongs.members)
			m.snapToPosition();

		descBox = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		descBox.alpha = 0.6;
		add(descBox);

		descText = new FlxText(50, 600, 1180, "", 32);
		descText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		descText.scrollFactor.set();
		descText.borderSize = 2.4;
		add(descText);

		changeMod(0);

		super.create();
	}

	var canControl:Bool = true;
	var holdTime:Float = 0;

	override function update(elapsed:Float)
	{
		if (canControl)
		{
			if (controls.BACK)
			{
				canControl = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(MusicBeatState.getClassFromStateMap("MainMenuState"));
			}

			if (controls.UI_UP_P)
			{
				changeMod(-1);
				holdTime = 0;
			}
			if (controls.UI_DOWN_P)
			{
				changeMod(1);
				holdTime = 0;
			}

			if (controls.UI_DOWN || controls.UI_UP)
			{
				var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
				holdTime += elapsed;
				var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

				if (holdTime > 0.5 && checkNewHold - checkLastHold > 0)
					changeMod((checkNewHold - checkLastHold) * (controls.UI_UP ? -1 : 1));
			}

			if (FlxG.mouse.wheel != 0)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
				changeMod(-1 * FlxG.mouse.wheel);
			}

			if (controls.ACCEPT)
			{
				persistentUpdate = false;

				TitleState.initialized = false;
				TitleState.closedState = false;
				MainMenuState.menuSong = "freakyMenu";

				FlxG.autoPause = ClientPrefs.data.autoPause;
				FlxG.mouse.visible = false;

				var curMod:String = modsList.all[curMod];
				Mods.currentModDirectory = Mods.currentModDirectory == curMod ? '' : curMod;

				modsList.disabled = [];
				modsList.enabled = [];

				for (m in modsList.all)
					modsList.disabled.push(m);
				for (m in modsList.all)
					if (m == Mods.currentModDirectory)
					{
						modsList.disabled.remove(m);
						modsList.enabled.push(m);
						break;
					}

				saveTxt();

				CustomFadeTransition.finishCallback = () -> FlxG.resetGame();
				openSubState(new CustomFadeTransition(0.5, false));
			}
		}

		super.update(elapsed);
	}

	var curMod:Int = 0;

	function changeMod(value:Int)
	{
		curMod = FlxMath.wrap(curMod + value, 0, modsList.all.length - 1);
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		for (num => item in grpSongs.members)
		{
			item.targetY = num - curMod;
			item.alpha = 0.6;
			if (item.targetY == 0)
				item.alpha = 1;
		}

		FlxTween.cancelTweensOf(bg);
		var pack:Dynamic = Mods.getPack(modsList.all[curMod]);
		FlxTween.color(bg, 0.5, bg.color, FlxColor.fromRGB(pack.color[0], pack.color[1], pack.color[2]), {ease: FlxEase.linear});

		descText.text = pack.description != null ? pack.description : '';
		descText.screenCenter(Y);
		descText.y += 270;

		descBox.setPosition(descText.x - 10, descText.y - 10);
		descBox.setGraphicSize(Std.int(descText.width + 20), Std.int(descText.height + 25));
		descBox.updateHitbox();
	}

	function saveTxt()
	{
		var fileStr:String = '';
		for (mod in modsList.all)
		{
			if (mod.trim().length < 1)
				continue;

			if (fileStr.length > 0)
				fileStr += '\n';

			var on = '1';
			if (modsList.disabled.contains(mod))
				on = '0';
			fileStr += '$mod|$on';
		}

		var path:String = 'modsList.txt';
		File.saveContent(path, fileStr);
		Mods.parseList();
		Mods.loadTopMod();
	}
}
