package debug;

import openfl.events.MouseEvent;
import openfl.filters.GlowFilter;
import openfl.Lib;
import openfl.text.TextFormat;
import openfl.text.TextField;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.events.KeyboardEvent;
import states.editors.MasterEditorMenu;
import lime.math.Rectangle;
import options.ControlsSubState;

class DebugDisplay extends Sprite
{
	public static var instance:DebugDisplay;

	var frameBG:Bitmap;
	var frameTF:TextField;

	var engineBG:Bitmap;
	var engineTF:TextField;

	var stateBG:Bitmap;
	var stateTF:TextField;

	var scriptBG:Bitmap;
	var scriptTF:TextField;

	var debugBG:Bitmap;
	var debugTF:TextField;

	var logBG:Bitmap;
	var logTF:TextField;

	var screenshotPreview:Sprite;
	var screenshotPreviewTween:FlxTween;

	var logBGArray:Array<Bitmap> = [];
	var logTFArray:Array<TextField> = [];

	public function addLog(value:Dynamic, ignoreCheck:Bool = true, deprecated:Bool = false, color:Int = 0xFFFFFFFF)
	{
		if (ignoreCheck || FunkinLua.getBool('luaDebugMode'))
		{
			if (deprecated && !FunkinLua.getBool('luaDeprecatedWarnings'))
			{
				return;
			}

			trace(value);

			var logBG = new Bitmap(new BitmapData(1, 1, true, FlxColor.BLACK));
			logBG.alpha = 0.5;
			addChildAt(logBG, getChildIndex(frameBG));

			var logTF:TextField = new TextField();
			logTF.defaultTextFormat = new TextFormat(openfl.utils.Assets.getFont(Paths.font('HackGenConsoleNF-Regular.ttf')).fontName, 16, color);
			logTF.text = Std.string(value);
			logTF.autoSize = RIGHT;
			logTF.selectable = true;
			addChildAt(logTF, getChildIndex(frameBG));

			logBG.width = logTF.width + 10;
			logBG.height = logTF.height + 10;
			logBG.x = Lib.current.stage.stageWidth - logBG.width - 20;
			logBG.y = Lib.current.stage.stageHeight - logBG.height - 20;

			logTF.x = logBG.x + 5;
			logTF.y = logBG.y + 5;

			for (obj in logBGArray)
			{
				obj.y -= logBG.height;
			}

			for (i in 0...logBGArray.length)
			{
				logTFArray[i].x = logBGArray[i].x + 5;
				logTFArray[i].y = logBGArray[i].y + 5;
			}

			logBGArray.push(logBG);
			logTFArray.push(logTF);
		}
	}

	public function clearLog()
	{
		for (obj in logBGArray)
		{
			removeChild(obj);
		}

		for (obj in logTFArray)
		{
			removeChild(obj);
		}

		logBGArray = [];
		logTFArray = [];
	}

	@:noCompletion private var times:Array<Float>;

	public var curDisplay:Int = 0;

	var ogSystemMouse:Bool = false;

	public function new(x:Float = 5, y:Float = 5)
	{
		super();

		instance = this;

		this.x = x;
		this.y = y;

		frameBG = new Bitmap(new BitmapData(1, 1, true, FlxColor.BLACK));
		frameBG.alpha = 0.5;
		addChild(frameBG);

		frameTF = new TextField();
		frameTF.defaultTextFormat = new TextFormat(openfl.utils.Assets.getFont(Paths.font('HackGenConsoleNF-Regular.ttf')).fontName, 16, 0xFFFFFF);
		frameTF.autoSize = LEFT;
		frameTF.selectable = false;
		addChild(frameTF);

		engineBG = new Bitmap(new BitmapData(1, 1, true, FlxColor.BLACK));
		engineBG.alpha = 0.5;
		addChild(engineBG);

		engineTF = new TextField();
		engineTF.defaultTextFormat = new TextFormat(openfl.utils.Assets.getFont(Paths.font('HackGenConsoleNF-Regular.ttf')).fontName, 16, 0xFFFFFF);
		engineTF.autoSize = LEFT;
		engineTF.selectable = false;
		addChild(engineTF);

		stateBG = new Bitmap(new BitmapData(1, 1, true, FlxColor.BLACK));
		stateBG.alpha = 0.5;
		addChild(stateBG);

		stateTF = new TextField();
		stateTF.defaultTextFormat = new TextFormat(openfl.utils.Assets.getFont(Paths.font('HackGenConsoleNF-Regular.ttf')).fontName, 16, 0xFFFFFF);
		stateTF.autoSize = LEFT;
		stateTF.selectable = false;
		addChild(stateTF);

		scriptBG = new Bitmap(new BitmapData(1, 1, true, FlxColor.BLACK));
		scriptBG.alpha = 0.5;
		addChild(scriptBG);

		scriptTF = new TextField();
		scriptTF.defaultTextFormat = new TextFormat(openfl.utils.Assets.getFont(Paths.font('HackGenConsoleNF-Regular.ttf')).fontName, 16, 0xFFFFFF);
		scriptTF.autoSize = LEFT;
		scriptTF.selectable = false;
		addChild(scriptTF);

		debugBG = new Bitmap(new BitmapData(1, 1, true, FlxColor.BLACK));
		debugBG.alpha = 0.5;
		addChild(debugBG);

		debugTF = new TextField();
		debugTF.defaultTextFormat = new TextFormat(openfl.utils.Assets.getFont(Paths.font('HackGenConsoleNF-Regular.ttf')).fontName, 16, 0xFFFFFF);
		debugTF.autoSize = LEFT;
		debugTF.selectable = false;
		addChild(debugTF);

		if (FlxG.save.data.displayDebugType != null)
			curDisplay = FlxG.save.data.displayDebugType;

		FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, function(e:KeyboardEvent)
		{
			// Take screenshot
			if (e.keyCode == ClientPrefs.keyBinds.get('screen_shot')[0] || e.keyCode == ClientPrefs.keyBinds.get('screen_shot')[1])
			{
				function formatNum(num:Int):String
				{
					return num < 10 ? '0' + num : '' + num;
				}

				if (!FileSystem.exists("./screenshots/"))
					FileSystem.createDirectory("./screenshots/");

				var fileName:String = 'Screenshot-${formatNum(Date.now().getFullYear())}-${formatNum(Date.now().getMonth() + 1)}-${formatNum(Date.now().getDate())} ${formatNum(Date.now().getHours())}${formatNum(Date.now().getMinutes())}${formatNum(Date.now().getSeconds())}';
				File.saveBytes('screenshots/' + fileName + '.png',
					FlxG.stage.window.readPixels(new Rectangle(0, 0, FlxG.stage.window.width, FlxG.stage.window.height)).encode());

				if (FlxG.game.getChildByName('screenshotPreview') != null)
					FlxG.removeChild(FlxG.game.getChildByName('screenshotPreview'));
				screenshotPreview = new Sprite();
				var screenshotBitmap = new Bitmap(BitmapData.fromImage(FlxG.stage.window.readPixels()));
				screenshotPreview.addChild(screenshotBitmap);
				screenshotPreview.scaleX = screenshotPreview.scaleY = 0.25;
				screenshotPreview.x = 10;
				screenshotPreview.y = 10;
				screenshotPreview.name = 'screenshotPreview';
				screenshotPreview.filters = [new GlowFilter(0xFF000000, 1, 10, 10)];
				FlxG.addChildBelowMouse(screenshotPreview);
				if (screenshotPreviewTween != null)
					screenshotPreviewTween.cancel();
				screenshotPreviewTween = FlxTween.tween(screenshotPreview, {alpha: 0}, 0.15, {
					ease: FlxEase.quadOut,
					startDelay: 3,
					onComplete: _ ->
					{
						screenshotPreview = null;
						FlxG.removeChild(screenshotPreview);
					}
				});
				screenshotPreview.y -= 10;
				screenshotPreview.buttonMode = true;
				screenshotPreview.addEventListener(MouseEvent.MOUSE_DOWN, (e:MouseEvent) ->
				{
					CoolUtil.openFolder('screenshots/');
				});
				FlxTween.tween(screenshotPreview, {y: screenshotPreview.y + 10}, 0.25, {ease: FlxEase.quadOut});

				var flashBitmap = new Bitmap(new BitmapData(Std.int(FlxG.stage.width), Std.int(FlxG.stage.height), false, 0xFFFFFFFF));
				var flashSpr = new Sprite();
				flashSpr.addChild(flashBitmap);
				FlxG.addChildBelowMouse(flashSpr);
				if (!ClientPrefs.data.flashing)
					flashSpr.alpha = 0.1;
				FlxTween.tween(flashSpr, {alpha: 0}, 0.15, {ease: FlxEase.quadOut, onComplete: _ -> FlxG.removeChild(flashSpr)});

				FlxG.sound.play(Paths.sound('screenshot'));
			}

			if (e.keyCode == ClientPrefs.keyBinds.get('debug_3')[0] || e.keyCode == ClientPrefs.keyBinds.get('debug_3')[1])
			{
				curDisplay = FlxMath.wrap(curDisplay + 1, 0, ClientPrefs.data.developerMode ? 3 : 1);

				if (curDisplay != 3)
				{
					FlxG.mouse.useSystemCursor = ogSystemMouse;
				}
				if (curDisplay == 3)
				{
					ogSystemMouse = FlxG.mouse.useSystemCursor;
					FlxG.mouse.useSystemCursor = true;
				}

				FlxG.save.data.displayDebugType = curDisplay;
				FlxG.save.flush();
			}

			if (e.keyCode == ClientPrefs.keyBinds.get('debug_4')[0] || e.keyCode == ClientPrefs.keyBinds.get('debug_4')[1])
			{
				if (!ClientPrefs.data.developerMode)
				{
					return;
				}
				MasterEditorMenu.showConsole();
			}

			if (e.keyCode == ClientPrefs.keyBinds.get('debug_5')[0] || e.keyCode == ClientPrefs.keyBinds.get('debug_5')[1])
			{
				if (!ClientPrefs.data.developerMode && MusicBeatState.instance != null)
					return;
				FlxG.state.persistentUpdate = false;
				var curState:String = Type.getClassName(Type.getClass(FlxG.state));
				if (curState != 'psychlua.CustomState')
				{
					FlxTransitionableState.skipNextTransOut = true;
					FlxG.resetState();
				}
				else
				{
					FlxTransitionableState.skipNextTransOut = true;
					FlxG.switchState(new CustomState(CustomState.name));
				}
				trace('Reloading State...');
			}
		});

		Lib.application.window.onResize.add(function(width:Int, height:Int)
		{
			var yCursor = Lib.current.stage.stageHeight - 20;
			for (i in 0...logBGArray.length)
			{
				var idx = logBGArray.length - 1 - i;
				var logBG = logBGArray[idx];
				var logTF = logTFArray[idx];

				logBG.x = Lib.current.stage.stageWidth - logBG.width - 20;
				yCursor -= Std.int(logBG.height);
				logBG.y = yCursor;
				yCursor -= 0;

				logTF.x = logBG.x + 5;
				logTF.y = logBG.y + 5;
			}
		});

		times = [];
	}

	public var currentFPS(default, null):Int;
	public var memoryMegas(get, never):Float;
	public var maxMemoryMegas:Float;

	private override function __enterFrame(deltaTime:Float):Void
	{
		final now:Float = haxe.Timer.stamp() * 1000;
		times.push(now);
		while (times[0] < now - 1000)
			times.shift();
		currentFPS = times.length < FlxG.updateFramerate ? times.length : FlxG.updateFramerate;
		if (memoryMegas > maxMemoryMegas)
			maxMemoryMegas = memoryMegas;

		frameTF.text = 'FPS: ${Std.string(Math.floor(currentFPS))}'
			+ '\nMemory: ${flixel.util.FlxStringUtil.formatBytes(memoryMegas)} / ${flixel.util.FlxStringUtil.formatBytes(maxMemoryMegas)}';

		engineTF.text = 'Psych Engine: v${MainMenuState.psychEngineVersion}' + '\nPsychness Engine: v${MainMenuState.psychnessEngineVersion}';

		var curState:String = Type.getClassName(Type.getClass(FlxG.state));
		stateTF.text = 'Current State: $curState'
			+ (curState == 'psychlua.CustomState' ? ' (${CustomState.name})' : '')
			+ '\nObjects: ${FlxG.state.members.length}';

		scriptTF.text = 'Running Lua Scripts: ${MusicBeatState.instance == null ? 0 : MusicBeatState.instance.luaArray.length}'
			+ '\nRunning Haxe Sctipts: ${MusicBeatState.instance == null ? 0 : MusicBeatState.instance.hscriptArray.length}';

		debugBG.visible = debugTF.visible = debugTF.text.length != 0;
		debugTF.text = '${mapToPrettyString(MusicBeatState.instance == null ? new Map<String, Dynamic>() : MusicBeatState.instance.debugVariables)}';

		frameBG.width = frameTF.width + 10;
		frameBG.height = frameTF.height + 10;

		frameTF.x = frameBG.x + 5;
		frameTF.y = frameBG.y + 5;

		engineBG.y = frameBG.y + frameBG.height + 10;
		engineBG.width = engineTF.width + 10;
		engineBG.height = engineTF.height + 10;

		engineTF.x = engineBG.x + 5;
		engineTF.y = engineBG.y + 5;

		stateBG.y = engineBG.y + engineBG.height + 10;
		stateBG.width = stateTF.width + 10;
		stateBG.height = stateTF.height + 10;

		stateTF.x = stateBG.x + 5;
		stateTF.y = stateBG.y + 5;

		scriptBG.y = stateBG.y + stateBG.height + 10;
		scriptBG.width = scriptTF.width + 10;
		scriptBG.height = scriptTF.height + 10;

		scriptTF.x = scriptBG.x + 5;
		scriptTF.y = scriptBG.y + 5;

		debugBG.y = Lib.current.stage.stageHeight - debugBG.height - 20;
		debugBG.width = debugTF.width + 10;
		debugBG.height = debugTF.height + 10;

		debugTF.x = debugBG.x + 5;
		debugTF.y = debugBG.y + 5;

		switch (curDisplay)
		{
			case 0:
				frameBG.visible = false;
				frameTF.visible = false;
				engineBG.visible = false;
				engineTF.visible = false;
				stateBG.visible = false;
				stateTF.visible = false;
				scriptBG.visible = false;
				scriptTF.visible = false;
				debugBG.visible = false;
				debugTF.visible = false;

				for (obj in logBGArray)
					obj.visible = false;
				for (obj in logTFArray)
					obj.visible = false;
			case 1:
				frameBG.visible = true;
				frameTF.visible = true;
				engineBG.visible = false;
				engineTF.visible = false;
				stateBG.visible = false;
				stateTF.visible = false;
				scriptBG.visible = false;
				scriptTF.visible = false;
				debugBG.visible = false;
				debugTF.visible = false;

				for (obj in logBGArray)
					obj.visible = false;
				for (obj in logTFArray)
					obj.visible = false;
			case 2:
				frameBG.visible = true;
				frameTF.visible = true;
				engineBG.visible = true;
				engineTF.visible = true;
				stateBG.visible = true;
				stateTF.visible = true;
				scriptBG.visible = true;
				scriptTF.visible = true;
				debugBG.visible = false;
				debugTF.visible = false;

				for (obj in logBGArray)
					obj.visible = false;
				for (obj in logTFArray)
					obj.visible = false;
			case 3:
				frameBG.visible = true;
				frameTF.visible = true;
				engineBG.visible = true;
				engineTF.visible = true;
				stateBG.visible = true;
				stateTF.visible = true;
				scriptBG.visible = true;
				scriptTF.visible = true;
				debugBG.visible = true;
				debugTF.visible = true;

				for (obj in logBGArray)
					obj.visible = true;
				for (obj in logTFArray)
					obj.visible = true;

				FlxG.mouse.useSystemCursor = true;
		}
	}

	inline function mapToPrettyString(map:Map<String, Dynamic>):String
	{
		var keys = [];
		for (k in map.keys())
			keys.push(k);
		keys.sort(function(a:String, b:String):Int
		{
			var aLower = a.toLowerCase();
			var bLower = b.toLowerCase();
			if (aLower < bLower)
				return -1;
			else if (aLower > bLower)
				return 1;
			else
				return 0;
		});

		var buf = new StringBuf();
		for (k in keys)
		{
			var v = map.get(k);
			buf.add(k + ": " + Std.string(v));
			buf.add("\n");
		}
		return buf.toString();
	}

	inline function get_memoryMegas():Float
		return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
}
