package backend;

import haxe.Json;
import lime.utils.Assets;
import objects.Note;

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var events:Array<Dynamic>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;
	var offset:Float;

	var characters:Array<SwagCharacter>;
	var stage:String;
	var format:String;

	@:optional var player1:String;
	@:optional var player2:String;
	@:optional var gfVersion:String;

	@:optional var gameOverChar:String;
	@:optional var gameOverSound:String;
	@:optional var gameOverLoop:String;
	@:optional var gameOverEnd:String;

	@:optional var disableNoteRGB:Bool;

	@:optional var arrowSkin:String;
	@:optional var splashSkin:String;
}

typedef SwagSection =
{
	var sectionNotes:Array<Dynamic>;
	var sectionBeats:Float;
	var mustHitSection:Bool;
	var focusCharacter:Int;
	@:optional var altAnim:Bool;
	@:optional var gfSection:Bool;
	@:optional var bpm:Float;
	@:optional var changeBPM:Bool;
}

enum abstract CharacterType(String) from String to String
{
	var OPPONENT = 'opponent';
	var PLAYER = 'player';
	var GIRLFRIEND = 'girlfriend';
}

typedef SwagCharacter =
{
	var name:String;
	var position:Array<Float>;
	var strumPosition:Array<Float>;
	var visible:Bool;
	var strumVisible:Bool;
	var noteVisible:Bool;
	var characterType:CharacterType;
	@:optional var index:Int;
}

class Song
{
	public var song:String;
	public var notes:Array<SwagSection>;
	public var events:Array<Dynamic>;
	public var bpm:Float;
	public var needsVoices:Bool = true;
	public var arrowSkin:String;
	public var splashSkin:String;
	public var gameOverChar:String;
	public var gameOverSound:String;
	public var gameOverLoop:String;
	public var gameOverEnd:String;
	public var disableNoteRGB:Bool = false;
	public var speed:Float = 1;
	public var stage:String;
	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';
	public var format:String = 'psychness_0.4.3';

	public static function convert(songJson:Dynamic, format:String = 'psychness') // Convert old charts to psychness format
	{
		switch (format)
		{
			case 'psych_v1':
				if (songJson.gfVersion == null)
				{
					songJson.gfVersion = songJson.player3;
					if (Reflect.hasField(songJson, 'player3'))
						Reflect.deleteField(songJson, 'player3');
				}

				if (songJson.events == null)
				{
					songJson.events = [];
					for (secNum in 0...songJson.notes.length)
					{
						var sec:SwagSection = songJson.notes[secNum];

						var i:Int = 0;
						var notes:Array<Dynamic> = sec.sectionNotes;
						var len:Int = notes.length;
						while (i < len)
						{
							var note:Array<Dynamic> = notes[i];
							if (note[1] < 0)
							{
								songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
								notes.remove(note);
								len = notes.length;
							}
							else
								i++;
						}
					}
				}

				var sectionsData:Array<SwagSection> = songJson.notes;
				if (sectionsData == null)
					return;

				for (section in sectionsData)
				{
					var beats:Null<Float> = cast section.sectionBeats;
					if (beats == null || Math.isNaN(beats))
					{
						section.sectionBeats = 4;
						if (Reflect.hasField(section, 'lengthInSteps'))
							Reflect.deleteField(section, 'lengthInSteps');
					}

					for (note in section.sectionNotes)
					{
						var gottaHitNote:Bool = (note[1] < 4) ? section.mustHitSection : !section.mustHitSection;
						note[1] = (note[1] % 4) + (gottaHitNote ? 0 : 4);

						if (!Std.isOfType(note[3], String))
							note[3] = Note.defaultNoteTypes[note[3]]; // compatibility with Week 7 and 0.1-0.3 psych charts
					}
				}
			case 'psychness':
				if (songJson.characters == null)
				{
					songJson.characters = [];
					songJson.characters.push({
						name: songJson.player1,
						position: [0, 0],
						strumPosition: [0, 0],
						visible: true,
						strumVisible: true,
						noteVisible: true,
						characterType: 'player',
						index: 1
					});
					songJson.characters.push({
						name: songJson.player2,
						position: [0, 0],
						strumPosition: [0, 0],
						visible: true,
						strumVisible: true,
						noteVisible: true,
						characterType: 'opponent',
						index: 1
					});
					songJson.characters.push({
						name: songJson.gfVersion == null || songJson.gfVersion.length < 1 ? 'gf' : songJson.gfVersion,
						position: [0, 0],
						strumPosition: [0, 0],
						visible: true,
						strumVisible: false,
						noteVisible: false,
						characterType: 'girlfriend',
						index: 1
					});

					if (Reflect.hasField(songJson, 'player1'))
						Reflect.deleteField(songJson, 'player1');
					if (Reflect.hasField(songJson, 'player2'))
						Reflect.deleteField(songJson, 'player2');
					if (Reflect.hasField(songJson, 'gfVersion'))
						Reflect.deleteField(songJson, 'gfVersion');
				}

				var sectionData:Array<SwagSection> = songJson.notes;
				if (songJson.notes != null)
				{
					for (section in sectionData)
					{
						if (section.mustHitSection)
							section.focusCharacter = 0;
						else
							section.focusCharacter = 1;
						if (section.gfSection)
							section.focusCharacter = 2;

						if (songJson.format == 'unknown')
						{
							if (section.focusCharacter == 1)
								for (n in section.sectionNotes)
								{
									n[1] += 4;
									if (n[1] >= 8)
										n[1] -= 8;
								}
							if (section.focusCharacter == 2)
								for (n in section.sectionNotes)
								{
									if (n[1] <= 3)
										n[1] += 8;
								}
						}

						if (Reflect.hasField(section, 'mustHitSection'))
							Reflect.deleteField(section, 'mustHitSection');
						if (Reflect.hasField(section, 'gfSection'))
							Reflect.deleteField(section, 'gfSection');
					}
				}
		}
	}

	public static var chartPath:String;
	public static var loadedSongName:String;

	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		if (folder == null)
			folder = jsonInput;
		PlayState.SONG = getChart(jsonInput, folder);
		loadedSongName = folder;
		chartPath = _lastPath.replace('/', '\\');
		StageData.loadDirectory(PlayState.SONG);
		return PlayState.SONG;
	}

	static var _lastPath:String;

	public static function getChart(jsonInput:String, ?folder:String):SwagSong
	{
		if (folder == null)
			folder = jsonInput;
		var rawData:String = null;

		var formattedFolder:String = Paths.formatToSongPath(folder);
		var formattedSong:String = Paths.formatToSongPath(jsonInput);
		_lastPath = Paths.json('$formattedFolder/$formattedSong');

		#if MODS_ALLOWED
		if (FileSystem.exists(_lastPath))
			rawData = File.getContent(_lastPath);
		#else
		if (Assets.exists(_lastPath))
			rawData = Assets.getText(_lastPath);
		#end

		return rawData != null ? parseJSON(rawData, jsonInput) : null;
	}

	public static function parseJSON(rawData:String, ?nameForError:String = null, ?convertTo:String = 'psychness'):SwagSong
	{
		var songJson:SwagSong = cast Json.parse(rawData);
		if (Reflect.hasField(songJson, 'song'))
		{
			var subSong:SwagSong = Reflect.field(songJson, 'song');
			if (subSong != null && Type.typeof(subSong) == TObject)
				songJson = subSong;
		}

		if (convertTo != null && convertTo.length > 0)
		{
			var fmt:String = songJson.format;
			if (fmt == null)
				fmt = songJson.format = 'unknown';

			switch (convertTo)
			{
				case 'psych_v1': // this gonna be unused i think
					if (!fmt.startsWith('psych_v1')) // Convert to Psych 1.0 format
					{
						trace('converting chart $nameForError with format $fmt to psych_v1 format...');
						songJson.format = 'psych_v1_convert';
						convert(songJson, convertTo);
					}
				case 'psychness':
					if (!fmt.startsWith('psychness')) // Convert to Psychness format
					{
						trace('converting chart $nameForError with format $fmt to psychness format...');
						convert(songJson, convertTo);
						songJson.format = 'psychness_convert';
					}
			}
		}
		return songJson;
	}
}
