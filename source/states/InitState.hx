package states;

import states.editors.MasterEditorMenu;

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
