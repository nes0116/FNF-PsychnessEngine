package;

import states.StoryMenuState;
import states.FreeplayState;
#if android
import android.content.Context;
#end
import debug.DebugDisplay;
import debug.FPSCounter;
import flixel.graphics.FlxGraphic;
import flixel.FlxGame;
import flixel.FlxState;
import haxe.io.Path;
import openfl.Assets;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.display.StageScaleMode;
import lime.app.Application;
import states.TitleState;
#if HSCRIPT_ALLOWED
import crowplexus.iris.Iris;
import psychlua.HScript.HScriptInfos;
#end
#if linux
import lime.graphics.Image;
#end
#if desktop
import backend.ALSoftConfig; // Just to make sure DCE doesn't remove this, since it's not directly referenced anywhere else.
#end
// crash handler stuff
#if CRASH_HANDLER
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.io.Path;
#end
import backend.Highscore;

using StringTools;

// NATIVE API STUFF, YOU CAN IGNORE THIS AND SCROLL //
#if (linux && !debug)
@:cppInclude('./external/gamemode_client.h')
@:cppFileCode('#define GAMEMODE_AUTO')
#end
#if windows
@:buildXml('
<target id="haxe">
	<lib name="wininet.lib" if="windows" />
	<lib name="dwmapi.lib" if="windows" />
</target>
')
@:cppFileCode('
#include <windows.h>
#include <winuser.h>
#pragma comment(lib, "Shell32.lib")
extern "C" HRESULT WINAPI SetCurrentProcessExplicitAppUserModelID(PCWSTR AppID);
')
#end
// // // // // // // // //
class Main extends Sprite
{
	var game = {
		width: 1280, // WINDOW width
		height: 720, // WINDOW height
		initialState: InitState, // initial game state
		framerate: 60, // default framerate
		skipSplash: true, // if the default flixel splash screen should be skipped
		startFullscreen: false // if the game should start at fullscreen mode
	};

	public static var fpsVar:DebugDisplay;

	public static var openNewChart:Bool = false;
	public static var loadChartPath:Array<String>;

	// You can pretty much ignore everything from here on - your code should go in your states.

	public static function main():Void
	{
		var argsMap = parseArgs();
		for (key in argsMap.keys())
			trace(key + " => " + argsMap.get(key));
		if (argsMap.exists("cwd"))
			Sys.setCwd(argsMap.get('cwd'));
		if (argsMap.exists("chart"))
			loadChartPath = [argsMap.get('chart'), argsMap.get('modDirectory')];
		if (argsMap.exists("newChart"))
			openNewChart = argsMap.get('newChart');

		#if windows
		untyped __cpp__("{\n        HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);\n        DWORD dwMode = 0;\n        if (GetConsoleMode(hOut, &dwMode))\n            SetConsoleMode(hOut, dwMode | 0x0004);\n    }");
		untyped __cpp__("SetConsoleOutputCP(65001);");
		untyped __cpp__("SetConsoleCP(65001);");
		#end

		Lib.current.addChild(new Main());
	}

	/**
		Converts application arguments to a Map<String, Dynamic>.
	**/
	public static function parseArgs():Map<String, Dynamic>
	{
		var map = new Map<String, Dynamic>();
		for (arg in Sys.args())
		{
			if (arg.startsWith("--"))
			{
				var parts = arg.substr(2).split("=");
				var key = parts[0];
				var value:Dynamic = true;

				if (parts.length > 1)
				{
					var strVal = parts[1];
					if (strVal == "true")
						value = true;
					else if (strVal == "false")
						value = false;
					else
						value = strVal;
				}

				map.set(key, value);
			}
		}
		return map;
	}

	/**
		When the game is closed.
	**/
	public static var onClose:Void->Void;

	/**
		When a file is dropped into the game.
	**/
	public static var onDropFile:String->Void;

	public function new()
	{
		super();

		#if windows
		// DPI Scaling fix for windows
		// this shouldn't be needed for other systems
		// Credit to YoshiCrafter29 for finding this function
		untyped __cpp__("SetProcessDPIAware();");
		#end

		// Credits to MAJigsaw77 (he's the og author for this code)
		#if android
		Sys.setCwd(Path.addTrailingSlash(Context.getExternalFilesDir()));
		#elseif ios
		Sys.setCwd(lime.system.System.applicationStorageDirectory);
		#end
		#if VIDEOS_ALLOWED
		hxvlc.util.Handle.init(#if (hxvlc >= "1.8.0") ['--no-lua'] #end);
		#end

		#if LUA_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		FlxG.save.bind('funkin', CoolUtil.getSavePath());
		Highscore.load();

		#if HSCRIPT_ALLOWED
		updateIrisLogOptions();
		#end

		#if LUA_ALLOWED Lua.set_callbacks_function(cpp.Callable.fromStaticFunction(psychlua.CallbackHandler.call)); #end
		Controls.instance = new Controls();
		ClientPrefs.loadDefaultKeys();
		#if ACHIEVEMENTS_ALLOWED Achievements.load(); #end
		addChild(new FlxGame(game.width, game.height, game.initialState, game.framerate, game.framerate, game.skipSplash, game.startFullscreen));
		updateLogOptions();

		#if !mobile
		fpsVar = new DebugDisplay(10, 10);
		addChild(fpsVar);
		Lib.current.stage.align = "tl";
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
		if (fpsVar != null)
		{
			fpsVar.visible = ClientPrefs.data.showFPS;
		}
		#end

		#if linux
		var icon = Image.fromFile("icon.png");
		Lib.current.stage.window.setIcon(icon);
		#end

		#if html5
		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		#end

		FlxG.fixedTimestep = false;
		FlxG.game.focusLostFramerate = 60;
		FlxG.keys.preventDefaultKeys = [TAB];

		#if CRASH_HANDLER
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
		#end

		#if DISCORD_ALLOWED
		DiscordClient.prepare();
		#end

		Lib.application.window.onClose.add(function()
		{
			if (onClose != null)
				onClose();
		});
		Lib.application.window.onDropFile.add(function(filePath:String)
		{
			if (onDropFile != null)
				onDropFile(filePath);
		});

		// shader coords fix
		FlxG.signals.gameResized.add(function(w, h)
		{
			if (FlxG.cameras != null)
			{
				for (cam in FlxG.cameras.list)
				{
					if (cam != null && cam.filters != null)
						resetSpriteCache(cam.flashSprite);
				}
			}

			if (FlxG.game != null)
				resetSpriteCache(FlxG.game);
		});
	}

	static function resetSpriteCache(sprite:Sprite):Void
	{
		@:privateAccess {
			sprite.__cacheBitmap = null;
			sprite.__cacheBitmapData = null;
		}
	}

	public static function updateLogOptions()
	{
		haxe.Log.trace = function(v:Dynamic, ?infos:haxe.PosInfos)
		{
			var time:String = DateTools.format(Date.now(), "%H:%M:%S");
			var message:String = '[  \x1b[32m$time  \x1b[0m|  \x1b[36m${infos.fileName}:${infos.lineNumber}: (${infos.methodName})  \x1b[0m] $v';
			if (!ClientPrefs.data.colorTextsOnConsole)
				message = '[  $time  |  ${infos.fileName}:${infos.lineNumber}: (${infos.methodName})  ] $v';
			Sys.println(message);
		}
	}

	#if HSCRIPT_ALLOWED
	public static function updateIrisLogOptions()
	{
		Iris.print = function(x, ?pos:haxe.PosInfos)
		{
			var time:String = DateTools.format(Date.now(), "%H:%M:%S");
			var path:String = ClientPrefs.data.displayCwdOnConsole ? Sys.getCwd() + pos.fileName : pos.fileName;
			path = path.replace("\\", "/");
			var newPos:HScriptInfos = cast pos;
			if (newPos.showLine == null)
				newPos.showLine = true;
			var message:String = '[  \x1b[32m$time  \x1b[0m|  \x1b[33m$path:${newPos.lineNumber}:${newPos.funcName != null ? ' (${newPos.funcName})' : ''}  \x1b[0m] $x';
			if (!ClientPrefs.data.colorTextsOnConsole)
				message = '[  $time  |  $path:${newPos.lineNumber}:${newPos.funcName != null ? ' (${newPos.funcName})' : ''}  ] $x';
			Sys.println(message);
			DebugDisplay.instance.addLog(x, false, false, 0xFFFFFFFF);
		}

		Iris.warn = function(x, ?pos:haxe.PosInfos)
		{
			var time:String = DateTools.format(Date.now(), "%H:%M:%S");
			var path:String = Sys.getCwd() + pos.fileName;
			path = path.replace("\\", "/");
			var newPos:HScriptInfos = cast pos;
			if (newPos.showLine == null)
				newPos.showLine = true;
			var message:String = '[  \x1b[32m$time  \x1b[0m|  \x1b[33m$path:${newPos.lineNumber}:${newPos.funcName != null ? ' (${newPos.funcName})' : ''}  \x1b[0m] \x1b[33m$x\x1b[0m';
			if (!ClientPrefs.data.colorTextsOnConsole)
				message = '[  $time  |  $path:${newPos.lineNumber}:${newPos.funcName != null ? ' (${newPos.funcName})' : ''}  ] $x';
			Sys.println(message);
			DebugDisplay.instance.addLog(x, false, false, 0xFFFFFF00);
		}

		Iris.error = function(x, ?pos:haxe.PosInfos)
		{
			var time:String = DateTools.format(Date.now(), "%H:%M:%S");
			var path:String = Sys.getCwd() + pos.fileName;
			path = path.replace("\\", "/");
			var newPos:HScriptInfos = cast pos;
			if (newPos.showLine == null)
				newPos.showLine = true;
			var message:String = '[  \x1b[32m$time  \x1b[0m|  \x1b[31m$path:${newPos.lineNumber}:${newPos.funcName != null ? ' (${newPos.funcName})' : ''}  \x1b[0m] \x1b[31m$x\x1b[0m';
			if (!ClientPrefs.data.colorTextsOnConsole)
				message = '[  $time  |  $path:${newPos.lineNumber}:${newPos.funcName != null ? ' (${newPos.funcName})' : ''}  ] $x';
			Sys.println(message);
			DebugDisplay.instance.addLog(x, false, false, 0xFFFF0000);
		}

		Iris.fatal = function(x, ?pos:haxe.PosInfos)
		{
			var time:String = DateTools.format(Date.now(), "%H:%M:%S");
			var path:String = Sys.getCwd() + pos.fileName;
			path = path.replace("\\", "/");
			var newPos:HScriptInfos = cast pos;
			if (newPos.showLine == null)
				newPos.showLine = true;
			var message:String = '[  \x1b[32m$time  \x1b[0m|  \x1b[31m$path:${newPos.lineNumber}:${newPos.funcName != null ? ' (${newPos.funcName})' : ''}  \x1b[0m] \x1b[31m$x\x1b[0m';
			if (!ClientPrefs.data.colorTextsOnConsole)
				message = '[  $time  |  $path:${newPos.lineNumber}:${newPos.funcName != null ? ' (${newPos.funcName})' : ''}  ] $x';
			Sys.println(message);
			DebugDisplay.instance.addLog(x, false, false, 0xFFFF0000);
		}
	}
	#end

	// Code was entirely made by sqirra-rng for their fnf engine named "Izzy Engine", big props to them!!!
	// very cool person for real they don't get enough credit for their work
	#if CRASH_HANDLER
	function onCrash(e:UncaughtErrorEvent):Void
	{
		var errMsg:String = "";
		var path:String;
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var dateNow:String = Date.now().toString();

		dateNow = dateNow.replace(" ", "_");
		dateNow = dateNow.replace(":", "'");

		path = "./crash/" + "PsychEngine_" + dateNow + ".txt";

		for (stackItem in callStack)
		{
			switch (stackItem)
			{
				case FilePos(s, file, line, column):
					errMsg += file + " (line " + line + ")\n";
				default:
					Sys.println(stackItem);
			}
		}

		errMsg += "\nUncaught Error: " + e.error;
		// remove if you're modding and want the crash log message to contain the link
		// please remember to actually modify the link for the github page to report the issues to.
		errMsg += "\n\n> Crash Handler written by: sqirra-rng";

		if (!FileSystem.exists("./crash/"))
			FileSystem.createDirectory("./crash/");

		File.saveContent(path, errMsg + "\n");

		Sys.println(errMsg);
		Sys.println("Crash dump saved in " + Path.normalize(path));

		Application.current.window.alert(errMsg, "Error!");
		#if DISCORD_ALLOWED
		DiscordClient.shutdown();
		#end
		Sys.exit(1);
	}
	#end
}
