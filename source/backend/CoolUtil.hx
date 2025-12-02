package backend;

import backend.Song.SwagSong;
import objects.HealthIcon;
import objects.Character;

@:cppFileCode('
    #include <windows.h>
    #include <shobjidl.h>
    #include <propvarutil.h>
    #include <propsys.h>
    #define INITGUID
    #include <propkey.h>
    #include <combaseapi.h>
    #include <iostream>
    #pragma comment(lib,"ole32.lib")
    #pragma comment(lib,"propsys.lib")
    #pragma comment(lib,"shell32.lib")

    #ifndef PKEY_Comments
    const PROPERTYKEY PKEY_Comments = { {0xf29f85e0,0x4ff9,0x1068,{0xab,0x91,0x08,0x00,0x2b,0x27,0xb3,0xd9}}, 6 };
    #endif
')
class CoolUtil
{
	@:functionCode('
        HRESULT hr = CoInitialize(NULL);
        if (FAILED(hr)) return;

        ICustomDestinationList* pcdl = nullptr;
        hr = CoCreateInstance(CLSID_DestinationList, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&pcdl));
        if (FAILED(hr)) { CoUninitialize(); return; }

        UINT slots = 0;
        IObjectArray* poaRemoved = nullptr;
        hr = pcdl->BeginList(&slots, IID_PPV_ARGS(&poaRemoved));
        if (FAILED(hr)) { pcdl->Release(); CoUninitialize(); return; }

        for(int c = 0; c < categories->__Field("length", hx::paccDynamic); c++) {
            Dynamic category = categories->__GetItem(c);
            String categoryName = category->__Field("name", hx::paccDynamic);
            Dynamic buttons = category->__Field("buttons", hx::paccDynamic);

            IObjectCollection* poc = nullptr;
            hr = CoCreateInstance(CLSID_EnumerableObjectCollection, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&poc));
            if (FAILED(hr)) continue;

            for(int i = 0; i < buttons->__Field("length", hx::paccDynamic); i++) {
                Dynamic btn = buttons->__GetItem(i);
                String exePath = btn->__Field("exePath", hx::paccDynamic);
                String arguments = btn->__Field("arguments", hx::paccDynamic);
                String title = btn->__Field("title", hx::paccDynamic);
                String description = btn->__Field("description", hx::paccDynamic);

                IShellLinkA* psl = nullptr;
                hr = CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&psl));
                if (SUCCEEDED(hr)) {
                    psl->SetPath(exePath.c_str());
                    psl->SetArguments(arguments.c_str());

                    IPropertyStore* pps = nullptr;
                    hr = psl->QueryInterface(IID_PPV_ARGS(&pps));
                    if (SUCCEEDED(hr)) {
                        PROPVARIANT pv;

                        // Title
                        wchar_t wTitle[512];
                        MultiByteToWideChar(CP_UTF8, 0, title.c_str(), -1, wTitle, 512);
                        InitPropVariantFromString(wTitle, &pv);
                        pps->SetValue(PKEY_Title, pv);
                        PropVariantClear(&pv);

                        // Description
                        wchar_t wDesc[512];
                        MultiByteToWideChar(CP_UTF8, 0, description.c_str(), -1, wDesc, 512);
                        InitPropVariantFromString(wDesc, &pv);
                        pps->SetValue(PKEY_Comments, pv);
                        PropVariantClear(&pv);

                        pps->Commit();
                        pps->Release();
                    }

                    poc->AddObject(psl);
                    psl->Release();
                }
            }

            IObjectArray* poa = nullptr;
            hr = poc->QueryInterface(IID_PPV_ARGS(&poa));
            if (SUCCEEDED(hr)) {
                wchar_t wCategory[256];
                MultiByteToWideChar(CP_UTF8, 0, categoryName.c_str(), -1, wCategory, 256);
                pcdl->AppendCategory(wCategory, poa);
                poa->Release();
            }
            poc->Release();
        }

        pcdl->CommitList();
        pcdl->Release();
        CoUninitialize();
    ')
	public static function addJumpListCategories(categories:Array<Dynamic>)
	{
	}

	public static function checkForUpdates(url:String = null):String
	{
		if (url == null || url.length == 0)
			url = "https://raw.githubusercontent.com/nes0116/FNF-PsychnessEngine/refs/heads/main/gitVersion.txt";
		var version:String = states.MainMenuState.psychnessEngineVersion.trim();
		if (ClientPrefs.data.checkForUpdates)
		{
			trace('checking for updates...');
			var http = new haxe.Http(url);
			http.onData = function(data:String)
			{
				var newVersion:String = data.split('\n')[0].trim();
				trace('version online: $newVersion, your version: $version');
				if (newVersion != version)
				{
					trace('versions arent matching! please update');
					version = newVersion;
					http.onData = null;
					http.onError = null;
					http = null;
				}
			}
			http.onError = function(error)
			{
				trace('error: $error');
			}
			http.request();
		}
		return version;
	}

	inline public static function quantize(f:Float, snap:Float)
	{
		// changed so this actually works lol
		var m:Float = Math.fround(f * snap);
		// trace(snap);
		return (m / snap);
	}

	inline public static function capitalize(text:String)
		return text.charAt(0).toUpperCase() + text.substr(1).toLowerCase();

	inline public static function coolTextFile(path:String):Array<String>
	{
		var daList:String = null;
		#if (sys && MODS_ALLOWED)
		if (FileSystem.exists(path))
			daList = File.getContent(path);
		#else
		if (Assets.exists(path))
			daList = Assets.getText(path);
		#end
		return daList != null ? listFromString(daList) : [];
	}

	inline public static function colorFromString(color:String):FlxColor
	{
		var hideChars = ~/[\t\n\r]/;
		var color:String = hideChars.split(color).join('').trim();
		if (color.startsWith('0x'))
			color = color.substring(color.length - 6);

		var colorNum:Null<FlxColor> = FlxColor.fromString(color);
		if (colorNum == null)
			colorNum = FlxColor.fromString('#$color');
		return colorNum != null ? colorNum : FlxColor.WHITE;
	}

	inline public static function listFromString(string:String):Array<String>
	{
		var daList:Array<String> = [];
		daList = string.trim().split('\n');

		for (i in 0...daList.length)
			daList[i] = daList[i].trim();

		return daList;
	}

	public static function floorDecimal(value:Float, decimals:Int):Float
	{
		if (decimals < 1)
			return Math.floor(value);

		var tempMult:Float = 1;
		for (i in 0...decimals)
			tempMult *= 10;

		var newValue:Float = Math.floor(value * tempMult);
		return newValue / tempMult;
	}

	inline public static function dominantColor(sprite:flixel.FlxSprite):Int
	{
		var countByColor:Map<Int, Int> = [];
		for (col in 0...sprite.frameWidth)
		{
			for (row in 0...sprite.frameHeight)
			{
				var colorOfThisPixel:FlxColor = sprite.pixels.getPixel32(col, row);
				if (colorOfThisPixel.alphaFloat > 0.05)
				{
					colorOfThisPixel = FlxColor.fromRGB(colorOfThisPixel.red, colorOfThisPixel.green, colorOfThisPixel.blue, 255);
					var count:Int = countByColor.exists(colorOfThisPixel) ? countByColor[colorOfThisPixel] : 0;
					countByColor[colorOfThisPixel] = count + 1;
				}
			}
		}

		var maxCount = 0;
		var maxKey:Int = 0; // after the loop this will store the max color
		countByColor[FlxColor.BLACK] = 0;
		for (key => count in countByColor)
		{
			if (count >= maxCount)
			{
				maxCount = count;
				maxKey = key;
			}
		}
		countByColor = [];
		return maxKey;
	}

	inline public static function numberArray(max:Int, ?min = 0):Array<Int>
	{
		var dumbArray:Array<Int> = [];
		for (i in min...max)
			dumbArray.push(i);

		return dumbArray;
	}

	inline public static function browserLoad(site:String)
	{
		#if linux
		Sys.command('/usr/bin/xdg-open', [site]);
		#else
		FlxG.openURL(site);
		#end
	}

	inline public static function openFolder(folder:String, absolute:Bool = false)
	{
		#if sys
		if (!absolute)
			folder = Sys.getCwd() + '$folder';

		folder = folder.replace('/', '\\');
		if (folder.endsWith('/'))
			folder.substr(0, folder.length - 1);

		#if linux
		var command:String = '/usr/bin/xdg-open';
		#else
		var command:String = 'explorer.exe';
		#end
		Sys.command(command, [folder]);
		trace('$command $folder');
		#else
		FlxG.error("Platform is not supported for CoolUtil.openFolder");
		#end
	}

	/**
		Helper Function to Fix Save Files for Flixel 5

		-- EDIT: [November 29, 2023] --

		this function is used to get the save path, period.
		since newer flixel versions are being enforced anyways.
		@crowplexus
	**/
	@:access(flixel.util.FlxSave.validate)
	inline public static function getSavePath():String
	{
		final company:String = FlxG.stage.application.meta.get('company');
		// #if (flixel < "5.0.0") return company; #else
		return '${company}/${flixel.util.FlxSave.validate(FlxG.stage.application.meta.get('file'))}';
		// #end
	}

	public static function setTextBorderFromString(text:FlxText, border:String)
	{
		switch (border.toLowerCase().trim())
		{
			case 'shadow':
				text.borderStyle = SHADOW;
			case 'outline':
				text.borderStyle = OUTLINE;
			case 'outline_fast', 'outlinefast':
				text.borderStyle = OUTLINE_FAST;
			default:
				text.borderStyle = NONE;
		}
	}

	public static function getCharacterDataFromString(name:String):Dynamic
	{
		var song:SwagSong = PlayState.SONG;
		var game:PlayState = PlayState.instance;

		var character:Character = game.boyfriend;
		var charType:Int = 0;
		var map:Map<String, Character> = game.boyfriendMap;
		var array:Array<Character> = game.players;
		var icon:HealthIcon = game.iconP1;
		var scriptShit:String = 'boyfriendName';

		var formatedCharNames:Array<String> = [];
		for (i in 0...game.characters.length)
			formatedCharNames.push(game.characters[i].curCharacter + "#" + game.characters[i].charIndex);

		if (!formatedCharNames.contains(name))
		{
			switch (name.toLowerCase().trim())
			{
				case 'bf' | 'boyfriend' | 'player' | '0':
					character = game.boyfriend;
					map = game.boyfriendMap;
					array = game.players;
					charType = 0;
					icon = game.iconP1;
					scriptShit = 'boyfriendName';
				case 'dad' | 'opponent' | '1':
					character = game.dad;
					map = game.dadMap;
					array = game.opponents;
					charType = 1;
					icon = game.iconP2;
					scriptShit = 'dadName';
				case 'gf' | 'girlfriend' | '2':
					character = game.gf;
					map = game.gfMap;
					array = game.girlfriends;
					charType = 2;
					icon = null;
					scriptShit = 'gfName';
			}
		}
		else
		{
			if (song.characters[formatedCharNames.indexOf(name)].characterType == 'player')
			{
				character = game.characters[formatedCharNames.indexOf(name)];
				map = game.boyfriendMap;
				array = game.players;
				charType = 0;
				icon = game.iconP1;
				scriptShit = 'boyfriendName';
			}
			if (song.characters[formatedCharNames.indexOf(name)].characterType == 'opponent')
			{
				character = game.characters[formatedCharNames.indexOf(name)];
				map = game.dadMap;
				array = game.opponents;
				charType = 1;
				icon = game.iconP2;
				scriptShit = 'dadName';
			}
			if (song.characters[formatedCharNames.indexOf(name)].characterType == 'girlfriend')
			{
				character = game.characters[formatedCharNames.indexOf(name)];
				map = game.gfMap;
				array = game.girlfriends;
				charType = 2;
				icon = null;
				scriptShit = 'gfName';
			}
		}

		return {
			character: character,
			charType: charType,
			map: map,
			array: array,
			icon: icon,
			scriptShit: scriptShit
		};
	}
}
