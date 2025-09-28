#if LUA_ALLOWED
package psychlua;

import backend.WeekData;
import backend.Highscore;
import backend.StageData;
import backend.Song;

import openfl.Lib;
import openfl.utils.Assets;
import openfl.display.BitmapData;
import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxState;

#if (!flash && sys)
import flixel.addons.display.FlxRuntimeShader;
#end

import cutscenes.DialogueBoxPsych;

import objects.StrumNote;
import objects.Note;
import objects.NoteSplash;
import objects.Character;

import states.*;
import states.editors.*;
import states.stages.*;

import substates.PauseSubState;
import substates.GameOverSubstate;

import psychlua.LuaUtils;
import psychlua.LuaUtils.LuaTweenOptions;
#if HSCRIPT_ALLOWED
import psychlua.HScript;
#end
import psychlua.DebugLuaText;
import psychlua.ModchartSprite;

import flixel.addons.display.FlxBackdrop;

import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepadInputID;

import haxe.Json;

class FunkinLua {
	public var lua:State = null;
	public var camTarget:FlxCamera;
	public var scriptName:String = '';
	public var modFolder:String = null;
	public var closed:Bool = false;

	#if HSCRIPT_ALLOWED
	public var hscript:HScript = null;
	#end

	public var callbacks:Map<String, Dynamic> = new Map<String, Dynamic>();
	public static var customFunctions:Map<String, Dynamic> = new Map<String, Dynamic>();

	public function new(scriptName:String) {
		lua = LuaL.newstate();
		LuaL.openlibs(lua);

		//trace('Lua version: ' + Lua.version());
		//trace("LuaJIT version: " + Lua.versionJIT());

		//LuaL.dostring(lua, CLENSE);

		this.scriptName = scriptName.trim();
		var game:MusicBeatState;
		var curState:String = Type.getClassName(Type.getClass(FlxG.state));
		switch (curState)
		{
			case 'states.FreeplayState':
				game = FreeplayState.instance;
			case 'states.MainMenuState':
				game = MainMenuState.instance;
			case 'states.PlayState':
				game = PlayState.instance;
			case 'states.TitleState':
				game = states.TitleState.instance;
			case 'psychlua.CustomState':
				game = psychlua.CustomState.instance;
			default:
				game = MusicBeatState.instance;
		}
		if (game != null) game.luaArray.push(this);

		var myFolder:Array<String> = this.scriptName.split('/');
		#if MODS_ALLOWED
		if( myFolder[0] + '/' == Paths.mods() && (Mods.currentModDirectory == myFolder[1] || Mods.getGlobalMods().contains(myFolder[1]))) //is inside mods folder
			this.modFolder = myFolder[1];
		#end

		// Lua shit
		set('Function_StopLua', LuaUtils.Function_StopLua);
		set('Function_StopHScript', LuaUtils.Function_StopHScript);
		set('Function_StopAll', LuaUtils.Function_StopAll);
		set('Function_Stop', LuaUtils.Function_Stop);
		set('Function_Continue', LuaUtils.Function_Continue);
		set('luaDebugMode', false);
		set('luaDeprecatedWarnings', true);
		set('psychVersion', MainMenuState.psychEngineVersion.trim());
		set('psychnessVersion', MainMenuState.psychnessEngineVersion.trim());
		set('modFolder', this.modFolder);

		// Song/Week shit
		set('curBpm', Conductor.bpm);
		set('crochet', Conductor.crochet);
		set('stepCrochet', Conductor.stepCrochet);
		set('songLength', FlxG.sound.music.length);
		set('loadedSongName', Song.loadedSongName);
		set('loadedSongPath', Paths.formatToSongPath(Song.loadedSongName));
		set('chartPath', Song.chartPath);
		set('startedCountdown', false);

		set('isStoryMode', PlayState.isStoryMode);
		set('difficulty', PlayState.storyDifficulty);

		set('difficultyName', Difficulty.getString(false));
		set('difficultyPath', Difficulty.getFilePath());
		set('difficultyNameTranslation', Difficulty.getString(true));
		set('weekRaw', PlayState.storyWeek);
		set('week', WeekData.weeksList[PlayState.storyWeek]);
		set('seenCutscene', PlayState.seenCutscene);

		// Screen stuff
		set('screenWidth', FlxG.width);
		set('screenHeight', FlxG.height);

		// FreeplayState-only variables
		if(game != null && game is FreeplayState)
		@:privateAccess
		{
			//
		}

		// MainMenuState-only variables
		if(game != null && game is MainMenuState)
		@:privateAccess
		{
			//
		}

		// PlayState-only variables
		if(game != null && game is PlayState)
		@:privateAccess
		{
			set('bpm', PlayState.SONG.bpm);
			set('scrollSpeed', PlayState.SONG.speed);
			set('songName', PlayState.SONG.song);
			set('songPath', Paths.formatToSongPath(PlayState.SONG.song));
			set('curStage', PlayState.SONG.stage);

			set('hasVocals', PlayState.SONG.needsVoices);
			
			var curSection:SwagSection = PlayState.SONG.notes[game.curSection];
			set('curSection', game.curSection);
			set('curBeat', game.curBeat);
			set('curStep', game.curStep);
			set('curDecBeat', game.curDecBeat);
			set('curDecStep', game.curDecStep);
	
			set('score', PlayState.instance.songScore);
			set('misses', PlayState.instance.songMisses);
			set('hits', PlayState.instance.songHits);
			set('combo', PlayState.instance.combo);
			set('deaths', PlayState.deathCounter);
	
			set('rating', PlayState.instance.ratingPercent);
			set('ratingName', PlayState.instance.ratingName);
			set('ratingFC', PlayState.instance.ratingFC);
			set('totalPlayed', PlayState.instance.totalPlayed);
			set('totalNotesHit', PlayState.instance.totalNotesHit);

			set('inGameOver', GameOverSubstate.instance != null);
			set('focusCharacter', curSection != null ? curSection.focusCharacter : 0);
			set('mustHitSection', curSection != null ? (PlayState.SONG.characters[curSection.focusCharacter].characterType == PLAYER) : false);
			set('altAnim', curSection != null ? (curSection.altAnim == true) : false);
			set('gfSection', curSection != null ? (PlayState.SONG.characters[curSection.focusCharacter].characterType == GIRLFRIEND) : false);

			set('healthGainMult', PlayState.instance.healthGain);
			set('healthLossMult', PlayState.instance.healthLoss);
	
			#if FLX_PITCH
			set('playbackRate', PlayState.instance.playbackRate);
			#else
			set('playbackRate', 1);
			#end
	
			set('guitarHeroSustains', PlayState.instance.guitarHeroSustains);
			set('instakillOnMiss', PlayState.instance.instakillOnMiss);
			set('botPlay', PlayState.instance.cpuControlled);
			set('practice', PlayState.instance.practiceMode);
	
			for (i in 0...4) {
				set('defaultPlayerStrumX' + i, 0);
				set('defaultPlayerStrumY' + i, 0);
				set('defaultOpponentStrumX' + i, 0);
				set('defaultOpponentStrumY' + i, 0);
			}
	
			// Default character data
			set('defaultBoyfriendX', PlayState.instance.BF_X);
			set('defaultBoyfriendY', PlayState.instance.BF_Y);
			set('defaultOpponentX', PlayState.instance.DAD_X);
			set('defaultOpponentY', PlayState.instance.DAD_Y);
			set('defaultGirlfriendX', PlayState.instance.GF_X);
			set('defaultGirlfriendY', PlayState.instance.GF_Y);

			var boyfriendNames:Array<String> = [];
			var dadNames:Array<String> = [];
			var gfNames:Array<String> = [];
			for (char in PlayState.SONG.characters)
			{
				switch (char.characterType)
				{
					case CharacterType.PLAYER:
						boyfriendNames.push(char.name);
					case CharacterType.OPPONENT:
						dadNames.push(char.name);
					case CharacterType.GIRLFRIEND:
						gfNames.push(char.name);
				}
			}
			set('characters', PlayState.SONG.characters);
			set('boyfriendName', PlayState.instance.boyfriend != null ? PlayState.instance.boyfriend.curCharacter : boyfriendNames);
			set('dadName', PlayState.instance.dad != null ? PlayState.instance.dad.curCharacter : dadNames);
			set('gfName', PlayState.instance.gf != null ? PlayState.instance.gf.curCharacter : gfNames);
		}

		// Other settings
		set('downscroll', ClientPrefs.data.downScroll);
		set('middlescroll', ClientPrefs.data.middleScroll);
		set('framerate', ClientPrefs.data.framerate);
		set('ghostTapping', ClientPrefs.data.ghostTapping);
		set('hideHud', ClientPrefs.data.hideHud);
		set('timeBarType', ClientPrefs.data.timeBarType);
		set('scoreZoom', ClientPrefs.data.scoreZoom);
		set('cameraZoomOnBeat', ClientPrefs.data.camZooms);
		set('flashingLights', ClientPrefs.data.flashing);
		set('noteOffset', ClientPrefs.data.noteOffset);
		set('healthBarAlpha', ClientPrefs.data.healthBarAlpha);
		set('noResetButton', ClientPrefs.data.noReset);
		set('lowQuality', ClientPrefs.data.lowQuality);
		set('shadersEnabled', ClientPrefs.data.shaders);
		set('scriptName', scriptName);
		set('currentModDirectory', Mods.currentModDirectory);

		// Noteskin/Splash
		set('noteSkin', ClientPrefs.data.noteSkin);
		set('noteSkinPostfix', Note.getNoteSkinPostfix());
		set('splashSkin', ClientPrefs.data.splashSkin);
		set('splashSkinPostfix', NoteSplash.getSplashSkinPostfix());
		set('splashAlpha', ClientPrefs.data.splashAlpha);

		// build target (windows, mac, linux, etc.)
		set('buildTarget', LuaUtils.getBuildTarget());

		// For MainMenuState
		set('psychnessEngineVersion', MainMenuState.psychnessEngineVersion);
		set('psychEngineVersion', MainMenuState.psychEngineVersion);

		//
		Lua_helper.add_callback(lua, "getRunningScripts", function() {
			var runningScripts:Array<String> = [];
			for (script in game.luaArray)
				runningScripts.push(script.scriptName);

			return runningScripts;
		});

		addLocalCallback("setOnScripts", function(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null) {
			if(exclusions == null) exclusions = [];
			if(ignoreSelf && !exclusions.contains(scriptName)) exclusions.push(scriptName);
			game.setOnScripts(varName, arg, exclusions);
		});
		addLocalCallback("setOnHScript", function(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null) {
			if(exclusions == null) exclusions = [];
			if(ignoreSelf && !exclusions.contains(scriptName)) exclusions.push(scriptName);
			game.setOnHScript(varName, arg, exclusions);
		});
		addLocalCallback("setOnLuas", function(varName:String, arg:Dynamic, ?ignoreSelf:Bool = false, ?exclusions:Array<String> = null) {
			if(exclusions == null) exclusions = [];
			if(ignoreSelf && !exclusions.contains(scriptName)) exclusions.push(scriptName);
			game.setOnLuas(varName, arg, exclusions);
		});

		addLocalCallback("callOnScripts", function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops=false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null) {
			if(excludeScripts == null) excludeScripts = [];
			if(ignoreSelf && !excludeScripts.contains(scriptName)) excludeScripts.push(scriptName);
			return game.callOnScripts(funcName, args, ignoreStops, excludeScripts, excludeValues);
		});
		addLocalCallback("callOnLuas", function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops=false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null) {
			if(excludeScripts == null) excludeScripts = [];
			if(ignoreSelf && !excludeScripts.contains(scriptName)) excludeScripts.push(scriptName);
			return game.callOnLuas(funcName, args, ignoreStops, excludeScripts, excludeValues);
		});
		addLocalCallback("callOnHScript", function(funcName:String, ?args:Array<Dynamic> = null, ?ignoreStops=false, ?ignoreSelf:Bool = true, ?excludeScripts:Array<String> = null, ?excludeValues:Array<Dynamic> = null) {
			if(excludeScripts == null) excludeScripts = [];
			if(ignoreSelf && !excludeScripts.contains(scriptName)) excludeScripts.push(scriptName);
			return game.callOnHScript(funcName, args, ignoreStops, excludeScripts, excludeValues);
		});

		Lua_helper.add_callback(lua, "callScript", function(luaFile:String, funcName:String, ?args:Array<Dynamic> = null) {
			if(args == null){
				args = [];
			}

			var luaPath:String = findScript(luaFile);
			if(luaPath != null)
				for (luaInstance in game.luaArray)
					if(luaInstance.scriptName == luaPath)
						return luaInstance.call(funcName, args);

			return null;
		});
		Lua_helper.add_callback(lua, "isRunning", function(scriptFile:String) {
			var luaPath:String = findScript(scriptFile);
			if(luaPath != null)
			{
				for (luaInstance in game.luaArray)
					if(luaInstance.scriptName == luaPath)
						return true;
			}

			#if HSCRIPT_ALLOWED
			var hscriptPath:String = findScript(scriptFile, '.hx');
			if(hscriptPath != null)
			{
				for (hscriptInstance in game.hscriptArray)
					if(hscriptInstance.origin == hscriptPath)
						return true;
			}
			#end
			return false;
		});

		Lua_helper.add_callback(lua, "setVar", function(varName:String, value:Dynamic) {
			MusicBeatState.getVariables().set(varName, ReflectionFunctions.parseSingleInstance(value));
			return value;
		});
		Lua_helper.add_callback(lua, "getVar", function(varName:String) {
			return MusicBeatState.getVariables().get(varName);
		});

		Lua_helper.add_callback(lua, "addLuaScript", function(luaFile:String, ?ignoreAlreadyRunning:Bool = false) {
			var luaPath:String = findScript(luaFile);
			if(luaPath != null)
			{
				if(!ignoreAlreadyRunning)
					for (luaInstance in game.luaArray)
						if(luaInstance.scriptName == luaPath)
						{
							DebugDisplay.instance.addLog('addLuaScript: The script "' + luaPath + '" is already running!');
							return;
						}

				new FunkinLua(luaPath);
				return;
			}
			DebugDisplay.instance.addLog("addLuaScript: Script doesn't exist!", false, false, FlxColor.RED);
		});
		Lua_helper.add_callback(lua, "addHScript", function(scriptFile:String, ?ignoreAlreadyRunning:Bool = false) {
			#if HSCRIPT_ALLOWED
			var scriptPath:String = findScript(scriptFile, '.hx');
			if(scriptPath != null)
			{
				if(!ignoreAlreadyRunning)
					for (script in game.hscriptArray)
						if(script.origin == scriptPath)
						{
							DebugDisplay.instance.addLog('addHScript: The script "' + scriptPath + '" is already running!');
							return;
						}

				PlayState.instance.initHScript(scriptPath);
				return;
			}
			DebugDisplay.instance.addLog("addHScript: Script doesn't exist!", false, false, FlxColor.RED);
			#else
			DebugDisplay.instance.addLog("addHScript: HScript is not supported on this platform!", false, false, FlxColor.RED);
			#end
		});
		Lua_helper.add_callback(lua, "removeLuaScript", function(luaFile:String) {
			var luaPath:String = findScript(luaFile);
			if(luaPath != null)
			{
				var foundAny:Bool = false;
				for (luaInstance in game.luaArray)
				{
					if(luaInstance.scriptName == luaPath)
					{
						trace('Closing lua script $luaPath');
						luaInstance.stop();
						foundAny = true;
					}
				}
				if(foundAny) return true;
			}

			DebugDisplay.instance.addLog('removeLuaScript: Script $luaFile isn\'t running!', false, false, FlxColor.RED);
			return false;
		});
		Lua_helper.add_callback(lua, "removeHScript", function(scriptFile:String) {
			#if HSCRIPT_ALLOWED
			var scriptPath:String = findScript(scriptFile, '.hx');
			if(scriptPath != null)
			{
				var foundAny:Bool = false;
				for (script in game.hscriptArray)
				{
					if(script.origin == scriptPath)
					{
						trace('Closing hscript $scriptPath');
						script.destroy();
						foundAny = true;
					}
				}
				if(foundAny) return true;
			}

			DebugDisplay.instance.addLog('removeHScript: Script $scriptFile isn\'t running!', false, false, FlxColor.RED);
			return false;
			#else
			DebugDisplay.instance.addLog("removeHScript: HScript is not supported on this platform!", false, false, FlxColor.RED);
			#end
		});

		Lua_helper.add_callback(lua, "loadSong", function(?name:String = null, ?difficultyNum:Int = -1) {
			if(name == null || name.length < 1)
				name = Song.loadedSongName;
			if (difficultyNum == -1)
				difficultyNum = PlayState.storyDifficulty;

			var poop = Highscore.formatSong(name, difficultyNum);
			Song.loadFromJson(poop, name);
			PlayState.storyDifficulty = difficultyNum;
			FlxG.state.persistentUpdate = false;
			LoadingState.loadAndSwitchState(new PlayState());

			FlxG.sound.music.pause();
			FlxG.sound.music.volume = 0;
			if(PlayState.instance != null && PlayState.instance.vocals != null)
			{
				PlayState.instance.vocals.pause();
				PlayState.instance.vocals.volume = 0;
			}
			FlxG.camera.followLerp = 0;
		});

		Lua_helper.add_callback(lua, "loadGraphic", function(variable:String, image:String, ?gridX:Int = 0, ?gridY:Int = 0) {
			var split:Array<String> = variable.split('.');
			var spr:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			var animated = gridX != 0 || gridY != 0;

			if(split.length > 1) {
				spr = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1]);
			}

			if(spr != null && image != null && image.length > 0)
			{
				spr.loadGraphic(Paths.image(image), animated, gridX, gridY);
			}
		});
		Lua_helper.add_callback(lua, "loadFrames", function(variable:String, image:String, spriteType:String = 'auto') {
			var split:Array<String> = variable.split('.');
			var spr:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				spr = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1]);
			}

			if(spr != null && image != null && image.length > 0)
			{
				LuaUtils.loadFrames(spr, image, spriteType);
			}
		});
		Lua_helper.add_callback(lua, "loadMultipleFrames", function(variable:String, images:Array<String>) {
			var split:Array<String> = variable.split('.');
			var spr:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				spr = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1]);
			}

			if(spr != null && images != null && images.length > 0)
			{
				spr.frames = Paths.getMultiAtlas(images);
			}
		});

		//shitass stuff for epic coders like me B)  *image of obama giving himself a medal*
		Lua_helper.add_callback(lua, "getObjectOrder", function(obj:String, ?group:String = null) {
			var leObj:FlxBasic = LuaUtils.getObjectDirectly(obj);
			if(leObj != null)
			{
				if(group != null)
				{
					var groupOrArray:Dynamic = Reflect.getProperty(LuaUtils.getTargetInstance(), group);
					if(groupOrArray != null)
					{
						switch(Type.typeof(groupOrArray))
						{
							case TClass(Array): //Is Array
								return groupOrArray.indexOf(leObj);
							default: //Is Group
								return Reflect.getProperty(groupOrArray, 'members').indexOf(leObj); //Has to use a Reflect here because of FlxTypedSpriteGroup
						}
					}
					else
					{
						DebugDisplay.instance.addLog('getObjectOrder: Group $group doesn\'t exist!', false, false, FlxColor.RED);
						return -1;
					}
				}
				var groupOrArray:Dynamic = CustomSubstate.instance != null ? CustomSubstate.instance : LuaUtils.getTargetInstance();
				return groupOrArray.members.indexOf(leObj);
			}
			DebugDisplay.instance.addLog('getObjectOrder: Object $obj doesn\'t exist!', false, false, FlxColor.RED);
			return -1;
		});
		Lua_helper.add_callback(lua, "setObjectOrder", function(obj:String, position:Int, ?group:String = null) {
			var leObj:FlxBasic = LuaUtils.getObjectDirectly(obj);
			if(leObj != null)
			{
				if(group != null)
				{
					var groupOrArray:Dynamic = Reflect.getProperty(LuaUtils.getTargetInstance(), group);
					if(groupOrArray != null)
					{
						switch(Type.typeof(groupOrArray))
						{
							case TClass(Array): //Is Array
								groupOrArray.remove(leObj);
								groupOrArray.insert(position, leObj);
							default: //Is Group
								groupOrArray.remove(leObj, true);
								groupOrArray.insert(position, leObj);
						}
					}
					else DebugDisplay.instance.addLog('setObjectOrder: Group $group doesn\'t exist!', false, false, FlxColor.RED);
				}
				else
				{
					var groupOrArray:Dynamic = CustomSubstate.instance != null ? CustomSubstate.instance : LuaUtils.getTargetInstance();
					groupOrArray.remove(leObj, true);
					groupOrArray.insert(position, leObj);
				}
				return;
			}
			DebugDisplay.instance.addLog('setObjectOrder: Object $obj doesn\'t exist!', false, false, FlxColor.RED);
		});

		// gay ass tweens
		Lua_helper.add_callback(lua, "startTween", function(tag:String, vars:String, values:Any = null, duration:Float, ?options:Any = null) {
			var penisExam:Dynamic = LuaUtils.tweenPrepare(tag, vars);
			if(penisExam != null)
			{
				if(values != null)
				{
					var myOptions:LuaTweenOptions = LuaUtils.getLuaTween(options);
					if(tag != null)
					{
						var variables = MusicBeatState.getVariables();
						var originalTag:String = 'tween_' + LuaUtils.formatVariable(tag);
						variables.set(tag, FlxTween.tween(penisExam, values, duration, myOptions != null ? {
							type: myOptions.type,
							ease: myOptions.ease,
							startDelay: myOptions.startDelay,
							loopDelay: myOptions.loopDelay,
	
							onUpdate: function(twn:FlxTween) {
								if(myOptions.onUpdate != null) game.callOnLuas(myOptions.onUpdate, [originalTag, vars]);
							},
							onStart: function(twn:FlxTween) {
								if(myOptions.onStart != null) game.callOnLuas(myOptions.onStart, [originalTag, vars]);
							},
							onComplete: function(twn:FlxTween) {
								if(twn.type == FlxTweenType.ONESHOT || twn.type == FlxTweenType.BACKWARD) variables.remove(tag);
								if(myOptions.onComplete != null) game.callOnLuas(myOptions.onComplete, [originalTag, vars]);
							}
						} : null));
						return tag;
					}
					else FlxTween.tween(penisExam, values, duration, myOptions != null ? {
						type: myOptions.type,
						ease: myOptions.ease,
						startDelay: myOptions.startDelay,
						loopDelay: myOptions.loopDelay,

						onUpdate: function(twn:FlxTween) {
							if(myOptions.onUpdate != null) game.callOnLuas(myOptions.onUpdate, [null, vars]);
						},
						onStart: function(twn:FlxTween) {
							if(myOptions.onStart != null) game.callOnLuas(myOptions.onStart, [null, vars]);
						},
						onComplete: function(twn:FlxTween) {
							if(myOptions.onComplete != null) game.callOnLuas(myOptions.onComplete, [null, vars]);
						}
					} : null);
				}
				else DebugDisplay.instance.addLog('startTween: No values on 2nd argument!', false, false, FlxColor.RED);
			}
			else DebugDisplay.instance.addLog('startTween: Couldnt find object: ' + vars, false, false, FlxColor.RED);
			return null;
		});

		Lua_helper.add_callback(lua, "doTweenX", function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return oldTweenFunction(tag, vars, {x: value}, duration, ease, 'doTweenX');
		});
		Lua_helper.add_callback(lua, "doTweenY", function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return oldTweenFunction(tag, vars, {y: value}, duration, ease, 'doTweenY');
		});
		Lua_helper.add_callback(lua, "doTweenAngle", function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return oldTweenFunction(tag, vars, {angle: value}, duration, ease, 'doTweenAngle');
		});
		Lua_helper.add_callback(lua, "doTweenAlpha", function(tag:String, vars:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return oldTweenFunction(tag, vars, {alpha: value}, duration, ease, 'doTweenAlpha');
		});
		Lua_helper.add_callback(lua, "doTweenZoom", function(tag:String, camera:String, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			switch(camera.toLowerCase()) {
				case 'camgame' | 'game': camera = 'camGame';
				case 'camhud' | 'hud': camera = 'camHUD';
				case 'camother' | 'other': camera = 'camOther';
				default:
					var cam:FlxCamera = MusicBeatState.getVariables().get(camera);
					if (cam == null || !Std.isOfType(cam, FlxCamera)) camera = 'camGame';
			}
			return oldTweenFunction(tag, camera, {zoom: value}, duration, ease, 'doTweenZoom');
		});
		Lua_helper.add_callback(lua, "doTweenColor", function(tag:String, vars:String, targetColor:String, duration:Float, ?ease:String = 'linear') {
			var penisExam:Dynamic = LuaUtils.tweenPrepare(tag, vars);
			if(penisExam != null) {
				var curColor:FlxColor = penisExam.color;
				curColor.alphaFloat = penisExam.alpha;
				
				if(tag != null)
				{
					var originalTag:String = tag;
					tag = LuaUtils.formatVariable('tween_$tag');
					var variables = MusicBeatState.getVariables();
					variables.set(tag, FlxTween.color(penisExam, duration, curColor, CoolUtil.colorFromString(targetColor), {ease: LuaUtils.getTweenEaseByString(ease),
						onComplete: function(twn:FlxTween)
						{
							variables.remove(tag);
							if (game != null) game.callOnLuas('onTweenCompleted', [originalTag, vars]);
						}
					}));
					return tag;
				}
				else FlxTween.color(penisExam, duration, curColor, CoolUtil.colorFromString(targetColor), {ease: LuaUtils.getTweenEaseByString(ease)});
			}
			else DebugDisplay.instance.addLog('doTweenColor: Couldnt find object: ' + vars, false, false, FlxColor.RED);
			return null;
		});

		//Tween shit, but for strums
		Lua_helper.add_callback(lua, "noteTweenX", function(tag:String, note:Int, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return noteTweenFunction(tag, note, {x: value}, duration, ease);
		});
		Lua_helper.add_callback(lua, "noteTweenY", function(tag:String, note:Int, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return noteTweenFunction(tag, note, {y: value}, duration, ease);
		});
		Lua_helper.add_callback(lua, "noteTweenAngle", function(tag:String, note:Int, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return noteTweenFunction(tag, note, {angle: value}, duration, ease);
		});
		Lua_helper.add_callback(lua, "noteTweenAlpha", function(tag:String, note:Int, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return noteTweenFunction(tag, note, {alpha: value}, duration, ease);
		});
		Lua_helper.add_callback(lua, "noteTweenDirection", function(tag:String, note:Int, value:Dynamic, duration:Float, ?ease:String = 'linear') {
			return noteTweenFunction(tag, note, {direction: value}, duration, ease);
		});
		Lua_helper.add_callback(lua, "mouseClicked", function(?button:String = 'left') {
			var click:Bool = FlxG.mouse.justPressed;
			switch(button.trim().toLowerCase())
			{
				case 'middle':
					click = FlxG.mouse.justPressedMiddle;
				case 'right':
					click = FlxG.mouse.justPressedRight;
			}
			return click;
		});
		Lua_helper.add_callback(lua, "mousePressed", function(?button:String = 'left') {
			var press:Bool = FlxG.mouse.pressed;
			switch(button.trim().toLowerCase())
			{
				case 'middle':
					press = FlxG.mouse.pressedMiddle;
				case 'right':
					press = FlxG.mouse.pressedRight;
			}
			return press;
		});
		Lua_helper.add_callback(lua, "mouseReleased", function(?button:String = 'left') {
			var released:Bool = FlxG.mouse.justReleased;
			switch(button.trim().toLowerCase())
			{
				case 'middle':
					released = FlxG.mouse.justReleasedMiddle;
				case 'right':
					released = FlxG.mouse.justReleasedRight;
			}
			return released;
		});
		Lua_helper.add_callback(lua, "mouseOverlaps", function(object:String, camera:String) {
			if (object == null || object.length < 1)
				return false;

			return FlxG.mouse.overlaps(game.getLuaObject(object), LuaUtils.cameraFromString(camera));
		});

		Lua_helper.add_callback(lua, "cancelTween", function(tag:String) LuaUtils.cancelTween(tag));

		Lua_helper.add_callback(lua, "runTimer", function(tag:String, time:Float = 1, loops:Int = 1) {
			LuaUtils.cancelTimer(tag);
			var variables = MusicBeatState.getVariables();
			
			var originalTag:String = tag;
			tag = LuaUtils.formatVariable('timer_$tag');
			variables.set(tag, new FlxTimer().start(time, function(tmr:FlxTimer)
			{
				if(tmr.finished) variables.remove(tag);
				game.callOnLuas('onTimerCompleted', [originalTag, tmr.loops, tmr.loopsLeft]);
				//trace('Timer Completed: ' + tag);
			}, loops));
			return tag;
		});
		Lua_helper.add_callback(lua, "cancelTimer", function(tag:String) LuaUtils.cancelTimer(tag));

		//stupid bietch ass functions
		Lua_helper.add_callback(lua, "addScore", function(value:Int = 0) {
			PlayState.instance.songScore += value;
			PlayState.instance.RecalculateRating();
		});
		Lua_helper.add_callback(lua, "addMisses", function(value:Int = 0) {
			PlayState.instance.songMisses += value;
			PlayState.instance.RecalculateRating();
		});
		Lua_helper.add_callback(lua, "addHits", function(value:Int = 0) {
			PlayState.instance.songHits += value;
			PlayState.instance.RecalculateRating();
		});
		Lua_helper.add_callback(lua, "setScore", function(value:Int = 0) {
			PlayState.instance.songScore = value;
			PlayState.instance.RecalculateRating();
		});
		Lua_helper.add_callback(lua, "setMisses", function(value:Int = 0) {
			PlayState.instance.songMisses = value;
			PlayState.instance.RecalculateRating();
		});
		Lua_helper.add_callback(lua, "setHits", function(value:Int = 0) {
			PlayState.instance.songHits = value;
			PlayState.instance.RecalculateRating();
		});
		Lua_helper.add_callback(lua, "setHealth", function(value:Float = 1) PlayState.instance.health = value);
		Lua_helper.add_callback(lua, "addHealth", function(value:Float = 0) PlayState.instance.health += value);
		Lua_helper.add_callback(lua, "getHealth", function() return PlayState.instance.health);

		//Identical functions
		Lua_helper.add_callback(lua, "FlxColor", function(color:String) return FlxColor.fromString(color));
		Lua_helper.add_callback(lua, "getColorFromName", function(color:String) return FlxColor.fromString(color));
		Lua_helper.add_callback(lua, "getColorFromString", function(color:String) return FlxColor.fromString(color));
		Lua_helper.add_callback(lua, "getColorFromHex", function(color:String) return FlxColor.fromString('#$color'));

		Lua_helper.add_callback(lua, "getColorFromCMYK", function(cyan:Float, magenta:Float, yellow:Float, black:Float, alpha:Float = 1) return FlxColor.fromCMYK(cyan, magenta, yellow, black, alpha));
		Lua_helper.add_callback(lua, "getColorFromCMYK", function(hue:Float, saturation:Float, brightness:Float, alpha:Float = 1) return FlxColor.fromHSB(hue, saturation, brightness, alpha));
		Lua_helper.add_callback(lua, "getColorFromCMYK", function(hue:Float, saturation:Float, brightness:Float, alpha:Float = 1) return FlxColor.fromHSL	(hue, saturation, brightness, alpha));
		Lua_helper.add_callback(lua, "getColorFromInt", function(value:Int) return FlxColor.fromInt(value));
		Lua_helper.add_callback(lua, "getColorFromRGB", function(red:Int, green:Int, blue:Int, alpha:Int = 255) return FlxColor.fromRGB(red, green, blue, alpha));
		Lua_helper.add_callback(lua, "getColorFromRGBFloat", function(red:Float, green:Float, blue:Float, alpha:Float = 255) return FlxColor.fromRGBFloat(red, green, blue, alpha));

		// precaching
		Lua_helper.add_callback(lua, "addCharacterToList", function(name:String, type:String) {
			PlayState.instance.addCharacterToList(name, CoolUtil.getCharacterDataFromString(type).charType, CoolUtil.getCharacterDataFromString(type).character);
		});
		Lua_helper.add_callback(lua, "precacheImage", function(name:String, ?allowGPU:Bool = true) {
			Paths.image(name, allowGPU);
		});
		Lua_helper.add_callback(lua, "precacheSound", function(name:String) {
			Paths.sound(name);
		});
		Lua_helper.add_callback(lua, "precacheMusic", function(name:String) {
			Paths.music(name);
		});

		// others
		Lua_helper.add_callback(lua, "triggerEvent", function(name:String, ?value1:String = '', ?value2:String = '') {
			PlayState.instance.triggerEvent(name, value1, value2, Conductor.songPosition);
			//trace('Triggered event: ' + name + ', ' + value1 + ', ' + value2);
			return true;
		});

		Lua_helper.add_callback(lua, "startCountdown", function() {
			PlayState.instance.startCountdown();
			return true;
		});
		Lua_helper.add_callback(lua, "endSong", function() {
			PlayState.instance.KillNotes();
			PlayState.instance.endSong();
			return true;
		});
		Lua_helper.add_callback(lua, "restartSong", function(?skipTransition:Bool = false) {
			PlayState.instance.persistentUpdate = false;
			FlxG.camera.followLerp = 0;
			PauseSubState.restartSong(skipTransition);
			return true;
		});
		Lua_helper.add_callback(lua, "exitSong", function(?skipTransition:Bool = false) {
			if(skipTransition)
			{
				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
			}

			if(PlayState.isStoryMode)
				MusicBeatState.switchState(MusicBeatState.getClassFromStateMap("StoryMenuState"));
			else
				MusicBeatState.switchState(MusicBeatState.getClassFromStateMap("FreeplayState"));

			#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end

			FlxG.sound.playMusic(Paths.music(MainMenuState.menuSong));
			PlayState.changedDifficulty = false;
			PlayState.chartingMode = false;
			PlayState.instance.transitioning = true;
			FlxG.camera.followLerp = 0;
			Mods.loadTopMod();
			return true;
		});
		Lua_helper.add_callback(lua, "getSongPosition", function() {
			return Conductor.songPosition;
		});

		Lua_helper.add_callback(lua, "getCharacterX", function(type:String) {
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent':
					return PlayState.instance.dadGroup.x;
				case 'gf' | 'girlfriend':
					return PlayState.instance.gfGroup.x;
				default:
					return PlayState.instance.boyfriendGroup.x;
			}
		});
		Lua_helper.add_callback(lua, "setCharacterX", function(type:String, value:Float) {
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent':
					PlayState.instance.dadGroup.x = value;
				case 'gf' | 'girlfriend':
					PlayState.instance.gfGroup.x = value;
				default:
					PlayState.instance.boyfriendGroup.x = value;
			}
		});
		Lua_helper.add_callback(lua, "getCharacterY", function(type:String) {
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent':
					return PlayState.instance.dadGroup.y;
				case 'gf' | 'girlfriend':
					return PlayState.instance.gfGroup.y;
				default:
					return PlayState.instance.boyfriendGroup.y;
			}
		});
		Lua_helper.add_callback(lua, "setCharacterY", function(type:String, value:Float) {
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent':
					PlayState.instance.dadGroup.y = value;
				case 'gf' | 'girlfriend':
					PlayState.instance.gfGroup.y = value;
				default:
					PlayState.instance.boyfriendGroup.y = value;
			}
		});
		Lua_helper.add_callback(lua, "cameraSetTarget", function(index:Int) {
			PlayState.instance.moveCamera(index);
		});

		Lua_helper.add_callback(lua, "setCameraScroll", function(x:Float, y:Float) FlxG.camera.scroll.set(x - FlxG.width/2, y - FlxG.height/2));
		Lua_helper.add_callback(lua, "setCameraFollowPoint", function(x:Float, y:Float) PlayState.instance.camFollow.setPosition(x, y));
		Lua_helper.add_callback(lua, "addCameraScroll", function(?x:Float = 0, ?y:Float = 0) FlxG.camera.scroll.add(x, y));
		Lua_helper.add_callback(lua, "addCameraFollowPoint", function(?x:Float = 0, ?y:Float = 0) {
			PlayState.instance.camFollow.x += x;
			PlayState.instance.camFollow.y += y;
		});
		Lua_helper.add_callback(lua, "getCameraScrollX", () -> FlxG.camera.scroll.x + FlxG.width/2);
		Lua_helper.add_callback(lua, "getCameraScrollY", () -> FlxG.camera.scroll.y + FlxG.height/2);
		Lua_helper.add_callback(lua, "getCameraFollowX", () -> PlayState.instance.camFollow.x);
		Lua_helper.add_callback(lua, "getCameraFollowY", () -> PlayState.instance.camFollow.y);

		Lua_helper.add_callback(lua, "cameraShake", function(camera:String, intensity:Float, duration:Float) {
			LuaUtils.cameraFromString(camera).shake(intensity, duration);
		});

		Lua_helper.add_callback(lua, "cameraFlash", function(camera:String, color:String, duration:Float,forced:Bool) {
			LuaUtils.cameraFromString(camera).flash(CoolUtil.colorFromString(color), duration, null, forced);
		});
		Lua_helper.add_callback(lua, "cameraFade", function(camera:String, color:String, duration:Float, forced:Bool, ?fadeOut:Bool = false) {
			LuaUtils.cameraFromString(camera).fade(CoolUtil.colorFromString(color), duration, fadeOut, null, forced);
		});
		Lua_helper.add_callback(lua, "setRatingPercent", function(value:Float) {
			PlayState.instance.ratingPercent = value;
			PlayState.instance.setOnScripts('rating', PlayState.instance.ratingPercent);
		});
		Lua_helper.add_callback(lua, "setRatingName", function(value:String) {
			PlayState.instance.ratingName = value;
			PlayState.instance.setOnScripts('ratingName', PlayState.instance.ratingName);
		});
		Lua_helper.add_callback(lua, "setRatingFC", function(value:String) {
			PlayState.instance.ratingFC = value;
			PlayState.instance.setOnScripts('ratingFC', PlayState.instance.ratingFC);
		});
		Lua_helper.add_callback(lua, "updateScoreText", function() PlayState.instance.updateScoreText());
		Lua_helper.add_callback(lua, "getMouseX", function(?camera:String = 'game') {
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			return FlxG.mouse.getScreenPosition(cam).x;
		});
		Lua_helper.add_callback(lua, "getMouseY", function(?camera:String = 'game') {
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			return FlxG.mouse.getScreenPosition(cam).y;
		});

		Lua_helper.add_callback(lua, "getMidpointX", function(variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:FlxObject = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1]);
			}
			if(obj != null) return obj.getMidpoint().x;

			return 0;
		});
		Lua_helper.add_callback(lua, "getMidpointY", function(variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:FlxObject = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1]);
			}
			if(obj != null) return obj.getMidpoint().y;

			return 0;
		});
		Lua_helper.add_callback(lua, "getGraphicMidpointX", function(variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1]);
			}
			if(obj != null) return obj.getGraphicMidpoint().x;

			return 0;
		});
		Lua_helper.add_callback(lua, "getGraphicMidpointY", function(variable:String) {
			var split:Array<String> = variable.split('.');
			var obj:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1]);
			}
			if(obj != null) return obj.getGraphicMidpoint().y;

			return 0;
		});
		Lua_helper.add_callback(lua, "getScreenPositionX", function(variable:String, ?camera:String = 'game') {
			var split:Array<String> = variable.split('.');
			var obj:FlxObject = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1]);
			}
			if(obj != null) return obj.getScreenPosition(LuaUtils.cameraFromString(camera)).x;

			return 0;
		});
		Lua_helper.add_callback(lua, "getScreenPositionY", function(variable:String, ?camera:String = 'game') {
			var split:Array<String> = variable.split('.');
			var obj:FlxObject = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				obj = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1]);
			}
			if(obj != null) return obj.getScreenPosition(LuaUtils.cameraFromString(camera)).y;

			return 0;
		});
		Lua_helper.add_callback(lua, "characterDance", function(character:String) {
			switch(character.toLowerCase()) {
				case 'dad': PlayState.instance.dad.dance();
				case 'gf' | 'girlfriend': if(PlayState.instance.gf != null) PlayState.instance.gf.dance();
				default: PlayState.instance.boyfriend.dance();
			}
		});

		Lua_helper.add_callback(lua, "makeLuaSprite", function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0) {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var leSprite:ModchartSprite = new ModchartSprite(x, y);
			if(image != null && image.length > 0)
			{
				leSprite.loadGraphic(Paths.image(image));
			}
			MusicBeatState.getVariables().set(tag, leSprite);
			leSprite.active = true;
		});
		Lua_helper.add_callback(lua, "makeAnimatedLuaSprite", function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0, ?spriteType:String = 'auto') {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var leSprite:ModchartSprite = new ModchartSprite(x, y);

			if(image != null && image.length > 0)
			{
				LuaUtils.loadFrames(leSprite, image, spriteType);
			}
			MusicBeatState.getVariables().set(tag, leSprite);
		});

		Lua_helper.add_callback(lua, "makeGraphic", function(obj:String, width:Int = 256, height:Int = 256, color:String = 'FFFFFF') {
			var spr:FlxSprite = LuaUtils.getObjectDirectly(obj);
			if(spr != null) spr.makeGraphic(width, height, CoolUtil.colorFromString(color));
		});
		Lua_helper.add_callback(lua, "addAnimationByPrefix", function(obj:String, name:String, prefix:String, framerate:Float = 24, loop:Bool = true) {
			var obj:FlxSprite = cast LuaUtils.getObjectDirectly(obj);
			if(obj != null && obj.animation != null)
			{
				obj.animation.addByPrefix(name, prefix, framerate, loop);
				if(obj.animation.curAnim == null)
				{
					var dyn:Dynamic = cast obj;
					if(dyn.playAnim != null) dyn.playAnim(name, true);
					else dyn.animation.play(name, true);
				}
				return true;
			}
			return false;
		});

		Lua_helper.add_callback(lua, "addAnimation", function(obj:String, name:String, frames:Any, framerate:Float = 24, loop:Bool = true) {
			return LuaUtils.addAnimByIndices(obj, name, null, frames, framerate, loop);
		});

		Lua_helper.add_callback(lua, "addAnimationByIndices", function(obj:String, name:String, prefix:String, indices:Any, framerate:Float = 24, loop:Bool = false) {
			return LuaUtils.addAnimByIndices(obj, name, prefix, indices, framerate, loop);
		});

		Lua_helper.add_callback(lua, "playAnim", function(obj:String, name:String, ?forced:Bool = false, ?reverse:Bool = false, ?startFrame:Int = 0)
		{
			var obj:Dynamic = LuaUtils.getObjectDirectly(obj);
			if(obj.playAnim != null)
			{
				obj.playAnim(name, forced, reverse, startFrame);
				return true;
			}
			else
			{
				if(obj.anim != null) obj.anim.play(name, forced, reverse, startFrame); //FlxAnimate
				else obj.animation.play(name, forced, reverse, startFrame);
				return true;
			}
			return false;
		});
		Lua_helper.add_callback(lua, "addOffset", function(obj:String, anim:String, x:Float, y:Float) {
			var obj:Dynamic = LuaUtils.getObjectDirectly(obj);
			if(obj != null && obj.addOffset != null)
			{
				obj.addOffset(anim, x, y);
				return true;
			}
			return false;
		});

		Lua_helper.add_callback(lua, "setScrollFactor", function(obj:String, scrollX:Float, scrollY:Float) {
			if(game.getLuaObject(obj) != null) {
				game.getLuaObject(obj).scrollFactor.set(scrollX, scrollY);
				return;
			}

			var object:FlxObject = Reflect.getProperty(LuaUtils.getTargetInstance(), obj);
			if(object != null) {
				object.scrollFactor.set(scrollX, scrollY);
			}
		});
		Lua_helper.add_callback(lua, "addLuaSprite", function(tag:String, ?inFront:Bool = false) {
			var mySprite:FlxSprite = MusicBeatState.getVariables().get(tag);
			if(mySprite == null) return;

			var instance = LuaUtils.getTargetInstance();
			if(inFront || curState != 'states.PlayState')
				instance.add(mySprite);
			else
			{
				if(PlayState.instance == null || !PlayState.instance.isDead)
					instance.insert(instance.members.indexOf(LuaUtils.getLowestCharacterGroup()), mySprite);
				else
					GameOverSubstate.instance.insert(GameOverSubstate.instance.members.indexOf(GameOverSubstate.instance.boyfriend), mySprite);
			}
		});
		Lua_helper.add_callback(lua, "setGraphicSize", function(obj:String, x:Float, y:Float = 0, updateHitbox:Bool = true) {
			if(game.getLuaObject(obj)!=null) {
				var shit:FlxSprite = game.getLuaObject(obj);
				shit.setGraphicSize(x, y);
				if(updateHitbox) shit.updateHitbox();
				return;
			}

			var split:Array<String> = obj.split('.');
			var poop:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				poop = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1]);
			}

			if(poop != null) {
				poop.setGraphicSize(x, y);
				if(updateHitbox) poop.updateHitbox();
				return;
			}
			DebugDisplay.instance.addLog('setGraphicSize: Couldnt find object: ' + obj, false, false, FlxColor.RED);
		});
		Lua_helper.add_callback(lua, "scaleObject", function(obj:String, x:Float, y:Float, updateHitbox:Bool = true) {
			if(game.getLuaObject(obj)!=null) {
				var shit:FlxSprite = game.getLuaObject(obj);
				shit.scale.set(x, y);
				if(updateHitbox) shit.updateHitbox();
				return;
			}

			var split:Array<String> = obj.split('.');
			var poop:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				poop = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1]);
			}

			if(poop != null) {
				poop.scale.set(x, y);
				if(updateHitbox) poop.updateHitbox();
				return;
			}
			DebugDisplay.instance.addLog('scaleObject: Couldnt find object: ' + obj, false, false, FlxColor.RED);
		});
		Lua_helper.add_callback(lua, "updateHitbox", function(obj:String) {
			if(game.getLuaObject(obj)!=null) {
				var shit:FlxSprite = game.getLuaObject(obj);
				shit.updateHitbox();
				return;
			}

			var split:Array<String> = obj.split('.');
			var poop:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				poop = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1]);
			}

			if(poop != null) {
				poop.updateHitbox();
				return;
			}
			DebugDisplay.instance.addLog('updateHitbox: Couldnt find object: ' + obj, false, false, FlxColor.RED);
		});

		Lua_helper.add_callback(lua, "removeLuaSprite", function(tag:String, destroy:Bool = true, ?group:String = null) {
			var obj:FlxSprite = LuaUtils.getObjectDirectly(tag);
			if(obj == null || obj.destroy == null)
				return;
			
			var groupObj:Dynamic = null;
			if(group == null) groupObj = LuaUtils.getTargetInstance();
			else groupObj = LuaUtils.getObjectDirectly(group);

			groupObj.remove(obj, true);
			if(destroy)
			{
				MusicBeatState.getVariables().remove(tag);
				obj.destroy();
			}
		});

		Lua_helper.add_callback(lua, "luaSpriteExists", function(tag:String) {
			var obj:FlxSprite = MusicBeatState.getVariables().get(tag);
			return (obj != null && (Std.isOfType(obj, ModchartSprite) || Std.isOfType(obj, ModchartAnimateSprite)));
		});
		Lua_helper.add_callback(lua, "luaTextExists", function(tag:String) {
			var obj:FlxText = MusicBeatState.getVariables().get(tag);
			return (obj != null && Std.isOfType(obj, FlxText));
		});
		Lua_helper.add_callback(lua, "luaSoundExists", function(tag:String) {
			var obj:FlxSound = MusicBeatState.getVariables().get('sound_$tag');
			return (obj != null && Std.isOfType(obj, FlxSound));
		});

		Lua_helper.add_callback(lua, "setHealthBarColors", function(left:String, right:String) {
			var left_color:Null<FlxColor> = null;
			var right_color:Null<FlxColor> = null;
			if (left != null && left != '')
				left_color = CoolUtil.colorFromString(left);
			if (right != null && right != '')
				right_color = CoolUtil.colorFromString(right);
			PlayState.instance.healthBar.setColors(left_color, right_color);
		});
		Lua_helper.add_callback(lua, "setTimeBarColors", function(left:String, right:String) {
			var left_color:Null<FlxColor> = null;
			var right_color:Null<FlxColor> = null;
			if (left != null && left != '')
				left_color = CoolUtil.colorFromString(left);
			if (right != null && right != '')
				right_color = CoolUtil.colorFromString(right);
			PlayState.instance.timeBar.setColors(left_color, right_color);
		});

		Lua_helper.add_callback(lua, "setObjectCamera", function(obj:String, camera:String = 'game') {
			var real:FlxBasic = game.getLuaObject(obj);
			if(real != null) {
				real.cameras = [LuaUtils.cameraFromString(camera)];
				return true;
			}

			var split:Array<String> = obj.split('.');
			var object:FlxBasic = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				object = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1]);
			}

			if(object != null) {
				object.cameras = [LuaUtils.cameraFromString(camera)];
				return true;
			}
			DebugDisplay.instance.addLog("setObjectCamera: Object " + obj + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});
		Lua_helper.add_callback(lua, "setBlendMode", function(obj:String, blend:String = '') {
			var real:FlxSprite = game.getLuaObject(obj);
			if(real != null) {
				real.blend = LuaUtils.blendModeFromString(blend);
				return true;
			}

			var split:Array<String> = obj.split('.');
			var spr:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				spr = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1]);
			}

			if(spr != null) {
				spr.blend = LuaUtils.blendModeFromString(blend);
				return true;
			}
			DebugDisplay.instance.addLog("setBlendMode: Object " + obj + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});
		Lua_helper.add_callback(lua, "screenCenter", function(obj:String, pos:String = 'xy') {
			var spr:FlxObject = game.getLuaObject(obj);

			if(spr==null){
				var split:Array<String> = obj.split('.');
				spr = LuaUtils.getObjectDirectly(split[0]);
				if(split.length > 1) {
					spr = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1]);
				}
			}

			if(spr != null)
			{
				switch(pos.trim().toLowerCase())
				{
					case 'x':
						spr.screenCenter(X);
						return;
					case 'y':
						spr.screenCenter(Y);
						return;
					default:
						spr.screenCenter(XY);
						return;
				}
			}
			DebugDisplay.instance.addLog("screenCenter: Object " + obj + " doesn't exist!", false, false, FlxColor.RED);
		});
		Lua_helper.add_callback(lua, "objectsOverlap", function(obj1:String, obj2:String) {
			var namesArray:Array<String> = [obj1, obj2];
			var objectsArray:Array<FlxBasic> = [];
			for (i in 0...namesArray.length)
			{
				var real:FlxBasic = game.getLuaObject(namesArray[i]);
				if(real != null)
					objectsArray.push(real);
				else
					objectsArray.push(Reflect.getProperty(LuaUtils.getTargetInstance(), namesArray[i]));
			}
			return (!objectsArray.contains(null) && FlxG.overlap(objectsArray[0], objectsArray[1]));
		});
		Lua_helper.add_callback(lua, "getPixelColor", function(obj:String, x:Int, y:Int) {
			var split:Array<String> = obj.split('.');
			var spr:FlxSprite = LuaUtils.getObjectDirectly(split[0]);
			if(split.length > 1) {
				spr = LuaUtils.getVarInArray(LuaUtils.getPropertyLoop(split), split[split.length-1]);
			}

			if(spr != null) return spr.pixels.getPixel32(x, y);
			return FlxColor.BLACK;
		});
		Lua_helper.add_callback(lua, "startDialogue", function(dialogueFile:String, ?music:String = null) {
			var path:String;
			var songPath:String = Paths.formatToSongPath(Song.loadedSongName);
			#if TRANSLATIONS_ALLOWED
			path = Paths.getPath('data/$songPath/${dialogueFile}_${ClientPrefs.data.language}.json', TEXT);
			#if MODS_ALLOWED
			if(!FileSystem.exists(path))
			#else
			if(!Assets.exists(path, TEXT))
			#end
			#end
				path = Paths.getPath('data/$songPath/$dialogueFile.json', TEXT);

			DebugDisplay.instance.addLog('startDialogue: Trying to load dialogue: ' + path);

			#if MODS_ALLOWED
			if(FileSystem.exists(path))
			#else
			if(Assets.exists(path, TEXT))
			#end
			{
				var shit:DialogueFile = DialogueBoxPsych.parseDialogue(path);
				if(shit.dialogue.length > 0)
				{
					PlayState.instance.startDialogue(shit, music);
					DebugDisplay.instance.addLog('startDialogue: Successfully loaded dialogue', false, false, FlxColor.GREEN);
					return true;
				}
				else DebugDisplay.instance.addLog('startDialogue: Your dialogue file is badly formatted!', false, false, FlxColor.RED);
			}
			else
			{
				DebugDisplay.instance.addLog('startDialogue: Dialogue file not found', false, false, FlxColor.RED);
				if(PlayState.instance.endingSong)
					PlayState.instance.endSong();
				else
					PlayState.instance.startCountdown();
			}
			return false;
		});
		Lua_helper.add_callback(lua, "startVideo", function(videoFile:String, ?canSkip:Bool = true, ?forMidSong:Bool = false, ?shouldLoop:Bool = false, ?playOnLoad:Bool = true) {
			#if VIDEOS_ALLOWED
			if(FileSystem.exists(Paths.video(videoFile)))
			{
				if(PlayState.instance.videoCutscene != null)
				{
					PlayState.instance.remove(PlayState.instance.videoCutscene);
					PlayState.instance.videoCutscene.destroy();
				}
				PlayState.instance.videoCutscene = PlayState.instance.startVideo(videoFile, forMidSong, canSkip, shouldLoop, playOnLoad);
				return true;
			}
			else
			{
				DebugDisplay.instance.addLog('startVideo: Video file not found: ' + videoFile, false, false, FlxColor.RED);
			}
			return false;

			#else
			PlayState.instance.inCutscene = true;
			new FlxTimer().start(0.1, function(tmr:FlxTimer)
			{
				PlayState.instance.inCutscene = false;
				if(PlayState.instance.endingSong)
					PlayState.instance.endSong();
				else
					PlayState.instance.startCountdown();
			});
			return true;
			#end
		});

		Lua_helper.add_callback(lua, "playMusic", function(sound:String, ?volume:Float = 1, ?loop:Bool = false) {
			FlxG.sound.playMusic(Paths.music(sound), volume, loop);
		});
		Lua_helper.add_callback(lua, "playSound", function(sound:String, ?volume:Float = 1, ?tag:String = null, ?loop:Bool = false) {
			if(tag != null && tag.length > 0)
			{
				var originalTag:String = tag;
				tag = LuaUtils.formatVariable('sound_$tag');
				var variables = MusicBeatState.getVariables();
				var oldSnd = variables.get(tag);
				if(oldSnd != null)
				{
					oldSnd.stop();
					oldSnd.destroy();
				}

				variables.set(tag, FlxG.sound.play(Paths.sound(sound), volume, loop, null, true, function()
				{
					if(!loop) variables.remove(tag);
					if(game != null) game.callOnLuas('onSoundFinished', [originalTag]);
				}));
				return tag;
			}
			FlxG.sound.play(Paths.sound(sound), volume);
			return null;
		});
		Lua_helper.add_callback(lua, "stopSound", function(tag:String) {
			if(tag == null || tag.length < 1)
			{
				if(FlxG.sound.music != null)
					FlxG.sound.music.stop();
			}
			else
			{
				tag = LuaUtils.formatVariable('sound_$tag');
				var variables = MusicBeatState.getVariables();
				var snd:FlxSound = variables.get(tag);
				if(snd != null)
				{
					snd.stop();
					variables.remove(tag);
				}
			}
		});
		Lua_helper.add_callback(lua, "pauseSound", function(tag:String) {
			if(tag == null || tag.length < 1)
			{
				if(FlxG.sound.music != null)
					FlxG.sound.music.pause();
			}
			else
			{
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) snd.pause();
			}
		});
		Lua_helper.add_callback(lua, "resumeSound", function(tag:String) {
			if(tag == null || tag.length < 1)
			{
				if(FlxG.sound.music != null)
					FlxG.sound.music.play();
			}
			else
			{
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) snd.play();
			}
		});
		Lua_helper.add_callback(lua, "soundFadeIn", function(tag:String, duration:Float, fromValue:Float = 0, toValue:Float = 1) {
			if(tag == null || tag.length < 1)
			{
				if(FlxG.sound.music != null)
					FlxG.sound.music.fadeIn(duration, fromValue, toValue);
			}
			else
			{
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null)
					snd.fadeIn(duration, fromValue, toValue);
			}
		});
		Lua_helper.add_callback(lua, "soundFadeOut", function(tag:String, duration:Float, toValue:Float = 0) {
			if(tag == null || tag.length < 1)
			{
				if(FlxG.sound.music != null)
					FlxG.sound.music.fadeOut(duration, toValue);
			}
			else
			{
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null)
					snd.fadeOut(duration, toValue);
			}
		});
		Lua_helper.add_callback(lua, "soundFadeCancel", function(tag:String) {
			if(tag == null || tag.length < 1)
			{
				if(FlxG.sound.music != null && FlxG.sound.music.fadeTween != null)
					FlxG.sound.music.fadeTween.cancel();
			}
			else
			{
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null && snd.fadeTween != null)
					snd.fadeTween.cancel();
			}
		});
		Lua_helper.add_callback(lua, "getSoundVolume", function(tag:String) {
			if(tag == null || tag.length < 1)
			{
				if(FlxG.sound.music != null)
					return FlxG.sound.music.volume;
			}
			else
			{
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) return snd.volume;
			}
			return 0;
		});
		Lua_helper.add_callback(lua, "setSoundVolume", function(tag:String, value:Float) {
			if(tag == null || tag.length < 1)
			{
				tag = LuaUtils.formatVariable('sound_$tag');
				if(FlxG.sound.music != null)
				{
					FlxG.sound.music.volume = value;
					return;
				}
			}
			else
			{
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) snd.volume = value;
			}
		});
		Lua_helper.add_callback(lua, "getSoundTime", function(tag:String) {
			if(tag == null || tag.length < 1)
			{
				return FlxG.sound.music != null ? FlxG.sound.music.time : 0;
			}
			tag = LuaUtils.formatVariable('sound_$tag');
			var snd:FlxSound = MusicBeatState.getVariables().get(tag);
			return snd != null ? snd.time : 0;
		});
		Lua_helper.add_callback(lua, "setSoundTime", function(tag:String, value:Float) {
			if(tag == null || tag.length < 1)
			{
				if(FlxG.sound.music != null)
				{
					FlxG.sound.music.time = value;
					return;
				}
			}
			else
			{
				tag = LuaUtils.formatVariable('sound_$tag');
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null) snd.time = value;
			}
		});
		Lua_helper.add_callback(lua, "getSoundPitch", function(tag:String) {
			#if FLX_PITCH
			tag = LuaUtils.formatVariable('sound_$tag');
			var snd:FlxSound = MusicBeatState.getVariables().get(tag);
			return snd != null ? snd.pitch : 1;
			#else
			DebugDisplay.instance.addLog("getSoundPitch: Sound Pitch is not supported on this platform!", false, false, FlxColor.RED);
			return 1;
			#end
		});
		Lua_helper.add_callback(lua, "setSoundPitch", function(tag:String, value:Float, ?doPause:Bool = false) {
			#if FLX_PITCH
			tag = LuaUtils.formatVariable('sound_$tag');
			var snd:FlxSound = MusicBeatState.getVariables().get(tag);
			if(snd != null)
			{
				var wasResumed:Bool = snd.playing;
				if (doPause) snd.pause();
				snd.pitch = value;
				if (doPause && wasResumed) snd.play();
			}
			
			if(tag == null || tag.length < 1)
			{
				if(FlxG.sound.music != null)
				{
					var wasResumed:Bool = FlxG.sound.music.playing;
					if (doPause) FlxG.sound.music.pause();
					FlxG.sound.music.pitch = value;
					if (doPause && wasResumed) FlxG.sound.music.play();
					return;
				}
			}
			else
			{
				var snd:FlxSound = MusicBeatState.getVariables().get(tag);
				if(snd != null)
				{
					var wasResumed:Bool = snd.playing;
					if (doPause) snd.pause();
					snd.pitch = value;
					if (doPause && wasResumed) snd.play();
				}
			}
			#else
			DebugDisplay.instance.addLog("setSoundPitch: Sound Pitch is not supported on this platform!", false, false, FlxColor.RED);
			#end
		});

		// mod settings
		addLocalCallback("getModSetting", function(saveTag:String, ?modName:String = null) {
			#if MODS_ALLOWED
			if(modName == null)
			{
				if(this.modFolder == null)
				{
					DebugDisplay.instance.addLog('getModSetting: Argument #2 is null and script is not inside a packed Mod folder!', false, false, FlxColor.RED);
					return null;
				}
				modName = this.modFolder;
			}
			return LuaUtils.getModSetting(saveTag, modName);
			#else
			DebugDisplay.instance.addLog("getModSetting: Mods are disabled in this build!", false, false, FlxColor.RED);
			#end
		});
		//

		// Vioness function
		Lua_helper.add_callback(lua, "makeBackDropLuaSprite", function(tag:String, ?image:String = null, ?x:Float = 0, ?y:Float = 0, ?repeatAxes = 'xy', ?spacingX:Float = 0, ?spacingY:Float = 0) {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);

			if(image != null && image.length > 0)
			{
				var axes:flixel.util.FlxAxes = XY;

				switch(repeatAxes.trim().toLowerCase())
				{
					case 'x':
						axes = X;
					case 'y':
						axes = Y;
					default:
						axes = XY;
				}

				var leSprite:FlxBackdrop = new FlxBackdrop(new ModchartSprite(x, y).loadGraphic(Paths.image(image)).pixels, axes, spacingX, spacingY);
				MusicBeatState.getVariables().set(tag, leSprite);
				leSprite.active = true;
			}
		});

		Lua_helper.add_callback(lua, "makeLuaAlphabet", function(tag:String, ?text:String = '', ?x:Float = 0, ?y:Float = 0, ?bold:Bool = true) {
			tag = tag.replace('.', '');

			LuaUtils.destroyObject(tag);
			var leAlphabet:Alphabet = new Alphabet(x, y, text, bold);
			if(PlayState.instance != null) leAlphabet.cameras = [PlayState.instance.camHUD];
			leAlphabet.scrollFactor.set();
			MusicBeatState.getVariables().set(tag, leAlphabet);
		});
		Lua_helper.add_callback(lua, "setAlphabetAlignment", function(tag:String, alignment:String = 'left') {
			var obj:Alphabet = LuaUtils.getObjectDirectly(tag);
			if(obj != null)
			{
				obj.alignment = LEFT;
				switch(alignment.trim().toLowerCase())
				{
					case 'right':
						obj.alignment = RIGHT;
					case 'center':
						obj.alignment = CENTERED;
				}
				return true;
			}
			DebugDisplay.instance.addLog("setAlphabetScale: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});
		Lua_helper.add_callback(lua, "setAlphabetScale", function(tag:String, scale:Float) {
			var obj:Alphabet = LuaUtils.getObjectDirectly(tag);
			if(obj != null)
			{
				obj.setScale(scale);
				return true;
			}
			DebugDisplay.instance.addLog("setAlphabetScale: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});
		Lua_helper.add_callback(lua, "setAlphabetString", function(tag:String, text:String) {
			var obj:Alphabet = LuaUtils.getObjectDirectly(tag);
			if(obj != null)
			{
				obj.text = text;
				return true;
			}
			DebugDisplay.instance.addLog("setAlphabetScale: Object " + tag + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});
		
		Lua_helper.add_callback(lua, "switchState", function(?state:String = null, ?variables:Array<Dynamic>, ?skipTransition:Bool = false) {
			var curState:Null<Dynamic> = Type.resolveClass(state);
			if(skipTransition)
			{
				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
			}
        	if (curState != null)
        	    MusicBeatState.switchState(cast Type.createInstance(curState, variables));
		});

		Lua_helper.add_callback(lua, "setClassFromStateMap", function(name:String, state:String, ?variables:Array<Dynamic>) {
			MusicBeatState.stateMap.set(name, [state, variables]);
			return true;
		});
		Lua_helper.add_callback(lua, "getClassFromStateMap", function(name:String) {
			return MusicBeatState.stateMap.get(name);
		});
		Lua_helper.add_callback(lua, "resetStateMap", function() {
			MusicBeatState.resetStateMap();
			return true;
		});

		Lua_helper.add_callback(lua, "makeLuaCamera", function(tag:String = null, ?x:Float = 0, y:Float = 0, width:Int = null, height:Int = null, zoom:Float = 1) {
			tag = tag.replace('.', '');
			LuaUtils.destroyObject(tag);
			var camera:FlxCamera = new FlxCamera(x, y, width, height, zoom);
			MusicBeatState.getVariables().set(tag, camera);
			camera.active = true;
		});

		Lua_helper.add_callback(lua, "addLuaCamera", function(tag:String = null, defaultDrawTarget:Bool = false) {
			tag = tag.replace('.', '');
			var camera:FlxCamera = LuaUtils.cameraFromString(tag);
			if (camera != null)
			{
				FlxG.cameras.add(camera, defaultDrawTarget);
				return;
			}
		});

		Lua_helper.add_callback(lua, "getCameraOrder", function(tag:String = null) {
			tag = tag.replace('.', '');
			var camera:FlxCamera = LuaUtils.cameraFromString(tag);
			if (camera != null)
			{
				return FlxG.cameras.list.indexOf(camera);
			}
			DebugDisplay.instance.addLog('getCameraOrder: Camera $camera doesn\'t exist!', false, false, FlxColor.RED);
			return -1;
		});

		Lua_helper.add_callback(lua, "setCameraOrder", function(tag:String = null, position:Int, defaultDrawTarget:Bool = false) {
			tag = tag.replace('.', '');
			var camera:FlxCamera = LuaUtils.cameraFromString(tag);
			if (camera != null)
			{
				@:privateAccess
				{
					var cameras = [
						for (i in FlxG.cameras.list)
						{
							camera: i,
							defaultDraw: FlxG.cameras.defaults.contains(i)
						}
					];

					for (i in cameras)
						FlxG.cameras.remove(i.camera, false);

					cameras.insert(position, {camera: camera, defaultDraw: defaultDrawTarget});

					for (i in cameras)
						FlxG.cameras.add(i.camera, i.defaultDraw);
				}
				return;
			}
			DebugDisplay.instance.addLog('setCameraOrder: Camera $camera doesn\'t exist!', false, false, FlxColor.RED);
		});

		Lua_helper.add_callback(lua, "loadWeek", function(?name:String = null, ?difficultyNum:Int = -1) {
			if(name == null || name.length < 1)
				name = WeekData.getCurrentWeek().fileName;
			if (difficultyNum == -1)
				difficultyNum = PlayState.storyDifficulty;

			WeekData.reloadWeekFiles(true);

			@:privateAccess
			{
				var path:String = Paths.getPath('weeks/$name.json', TEXT, null, true);
				var weekFile:WeekFile = WeekData.getWeekFile(path);

				var songArray:Array<String> = [];
				var leWeek:Array<Dynamic> = weekFile.songs;
				for (i in 0...leWeek.length) {
					songArray.push(leWeek[i][0]);
				}

				PlayState.storyPlaylist = songArray;
				PlayState.isStoryMode = true;

				var diffic = Difficulty.getFilePath(difficultyNum);
				if(diffic == null) diffic = '';

				PlayState.storyDifficulty = difficultyNum;

				Song.loadFromJson(PlayState.storyPlaylist[0].toLowerCase() + diffic, PlayState.storyPlaylist[0].toLowerCase());
				PlayState.campaignScore = 0;
				PlayState.campaignMisses = 0;
			}

			var directory = StageData.forceNextDirectory;
			LoadingState.loadNextDirectory();
			StageData.forceNextDirectory = directory;

			@:privateAccess
			if(PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
			{
				trace('CHANGED MOD DIRECTORY, RELOADING STUFF');
				Paths.freeGraphicsFromMemory();
			}
			LoadingState.prepareToSong();
			#if !SHOW_LOADING_SCREEN FlxG.sound.music.stop(); #end
			LoadingState.loadAndSwitchState(new PlayState(), true);
			FreeplayState.destroyFreeplayVocals();
			
			#if (MODS_ALLOWED && DISCORD_ALLOWED)
			DiscordClient.loadModRPC();
			#end
		});
		//

		Lua_helper.add_callback(lua, "debugPrint", function(text:Dynamic = '', color:String = 'WHITE') game.addTextToDebug(text, CoolUtil.colorFromString(color)));

		addLocalCallback("close", function() {
			closed = true;
			trace('Closing script $scriptName');
			return closed;
		});

		#if DISCORD_ALLOWED DiscordClient.addLuaCallbacks(lua); #end
		#if ACHIEVEMENTS_ALLOWED Achievements.addLuaCallbacks(lua); #end
		#if TRANSLATIONS_ALLOWED Language.addLuaCallbacks(lua); #end
		HScript.implement(this);
		#if flxanimate FlxAnimateFunctions.implement(this); #end
		ReflectionFunctions.implement(this);
		TextFunctions.implement(this);
		ExtraFunctions.implement(this);
		CustomState.implement(this);
		CustomSubstate.implement(this);
		ShaderFunctions.implement(this);
		DeprecatedFunctions.implement(this);

		if (TitleState.instance != null)
			TitleState.instance.implement(this);

		for (name => func in customFunctions)
		{
			if(func != null)
				Lua_helper.add_callback(lua, name, func);
		}

		try{
			var isString:Bool = !FileSystem.exists(scriptName);
			var result:Dynamic = null;
			if(!isString)
				result = LuaL.dofile(lua, scriptName);
			else
				result = LuaL.dostring(lua, scriptName);

			var resultStr:String = Lua.tostring(lua, result);
			if(resultStr != null && result != 0) {
				trace(resultStr);
				#if windows
				lime.app.Application.current.window.alert(resultStr, 'Error on lua script!');
				#else
				DebugDisplay.instance.addLog('$scriptName\n$resultStr', true, false, FlxColor.RED);
				#end
				lua = null;
				return;
			}
			if(isString) scriptName = 'unknown';
		} catch(e:Dynamic) {
			trace(e);
			return;
		}
		trace('lua file loaded succesfully:' + scriptName);

		call('onCreate', []);
	}

	//main
	public var lastCalledFunction:String = '';
	public static var lastCalledScript:FunkinLua = null;
	public function call(func:String, args:Array<Dynamic>):Dynamic {
		if(closed) return LuaUtils.Function_Continue;

		lastCalledFunction = func;
		lastCalledScript = this;
		try {
			if(lua == null) return LuaUtils.Function_Continue;

			Lua.getglobal(lua, func);
			var type:Int = Lua.type(lua, -1);

			if (type != Lua.LUA_TFUNCTION) {
				if (type > Lua.LUA_TNIL)
					DebugDisplay.instance.addLog("ERROR (" + func + "): attempt to call a " + LuaUtils.typeToString(type) + " value", false, false, FlxColor.RED);

				Lua.pop(lua, 1);
				return LuaUtils.Function_Continue;
			}

			for (arg in args) Convert.toLua(lua, arg);
			var status:Int = Lua.pcall(lua, args.length, 1, 0);

			// Checks if it's not successful, then show a error.
			if (status != Lua.LUA_OK) {
				var error:String = getErrorMessage(status);
				DebugDisplay.instance.addLog("ERROR (" + func + "): " + error, false, false, FlxColor.RED);
				return LuaUtils.Function_Continue;
			}

			// If successful, pass and then return the result.
			var result:Dynamic = cast Convert.fromLua(lua, -1);
			if (result == null) result = LuaUtils.Function_Continue;

			Lua.pop(lua, 1);
			if(closed) stop();
			return result;
		}
		catch (e:Dynamic) {
			trace(e);
		}
		return LuaUtils.Function_Continue;
	}

	public function set(variable:String, data:Dynamic) {
		if(lua == null) {
			return;
		}

		Convert.toLua(lua, data);
		Lua.setglobal(lua, variable);
	}

	public function stop() {
		closed = true;

		if(lua == null) {
			return;
		}
		Lua.close(lua);
		lua = null;
		#if HSCRIPT_ALLOWED
		if(hscript != null)
		{
			hscript.destroy();
			hscript = null;
		}
		#end
	}

	function oldTweenFunction(tag:String, vars:String, tweenValue:Any, duration:Float, ease:String, funcName:String)
	{
		var target:Dynamic = LuaUtils.tweenPrepare(tag, vars);
		var variables = MusicBeatState.getVariables();
		if(target != null)
		{
			if(tag != null)
			{
				var originalTag:String = tag;
				tag = LuaUtils.formatVariable('tween_$tag');
				variables.set(tag, FlxTween.tween(target, tweenValue, duration, {ease: LuaUtils.getTweenEaseByString(ease),
					onComplete: function(twn:FlxTween)
					{
						variables.remove(tag);
						if(PlayState.instance != null) PlayState.instance.callOnLuas('onTweenCompleted', [originalTag, vars]);
					}
				}));
			}
			else FlxTween.tween(target, tweenValue, duration, {ease: LuaUtils.getTweenEaseByString(ease)});
			return tag;
		}
		else DebugDisplay.instance.addLog('$funcName: Couldnt find object: $vars', false, false, FlxColor.RED);
		return null;
	}

	function noteTweenFunction(tag:String, note:Int, data:Dynamic, duration:Float, ease:String)
	{
		if(PlayState.instance == null) return null;

		var strumNote:StrumNote = PlayState.instance.strumLineNotes.members[note];
		trace(strumNote, note);
		if(strumNote == null) return null;

		if(tag != null)
		{
			var originalTag:String = tag;
			tag = LuaUtils.formatVariable('tween_$tag');
			LuaUtils.cancelTween(tag);

			var variables = MusicBeatState.getVariables();
			variables.set(tag, FlxTween.tween(strumNote, data, duration, {ease: LuaUtils.getTweenEaseByString(ease),
				onComplete: function(twn:FlxTween)
				{
					variables.remove(tag);
					if(PlayState.instance != null) PlayState.instance.callOnLuas('onTweenCompleted', [originalTag]);
				}
			}));
			return tag;
		}
		else FlxTween.tween(strumNote, data, duration, {ease: LuaUtils.getTweenEaseByString(ease)});
		return null;
	}

	public static function luaTrace(text:String, ignoreCheck:Bool = false, deprecated:Bool = false, color:FlxColor = FlxColor.WHITE) {
		if(ignoreCheck || getBool('luaDebugMode')) {
			if(deprecated && !getBool('luaDeprecatedWarnings')) {
				return;
			}
			trace(text);
			MusicBeatState.instance.addTextToDebug(text, color);
		}
	}

	public static function getBool(variable:String) {
		if(lastCalledScript == null) return false;

		var lua:State = lastCalledScript.lua;
		if(lua == null) return false;

		var result:String = null;
		Lua.getglobal(lua, variable);
		result = Convert.fromLua(lua, -1);
		Lua.pop(lua, 1);

		if(result == null) {
			return false;
		}
		return (result == 'true');
	}

	function findScript(scriptFile:String, ext:String = '.lua')
	{
		if(!scriptFile.endsWith(ext)) scriptFile += ext;
		var path:String = Paths.getPath(scriptFile, TEXT);
		#if MODS_ALLOWED
		if(FileSystem.exists(path))
		#else
		if(Assets.exists(path, TEXT))
		#end
		{
			return path;
		}
		#if MODS_ALLOWED
		else if(FileSystem.exists(scriptFile))
		#else
		else if(Assets.exists(scriptFile, TEXT))
		#end
		{
			return scriptFile;
		}
		return null;
	}

	public function getErrorMessage(status:Int):String {
		var v:String = Lua.tostring(lua, -1);
		Lua.pop(lua, 1);

		if (v != null) v = v.trim();
		if (v == null || v == "") {
			switch(status) {
				case Lua.LUA_ERRRUN: return "Runtime Error";
				case Lua.LUA_ERRMEM: return "Memory Allocation Error";
				case Lua.LUA_ERRERR: return "Critical Error";
			}
			return "Unknown Error";
		}

		return v;
		return null;
	}

	public function addLocalCallback(name:String, myFunction:Dynamic)
	{
		callbacks.set(name, myFunction);
		Lua_helper.add_callback(lua, name, null); //just so that it gets called
	}

	#if (!flash && sys)
	public var runtimeShaders:Map<String, Array<String>> = new Map<String, Array<String>>();
	#end

	public function initLuaShader(name:String)
	{
		if(!ClientPrefs.data.shaders) return false;

		#if (!flash && sys)
		if(runtimeShaders.exists(name))
		{
			var shaderData:Array<String> = runtimeShaders.get(name);
			if(shaderData != null && (shaderData[0] != null || shaderData[1] != null))
			{
				DebugDisplay.instance.addLog('Shader $name was already initialized!');
				return true;
			}
		}

		var foldersToCheck:Array<String> = [Paths.getSharedPath('shaders/')];
		#if MODS_ALLOWED
		foldersToCheck.push(Paths.mods('shaders/'));
		if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Mods.currentModDirectory + '/shaders/'));

		for(mod in Mods.getGlobalMods())
			foldersToCheck.insert(0, Paths.mods(mod + '/shaders/'));
		#end

		for (folder in foldersToCheck)
		{
			if(FileSystem.exists(folder))
			{
				var frag:String = folder + name + '.frag';
				var vert:String = folder + name + '.vert';
				var found:Bool = false;
				if(FileSystem.exists(frag))
				{
					frag = File.getContent(frag);
					found = true;
				}
				else frag = null;

				if(FileSystem.exists(vert))
				{
					vert = File.getContent(vert);
					found = true;
				}
				else vert = null;

				if(found)
				{
					runtimeShaders.set(name, [frag, vert]);
					//trace('Found shader $name!');
					return true;
				}
			}
		}
		DebugDisplay.instance.addLog('Missing shader $name .frag AND .vert files!', false, false, FlxColor.RED);
		#else
		DebugDisplay.instance.addLog('This platform doesn\'t support Runtime Shaders!', false, false, FlxColor.RED);
		#end
		return false;
	}
}
#end
