package states;

import flixel.input.mouse.FlxMouseEvent;
import options.ModSettingsSubState;
import flixel.graphics.FlxGraphic;
import openfl.filters.GlowFilter;
import flixel.util.FlxGradient;
import flixel.FlxObject;
import openfl.display.BitmapData;

class ModsMenuState extends MusicBeatState
{
	var bg:FlxSprite;
	var bgHeader:FlxSprite;
	var blackScreen:FlxSprite;
	var directory:FlxSprite;

	var camFollow:FlxObject;

	var grpPackages:FlxTypedGroup<Package> = new FlxTypedGroup<Package>();

	var curMod:Int = 0;
	var modLength:Int = 0;

	var descText:FlxText;
	var openModsFolderText:FlxText;

	var modsList:ModsList = null;
	var curModData:Dynamic = null;

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		super.create();

		persistentUpdate = true;

		modsList = Mods.parseList();
		curModData = Mods.getPack(Mods.currentModDirectory);

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set();
		add(bg);
		bg.screenCenter();

		bgHeader = new FlxSprite();
		bgHeader.antialiasing = ClientPrefs.data.antialiasing;
		bgHeader.scrollFactor.set();
		add(bgHeader);
		bgHeader.visible = false;
		bgHeader.screenCenter();

		blackScreen = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		blackScreen.antialiasing = ClientPrefs.data.antialiasing;
		blackScreen.scrollFactor.set();
		add(blackScreen);
		blackScreen.screenCenter();

		var gradient:FlxSprite = FlxGradient.createGradientFlxSprite(FlxG.width, Std.int(FlxG.height / 1.25), [0x0, FlxColor.BLACK]);
		gradient.scrollFactor.set();
		add(gradient);

		var black:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, Std.int(FlxG.height - gradient.height), FlxColor.BLACK);
		black.scrollFactor.set();
		black.y = gradient.y + gradient.height;
		add(black);

		add(grpPackages);

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
			var pack:Package = new Package((Package.packageWidth + 30) * i, 0, m);
			pack.ID = i;
			pack.screenCenter(Y);
			pack.y += 50;
			grpPackages.add(pack);

			if (i == 0)
				FlxG.camera.minScrollX = pack.x - 50;
			FlxG.camera.maxScrollX = pack.x + pack.width + 50;

			if (m == Mods.currentModDirectory)
			{
				curMod = i;

				directory = new FlxSprite().loadGraphic(Paths.image('directory'));
				directory.antialiasing = ClientPrefs.data.antialiasing;
				directory.y = pack.label.y + pack.label.height / 2 - directory.height / 2;
				directory.color = pack.label.color;
				add(directory);
			}

			modLength++;
		}

		var startIndex:Int = modLength;
		if (startIndex < 10)
		{
			for (i in 0...10 - startIndex)
			{
				var pack:Package = new Package((350 * startIndex) + 350 * i, 0, '//');
				pack.ID = startIndex + i;
				pack.screenCenter(Y);
				pack.x += Package.packageWidth / 2;
				pack.x += -Package.packageWidth / 4;
				pack.y += 50;
				grpPackages.add(pack);

				if (i == 0)
					FlxG.camera.minScrollX = Math.min(FlxG.camera.minScrollX, pack.x - 50);
				FlxG.camera.maxScrollX = Math.max(FlxG.camera.maxScrollX, pack.x + pack.width + 50);

				modLength++;
			}
		}

		descText = new FlxText(50, 600, 1180, "", 32);
		descText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		descText.scrollFactor.set();
		descText.borderSize = 2.4;
		add(descText);

		openModsFolderText = new FlxText(0, 0, 0, "Open Mods Folder...", 32);
		openModsFolderText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		openModsFolderText.scrollFactor.set();
		openModsFolderText.borderSize = 2.4;
		openModsFolderText.alpha = 0.75;
		openModsFolderText.x = FlxG.width - openModsFolderText.width - 10;
		openModsFolderText.y = 10;
		add(openModsFolderText);
		FlxMouseEvent.add(openModsFolderText, (_) ->
		{
			CoolUtil.openFolder('mods/');
		}, null, (_) ->
			{
				_.alpha = 1;
			}, (_) ->
			{
				_.alpha = 0.75;
			}, false, true, false);

		camFollow = new FlxObject(0, FlxG.height / 2 - 1, 2, 2);
		add(camFollow);

		changeMod(0);

		FlxG.camera.follow(camFollow, LOCKON, 10);
		FlxG.camera.deadzone.x = 380;
		FlxG.camera.deadzone.width = 542;

		new FlxTimer().start(0.01, (_) -> FlxG.camera.followLerp = 0.25);

		FlxG.mouse.visible = true;
	}

	var canControl:Bool = true;
	var holdTime:Float = 0;

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (canControl)
		{
			if (controls.BACK)
			{
				canControl = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(MusicBeatState.getClassFromStateMap("MainMenuState"));
			}

			if (controls.UI_LEFT_P)
			{
				changeMod(-1);
				holdTime = 0;
			}
			if (controls.UI_RIGHT_P)
			{
				changeMod(1);
				holdTime = 0;
			}

			if (controls.UI_LEFT || controls.UI_RIGHT)
			{
				var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
				holdTime += elapsed;
				var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

				if (holdTime > 0.5 && checkNewHold - checkLastHold > 0)
					changeMod((checkNewHold - checkLastHold) * (controls.UI_LEFT ? -1 : 1));
			}

			if (FlxG.mouse.wheel != 0)
			{
				FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
				changeMod(-1 * FlxG.mouse.wheel);
			}

			if (controls.ACCEPT)
			{
				if (grpPackages.members[curMod].isBlank)
					return;

				if (!FileSystem.exists('mods/${grpPackages.members[curMod].modDirectory}/pack.json'))
				{
					FlxG.sound.play(Paths.sound('cancelMenu'));
					return;
				}

				persistentUpdate = false;

				canControl = false;

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

				FlxG.sound.play(Paths.sound('cancelMenu'));
				FlxG.sound.music.fadeOut(0.3);
				if (FreeplayState.vocals != null)
				{
					FreeplayState.vocals.fadeOut(0.3);
					FreeplayState.vocals = null;
				}
				FlxG.camera.fade(FlxColor.BLACK, 0.5, false, FlxG.resetGame, false);

				// CustomFadeTransition.finishCallback = () -> FlxG.resetGame();
				// openSubState(new CustomFadeTransition(0.5, false));
			}

			{
				var curMod:Dynamic = grpPackages.members[curMod];
				if (FlxG.keys.justPressed.CONTROL
					&& curMod != null
					&& curMod.settings != null
					&& curMod.settings.length > 0
					&& Mods.getPack(curMod.modDirectory) != null)
				{
					persistentUpdate = false;
					openSubState(new ModSettingsSubState(curMod.settings, curMod.modDirectory, Mods.getPack(curMod.modDirectory).name));
				}
			}
		}

		try
		{
			bgHeader.alpha = FlxMath.lerp(FileSystem.exists('mods/${modsList.all[curMod]}/header.png') ? 1 : 0, bgHeader.alpha, Math.exp(-elapsed * 5));
			blackScreen.alpha = FlxMath.lerp(0.5, blackScreen.alpha, Math.exp(-elapsed * 1));
		}
		catch (e)
		{
		}

		for (pack in grpPackages)
		{
			pack.selected = pack.ID == curMod;
			if (directory != null)
			{
				if (curModData != null)
				{
					if (canControl && pack.label.text == curModData.name)
					{
						pack.label.offset.x = -directory.width / 2 + -7.5;
						directory.x = pack.label.x - pack.label.offset.x - directory.width - 15;
						directory.visible = pack.selected;
					}
				}
				else
					directory.visible = false;
			}
		}

		camFollow.x = grpPackages.members[curMod].x + Package.packageWidth / 2;
	}

	function changeMod(value:Int)
	{
		curMod = FlxMath.wrap(curMod + value, 0, modLength - 1);
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		function getHeader(mod:String):FlxGraphic
		{
			var key:String = 'mods/$mod/header.png';
			var graphic:FlxGraphic = null;
			if (Paths.currentTrackedAssets.exists(key))
				return Paths.currentTrackedAssets.get(key);
			if (FileSystem.exists(key))
			{
				var bmp:BitmapData = BitmapData.fromFile(key);
				graphic = Paths.cacheBitmap(key, null, bmp, true);
				return graphic;
			}
			return null;
		}

		var file:String = 'mods/${modsList.all[curMod]}/header.png';
		if (FileSystem.exists(file))
		{
			blackScreen.alpha = 1;
			bgHeader.loadGraphic(getHeader(modsList.all[curMod]));
			bgHeader.visible = true;
			bgHeader.screenCenter();
		}

		FlxTween.cancelTweensOf(bg);
		var curModPack:Package = grpPackages.members[curMod];
		var pack:Dynamic = Mods.getPack(modsList.all[curMod]);
		var targetColor:Int = FlxColor.WHITE;
		if (!curModPack.isBlank && pack != null && pack.color != null)
			targetColor = FlxColor.fromRGB(pack.color[0], pack.color[1], pack.color[2]);
		FlxTween.color(bg, 0.5, bg.color, targetColor, {ease: FlxEase.linear});

		descText.text = curModPack.isBlank ? '' : pack != null
			&& pack.description != null ? pack.description : 'mods/${curModPack.modDirectory}/pack.json DOES NOT EXIST!!';
		descText.screenCenter(Y);
		descText.y += 270;
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

class Package extends FlxSpriteGroup
{
	public static final packageWidth:Float = 320;

	public var modDirectory:String;
	public var settings:Dynamic;

	public var outline:FlxSprite;
	public var icon:FlxSprite;
	public var label:FlxText;

	public var selected(default, set):Bool = false;

	function set_selected(value:Bool):Bool
	{
		outline.visible = label.visible = selected;
		return selected = value;
	}

	public var isBlank:Bool = false;

	var borderColors:Array<FlxColor> = [0xFF33FFFF, 0xFF3333CC];
	var borderAlphas:Array<Float> = [1, .85];
	var titleTimer:Float = 0;

	public function new(x:Float, y:Float, name:String)
	{
		super(x, y);

		modDirectory = name;
		isBlank = name == '//';

		if (!isBlank)
		{
			var path:String = 'mods/$name/data/settings.json';
			if (FileSystem.exists(path))
			{
				try
				{
					settings = tjson.TJSON.parse(File.getContent(path));
				}
				catch (e:Dynamic)
				{
					var errorTitle = 'Mod name: ' + Mods.currentModDirectory;
					var errorMsg = 'An error occurred: $e';
					#if windows
					lime.app.Application.current.window.alert(errorMsg, errorTitle);
					#end
					trace('$errorTitle - $errorMsg');
				}
			}
		}

		var path:String = 'mods/$name/pack.png';
		icon = new FlxSprite().loadGraphic(FileSystem.exists(path) ? BitmapData.fromFile(path) : Paths.image('unknownMod'));
		icon.setGraphicSize(packageWidth / (isBlank ? 2 : 1), packageWidth / (isBlank ? 2 : 1));
		if (isBlank)
		{
			icon.alpha = 0.5;
			icon.color = FlxColor.BLACK;
		}
		icon.updateHitbox();
		icon.antialiasing = ClientPrefs.data.antialiasing;

		var cricleShader:shaders.CircleEffect = new shaders.CircleEffect();
		cricleShader.radius.value = [0.1];
		icon.shader = cricleShader;

		outline = new FlxSprite().makeGraphic(Std.int(icon.width + 20), Std.int(icon.height + 20), FlxColor.WHITE);
		outline.antialiasing = ClientPrefs.data.antialiasing;
		outline.x += icon.width / 2 - outline.width / 2;
		outline.y += icon.height / 2 - outline.height / 2;
		outline.blend = ADD;

		add(outline);
		add(icon);

		label = new FlxText(0, 0, 0, isBlank ? '' : Mods.getPack(name) == null
			|| Mods.getPack(name).name == null ? 'Unknown Mod' : Mods.getPack(name).name);
		label.antialiasing = false;
		label.setFormat(Paths.font('vcr.ttf'), 32, 0xFF33A3FF);
		label.borderSize = 1;
		label.x += icon.width / 2 - label.width / 2;
		label.y += -15 - label.height - 25;
		label.textField.filters = [new GlowFilter(0xFF000000)];
		add(label);

		var cricleShader:shaders.CircleEffect = new shaders.CircleEffect();
		cricleShader.radius.value = [0.115];
		outline.shader = cricleShader;
		selected = false;
	}

	override function update(elapsed:Float)
	{
		titleTimer += FlxMath.bound(elapsed / 2, 0, 1);
		if (titleTimer > 2)
			titleTimer -= 2;

		var timer:Float = titleTimer;
		if (timer >= 1)
			timer = (-timer) + 2;

		outline.color = FlxColor.interpolate(borderColors[0], borderColors[1], timer);
		outline.alpha = FlxMath.lerp(borderAlphas[0], borderAlphas[1], timer);

		super.update(elapsed);
	}
}
