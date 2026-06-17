package states;

import states.editors.content.PsychJsonPrinter;
import openfl.Lib;
import lime.graphics.Image;

class InitState extends MusicBeatState
{
	override function create()
	{
		FlxG.sound.playMusic(Paths.music(MainMenuState.menuSong), 0);

		ClientPrefs.loadPrefs();
		Language.reloadPhrases();
		MusicBeatState.resetStateMap();

		FlxG.console.registerClass(backend.CoolUtil);
		FlxG.console.registerClass(backend.Mods);

		FlxG.console.registerClass(states.PlayState);
		FlxG.console.registerClass(states.MainMenuState);
		FlxG.console.registerClass(states.StoryMenuState);
		FlxG.console.registerClass(states.FreeplayState);

		if (FlxG.save.data != null && FlxG.save.data.fullscreen)
		{
			FlxG.fullscreen = FlxG.save.data.fullscreen;
			// trace('LOADED FULLSCREEN SETTING!!');
		}
		persistentUpdate = true;
		persistentDraw = true;

		FlxTransitionableState.skipNextTransIn = true;
		FlxTransitionableState.skipNextTransOut = true;

		if (Main.loadChartPath != null)
		{
			TitleState.initialized = true;
			var error:String = null;
			try
			{
				var path:String = Main.loadChartPath[0];
				path = path.split("\\").join("/");
				var parts:Array<String> = path.split("/");
				var modName:String = Main.loadChartPath[1] == null ? parts[1] : Main.loadChartPath[1];
				var songFolder:String = parts[parts.length - 2];
				var chartBase:String = parts[parts.length - 1].split(".")[0];
				Mods.currentModDirectory = modName;
				backend.Song.loadFromJson(chartBase, songFolder);
			}
			catch (e:Dynamic)
			{
				error = e;
				trace(e);
			}
			states.PlayState.chartingMode = true;
			LoadingState.loadAndSwitchState(new states.editors.ChartingState(0, error), true);
		}
		if (Main.openNewChart)
		{
			states.PlayState.chartingMode = true;
			LoadingState.loadAndSwitchState(new states.editors.ChartingState(0), true);
		}

		FlxG.mouse.visible = false;

		var modsList:ModsList = Mods.parseList();
		if (modsList.enabled.length > 0)
		{
			var curMod:Dynamic = modsList.enabled[0];
			if (!FileSystem.exists('mods/$curMod/pack.json'))
			{
				var data:Dynamic = {
					name: 'MOD NAME HERE',
					description: 'MOD DESCRIPTION HERE',
					color: [128, 128, 128],
					discordRPC: "863222024192262205",
				}
				File.saveContent('mods/$curMod/pack.json', PsychJsonPrinter.print(data));
			}

			var mod:Dynamic = Mods.getPack(curMod);
			FlxG.stage.window.title = mod != null && mod.name != null ? mod.name : FlxG.stage.application.meta.get('name');
			var iconPath:String = 'mods/${Mods.currentModDirectory}/pack.png';
			if (FileSystem.exists(iconPath))
				Lib.application.window.setIcon(Image.fromFile(iconPath));
		}

		initScripts(Paths.getSharedPath(), 'scripts/');
		initScripts(Paths.getSharedPath(), 'scripts/states/InitState/');

		MusicBeatState.switchState(MusicBeatState.getClassFromStateMap("TitleState"));

		Paths.clearStoredMemory();
		super.create();
		Paths.clearUnusedMemory();

		callOnScripts('onCreatePost');
	}

	override function update(elapsed:Float)
	{
		callOnScripts('onUpdate', [elapsed]);
		super.update(elapsed);
		callOnScripts('onUpdatePost', [elapsed]);
	}
}
