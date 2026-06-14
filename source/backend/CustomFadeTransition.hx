package backend;

import flixel.FlxBasic;
import flixel.util.FlxGradient;

class CustomFadeTransition extends MusicBeatSubstate
{
	public static var finishCallback:Void->Void;
	public static var name:String;

	var isTransIn:Bool = false;
	var transBlack:FlxSprite;
	var transGradient:FlxSprite;

	var duration:Float;

	public function new(duration:Float, isTransIn:Bool)
	{
		this.duration = duration;
		this.isTransIn = isTransIn;
		super();
	}

	#if HSCRIPT_ALLOWED
	var hscript:HScript;
	#end

	override function create()
	{
		var camTransition:FlxCamera = new FlxCamera();
		camTransition.bgColor.alpha = 0;
		FlxG.cameras.add(camTransition, false);
		cameras = [camTransition];

		var width:Int = Std.int(FlxG.width / Math.max(camera.zoom, 0.001));
		var height:Int = Std.int(FlxG.height / Math.max(camera.zoom, 0.001));
		transGradient = FlxGradient.createGradientFlxSprite(1, height, (isTransIn ? [0x0, FlxColor.BLACK] : [FlxColor.BLACK, 0x0]));
		transGradient.scale.x = width;
		transGradient.updateHitbox();
		transGradient.scrollFactor.set();
		transGradient.screenCenter(X);
		add(transGradient);

		transBlack = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		transBlack.scale.set(width, height + 400);
		transBlack.updateHitbox();
		transBlack.scrollFactor.set();
		transBlack.screenCenter(X);
		add(transBlack);

		if (isTransIn)
			transGradient.y = transBlack.y - transBlack.height;
		else
			transGradient.y = -transGradient.height;

		var curModDirectory:String = Mods.currentModDirectory.trim().length > 0 ? Mods.currentModDirectory : Mods.parseList().enabled[0];

		#if HSCRIPT_ALLOWED
		if (curModDirectory != null && curModDirectory.length > 0 && name.length > 0)
		{
			var scriptPath:String = 'mods/${curModDirectory}/scripts/transitions/$name.hx';
			if (FileSystem.exists(scriptPath))
			{
				try
				{
					hscript = new HScript(null, scriptPath);
					hscript.set('this', this);
					hscript.set('duration', duration);
					hscript.set('isTransIn', isTransIn);
					hscript.set('transGradient', transGradient);
					hscript.set('transBlack', transBlack);

					hscript.set('finish', () -> close());

					hscript.set('add', (object:FlxBasic) -> return add(object));
					hscript.set('remove', (object:FlxBasic, splice:Bool = false) -> return remove(object, splice));
					hscript.set('insert', (position:Int, object:FlxBasic) -> return insert(position, object));
					hscript.set('members', members);

					if (hscript.exists('onCreate'))
					{
						hscript.call('onCreate');
						trace('initialized hscript interp successfully: $scriptPath');
						return super.create();
					}
					else
					{
						trace('"$scriptPath" contains no \"onCreate" function, stopping script.');
					}
				}
				catch (e:IrisError)
				{
					var pos:HScriptInfos = cast {fileName: scriptPath, showLine: false};
					Iris.error(Printer.errorToString(e, false), pos);
					var hscript:HScript = cast(Iris.instances.get(scriptPath), HScript);
				}
				if (hscript != null)
					hscript.destroy();
				hscript = null;
			}
		}
		#end

		if (hscript != null && hscript.exists('onCreatePost'))
			hscript.call('onCreatePost');

		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (hscript != null && hscript.exists('onUpdate'))
			hscript.call('onUpdate', [elapsed]);

		final height:Float = FlxG.height * Math.max(camera.zoom, 0.001);
		final targetPos:Float = transGradient.height + 50 * Math.max(camera.zoom, 0.001);
		if (duration > 0)
			transGradient.y += (height + targetPos) * elapsed / duration;
		else
			transGradient.y = (targetPos) * elapsed;

		if (isTransIn)
			transBlack.y = transGradient.y + transGradient.height;
		else
			transBlack.y = transGradient.y - transBlack.height;

		if (transGradient.y >= targetPos)
		{
			close();
		}

		if (hscript != null && hscript.exists('onUpdatePost'))
			hscript.call('onUpdatePost', [elapsed]);
	}

	var calledFinish:Bool = false;

	// Don't delete this
	override function close():Void
	{
		super.close();

		if (hscript != null && hscript.exists('onFinish') && !calledFinish)
		{
			calledFinish = true;
			var ret:Dynamic = hscript.call('onFinish');
			if (ret.returnValue == LuaUtils.Function_Stop)
				return;
		}

		if (finishCallback != null)
		{
			finishCallback();
			finishCallback = null;
		}
	}
}
