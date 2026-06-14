package options;

class DeveloperSettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = Language.getPhrase('developer_menu', 'Developer Settings');
		rpcTitle = 'Developer Settings Menu'; // for Discord Rich Presence

		var option:Option = new Option('Developer Mode', "If checked, you will be able to access the debugger and editor.", 'developerMode', BOOL);
		addOption(option);
		option.onChange = function()
		{
			if (!ClientPrefs.data.developerMode)
			{
				Main.fpsVar.curDisplay = 0;
			}
		}

		var option:Option = new Option('Display Cwd on Console',
			"If checked, it displays the Current Working Directory in the console to streamline file navigation in Visual Studio Code, but it may reduce the console's readability.",
			'displayCwdOnConsole', BOOL);
		addOption(option);
		option.onChange = function()
		{
			Main.updateIrisLogOptions();
		}

		var option:Option = new Option('Colors in Console',
			"If checked, text in the console is colored.\nif you are not using Visual Studio Code, recommend uncheck this setting to improve the console's readability.",
			'colorTextsOnConsole', BOOL);
		addOption(option);
		option.onChange = function()
		{
			Main.updateIrisLogOptions();
		}

		super();
	}
}
