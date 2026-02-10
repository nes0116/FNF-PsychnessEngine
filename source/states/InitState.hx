package states;

class InitState extends MusicBeatState
{
	override function create()
	{
		FlxG.sound.playMusic(Paths.music(MainMenuState.menuSong), 0);

		ClientPrefs.loadPrefs();
		Language.reloadPhrases();
		MusicBeatState.resetStateMap();

		FlxG.console.registerClass(backend.CoolUtil);

		FlxG.console.registerClass(states.PlayState);

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
