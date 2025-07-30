extends Node

var Players
var KeybindsAPI
onready var _Spawn = preload("res://mods/PurplePuppy-Testing/testing.gd").new()

var editor = false
var config_data = {}

signal _cycle_pattern

var prefix = "[PurplePuppy-Testing]"

var default_config_data = {
	"_cycle": 89
}

#SCARY NETWORK STUFF (THANKS CHATGBT AND GODOT AND TIME I WASTED)
# advertise that we have rgb compatibility
var lobby_id: int = 0
var local_steam_id: int
const MOD_KEY = "has_easel"
const MOD_VAL = "loveisrealanditsinsideofmycomputer"
var mod_user_id_array: Array = []

func _ready():

	Players = get_node_or_null("/root/ToesSocks/Players")
	KeybindsAPI = get_node_or_null("/root/BlueberryWolfiAPIs/KeybindsAPI")
	KeybindsAPI.connect("_keybind_changed", self, "_on_keybind_changed")
	Players.connect("ingame", self, "_on_game_entered")
	Players.connect("player_added", self, "_on_player_join")
	add_to_group("Mommy")
	
	
	load_or_create_config()
	
	if KeybindsAPI:
		var _cycle = KeybindsAPI.register_keybind({
			"action_name": "_cycle", 
			"title": "Toggle Dither Pattern", 
			"key": config_data["_cycle"], 
		})
	
		KeybindsAPI.connect(_cycle, self, "_cycle_pattern")
		
		
#SCARY NETWORK STUFF (THANKS CHATGBT AND GODOT AND TIME I WASTED)

	local_steam_id = Steam.getSteamID()
	print("[HAS EASELAPI] local SteamID =", local_steam_id)

	Steam.connect("lobby_created",   self, "_on_lobby_created")
	Steam.connect("lobby_joined",    self, "_on_lobby_joined")
	Steam.connect("lobby_chat_update", self, "_on_lobby_chat_update")
	
	_refresh_all_members()
	
	print("[HAS EASELAPI] setup complete")

func _on_lobby_created(success: int, this_lobby_id: int) -> void:
	print("[HAS EASELAPI] _on_lobby_created:", success, this_lobby_id)
	if success == 1:
		lobby_id = this_lobby_id
		Steam.setLobbyMemberData(lobby_id, MOD_KEY, MOD_VAL)
		print("[HAS EASELAPI] setLobbyMemberData ->", MOD_KEY, MOD_VAL)
		_refresh_all_members()
	else:
		push_error("[HAS EASELAPI] failed to create lobby")

func _on_lobby_joined(this_lobby_id: int, _perm: int, _locked: bool, response: int) -> void:
	print("[HAS EASELAPI] _on_lobby_joined:", this_lobby_id, response)
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		lobby_id = this_lobby_id
		Steam.setLobbyMemberData(lobby_id, MOD_KEY, MOD_VAL)
		print("[HAS EASELAPI] setLobbyMemberData ->", MOD_KEY, MOD_VAL)
		_refresh_all_members()
	else:
		push_error("[HAS EASELAPI] failed to join lobby")

func _on_lobby_chat_update(lobby_id, change_id, member_id, chat_state):
	if chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_ENTERED:
		Steam.setLobbyMemberData(lobby_id, MOD_KEY, MOD_VAL)
		_refresh_all_members()

func _refresh_all_members() -> void:
	mod_user_id_array.clear()
	if lobby_id == 0:
		return
	var cnt = Steam.getNumLobbyMembers(lobby_id)
	print("[HAS EASELAPI] lobby has ", cnt, " members")
	
	var owners := []
	for i in range(cnt):
		var m = Steam.getLobbyMemberByIndex(lobby_id, i)
		var v = Steam.getLobbyMemberData(lobby_id, m, MOD_KEY)
		
		var owner = false
		if v == MOD_VAL:
			_add_user(m)
			owner = true
			owners.append(Steam.getFriendPersonaName(m))
		
		var name = Steam.getFriendPersonaName(m)
		print("[HAS EASELAPI]  member ", name, " HAS EASEL -> ", owner)
	
	print("[HAS EASELAPI] mod user array looks like:")
	print(mod_user_id_array)
	
	if owners.size() > 0:
		var msg := ""
		for i in range(owners.size()):
			if i > 0:
				msg += ", "
			msg += owners[i]
		msg += " using EASEL!"
		PlayerData._send_notification(msg, 1)

func _add_user(steam_id:int) -> void:
	if steam_id in mod_user_id_array:
		return
	mod_user_id_array.append(steam_id)
	var name = Steam.getFriendPersonaName(steam_id)
	print("[HAS EASELAPI]  → keeping track of mod user: ", name)

func _cycle_pattern():
	emit_signal("_cycle_pattern")

func _on_game_entered():
	print("entered game")
	if _Spawn and _Spawn.is_inside_tree():
		_Spawn.queue_free()
		_Spawn = null
		print("[EASELAPI] Removed Child")

	if _Spawn == null or not _Spawn.is_inside_tree():
		_Spawn = preload("res://mods/PurplePuppy-Testing/testing.gd").new()
		add_child(_Spawn)
		print("[EASELAPI] Spawned Child")


func _get_gdweave_dir()->String:
	if editor:
		return "D:/Trash/GDWeave"
	else:
		var game_directory: = OS.get_executable_path().get_base_dir()
		var folder_override: String
		var final_directory: String
		for argument in OS.get_cmdline_args():
			if argument.begins_with("--gdweave-folder-override="):
				folder_override = argument.trim_prefix("--gdweave-folder-override=").replace("\\", "/")
		if folder_override:
			var relative_path: = game_directory.plus_file(folder_override)
			var is_relative: = not ":" in relative_path and Directory.new().file_exists(relative_path)
			final_directory = relative_path if is_relative else folder_override
		else:
			final_directory = game_directory.plus_file("GDWeave")
		return final_directory

	
func _get_config_dir()->String:
	var gdweave_dir = _get_gdweave_dir()
	var config_path = gdweave_dir.plus_file("mods").plus_file("PurplePuppy-Testing")
	return config_path
	
func _get_config_file()->String:
	var gdweave_dir = _get_gdweave_dir()
	var config_path = gdweave_dir.plus_file("mods").plus_file("PurplePuppy-Testing").plus_file("Hotkeys")
	return config_path
	
func save_config():
	var path = _get_config_file()
	var file = File.new()
	if file.open(path, File.WRITE) == OK:
		file.store_string(JSON.print(config_data, "\t"))
		file.close()
	else:
		print("Failed to write config to " + path)

func load_or_create_config():
	var path = _get_config_file()
	if not _ensure_config_dir_exists():
		print("Could not create config directory")
		return

	var file = File.new()
	if file.file_exists(path) and file.open(path, File.READ) == OK:
		var json = JSON.parse(file.get_as_text())
		file.close()
		if json.error == OK and typeof(json.result) == TYPE_DICTIONARY:
			config_data = json.result
			return
	# fallback on any failure:
	config_data = default_config_data.duplicate()
	save_config()

func _ensure_config_dir_exists() -> bool:
	var dir = Directory.new()
	var cfg_dir = _get_config_dir()
	if not dir.dir_exists(cfg_dir):
		return dir.make_dir_recursive(cfg_dir) == OK
	return true


func _on_keybind_changed(action_name: String, title: String, input_event: InputEvent)->void :
	if action_name == "":
		return 
	
	
	if input_event is InputEventKey:
		var scancode = input_event.scancode
		print(prefix, "Action Name:", action_name, "Key Scancode:", scancode)
		
		
		if config_data.has(action_name):
			config_data[action_name] = scancode
			save_config()
		else:
			print(prefix, "Action name not found in config: ", action_name)
	else:
		print(prefix, "Input event is not a key event.")
