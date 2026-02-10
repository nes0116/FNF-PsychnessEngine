package psychlua;

class CustomState extends MusicBeatState
{
	public static var name:String = 'unnamed';

	public function new(name:String)
	{
		super();
		CustomState.name = name;
	}

	public static var instance:CustomState;
	public static var staticVariables:Map<String, Dynamic> = new Map<String, Dynamic>();

	#if LUA_ALLOWED
	public static function implement(funk:FunkinLua)
	{
		var lua = funk.lua;
		Lua_helper.add_callback(lua, "openCustomState", openCustomState);

		Lua_helper.add_callback(lua, "setStaticVariable", setStaticVariable);
		Lua_helper.add_callback(lua, "getStaticVariable", getStaticVariable);
	}
	#end

	public static function openCustomState(name:String, ?skipTransition:Bool = false)
	{
		if (skipTransition)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
		}
		MusicBeatState.switchState(new CustomState(name));
	}

	public static function setStaticVariable(name:String, variable:Dynamic)
	{
		staticVariables.set(name, variable);
		return true;
	}

	public static function getStaticVariable(name:String, ?defaultValue:Dynamic):Dynamic
	{
		if (!staticVariables.exists(name))
			setStaticVariable(name, defaultValue);
		return staticVariables.get(name);
	}

	var tryed:Int = 0;

	override function create()
	{
		instance = this;

		FlxG.log.notice('OPEN CUSTOM STATE ($name)');

		initScripts(Paths.getSharedPath(), 'scripts/');
		initScripts(Paths.getSharedPath(), 'scripts/states/$name/');

		var stack:Bool = true;
		for (lua in luaArray)
		{
			if (lua.scriptName.contains('$name/') && lua.lua != null)
			{
				stack = false;
				break;
			}
		}

		if (stack)
		{
			var stateName:String = name;
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(new states.ErrorState("NO SCRIPT ADDED FOR "
				+ name.toUpperCase()
				+ "\n\nPress ACCEPT to Restart Custom State.\nPress BACK to return to Main Menu.",
				function() MusicBeatState.switchState(new CustomState(stateName)), function() MusicBeatState.switchState(new states.MainMenuState())));
			return;
		}

		setOnHScript('customState', instance);
		setOnHScript('customStateName', name);

		super.create();

		callOnScripts('onCreatePost');
	}

	override function update(elapsed:Float)
	{
		callOnScripts('onUpdate', [elapsed]);
		super.update(elapsed);
		callOnScripts('onUpdatePost', [elapsed]);
	}

	override function destroy()
	{
		instance = null;
		// name = 'unnamed';

		setOnHScript('customState', null);
		setOnHScript('customStateName', name);
		super.destroy();
	}
}
