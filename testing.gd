extends Node

onready var _PlayerData = get_node_or_null("/root/PlayerData")
onready var Mommy = get_tree().get_nodes_in_group("Mommy")[0]

var KeybindAPI
var color_picker
var player_node
var paint_node

const ColorPickerScene  = preload("res://mods/PurplePuppy.Testing/ColorPicker/TempColorPicker.tscn")
var _picker: CanvasLayer = null
var color_picking = false
var color_selected = false
var used_array = []

# Relevant Chalk Canvas node variables
var chalk_canvas_node_array = null
var chalk_canvas_node = null
var GridMap_node = null
var TileMap_node = null


# Data relevant Chalk Canvas variables
	
var last_grid_id = 0
var current_zone = "main_zone"
var last_grid_pos = null
var _using_world_canvas = true

#Chalk Item Variables
var chalk_Name_ID_array = [
	["chalk_eraser", -1],
	["chalk_white", 0],
	["chalk_black", 1],
	["chalk_red", 2],
	["chalk_blue", 3],
	["chalk_yellow", 4],
	["chalk_special", 5],
	["chalk_green", 6]
]

var color_map := {
	0: Color8(255, 238, 218, 255),
	1: Color8(5, 11, 21, 255),
	2: Color8(172, 0, 41, 255),
	3: Color8(0, 133, 131, 255),
	4: Color8(230, 157, 0, 255),
	5: Color8(255, 0, 255, 255),
	6: Color8(125, 162, 36, 255),
   -1: Color8(0, 0, 0, 0)
}

var holding_chalk = false
var chalk_item_name = null
var chalk_color = null
var chalk_color_override = false
var old_chalk_color_override = false
var chalk_dither_pattern = "default"
var chalk_dither_low_frequency = false
var allow_manual_drawing = true

#event info

var shift_state = false
var m1_state = false
var alt_state = false
var control_state                   

func _ready():
	Mommy.connect("_cycle_pattern", self, "_cycle_pattern")
	Mommy.connect("_color_pick", self, "show_color_picker")
	Mommy.connect("_color_pick_up", self, "hide_color_picker")
	
	_picker = ColorPickerScene.instance()
	add_child(_picker)
	
	color_picker = _picker.get_node("PanelContainer/VBoxContainer/Control/ColorPicker")
	
	color_picker.connect("color_updated", self, "_on_picker_color_updated")
	
	add_to_group("Daddy")
	
	while not get_tree().current_scene.get_node_or_null("Viewport/main/entities/player"):
		yield(get_tree(), "idle_frame")
		
	player_node = get_tree().current_scene.get_node_or_null("Viewport/main/entities/player")
	paint_node = player_node.get_node("paint_node")
	_refresh_all_members()


func _refresh_all_members() -> void:
	
	yield(get_tree().create_timer(3.0), "timeout")
	
	var cnt = Steam.getNumLobbyMembers(Mommy.lobby_id)
	
	var owners := []
	for i in range(cnt):
		var m = Steam.getLobbyMemberByIndex(Mommy.lobby_id, i)
		var v = Steam.getLobbyMemberData(Mommy.lobby_id, m, Mommy.MOD_KEY)
		
		if m == Steam.getSteamID():
			continue
		
		var owner = false
		if v == Mommy.MOD_VAL:
			owner = true
			owners.append(Steam.getFriendPersonaName(m))
	
	
	yield(get_tree().create_timer(3.0), "timeout")
	if owners.size() > 0:
		var msg := ""
		for i in range(owners.size()):
			if i > 0:
				msg += ", "
			msg += owners[i]
		msg += " using EASEL :3"
		PlayerData._send_notification(msg, 1)

	if alt_state and holding_chalk:
		if not _picker or not _picker.get_node("PanelContainer").is_visible():
			show_color_picker()
	else:
		hide_color_picker()

func show_color_picker() -> void:
	if _picker && holding_chalk:
		color_picking = true
		var panel = _picker.get_node("PanelContainer")
		_picker.show()
		panel.show()

func hide_color_picker() -> void:
	color_picking = false
	color_selected = false
	used_array.clear()
	if _picker:
		var panel = _picker.get_node("PanelContainer")
		panel.hide()

func _on_picker_color_updated(rgba: Array) -> void:
	chalk_color_override = rgba
	color_selected = true
	

func _input(event):
	if event is InputEventKey: 
		if event.scancode == KEY_SHIFT:
			shift_state = event.pressed
		if event.scancode == KEY_CONTROL:
			control_state = event.pressed
		if event.scancode == KEY_ALT:
			alt_state = event.pressed

	elif event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			m1_state = event.pressed
			if not event.pressed:
				last_grid_pos = null

func _cycle_pattern():
	var vanillaCanvasData = []
	if !(player_node and player_node.busy) && alt_state:
		_refresh_all_members()
		return
		
		
	if (player_node and player_node.busy) or !holding_chalk: return

		
	match chalk_dither_pattern:
		"default":
			chalk_dither_pattern = "grid"
		"grid":
			chalk_dither_pattern = "checkerboard"
		"checkerboard":
			chalk_dither_pattern = "default"
		_:
			chalk_dither_pattern = "default"
			
	chalk_dither_low_frequency = false
	
	_communicate_pattern_change()
			
			
func _communicate_pattern_change(reset_override = false): #let em know what they are using so no flying blind. only temporary until ui is made
	var sparce_check = ""
	if chalk_dither_low_frequency: sparce_check = "sparce "
	
	if !(old_chalk_color_override == chalk_color_override):
		if chalk_dither_pattern == "default":
			PlayerData._send_notification("RGB color reset!", 0)
			
		else:
			PlayerData._send_notification("Using " + chalk_dither_pattern + ", RGB color reset!", 0)
	else:
		PlayerData._send_notification("Using " + sparce_check + chalk_dither_pattern + " pattern!", 0)
	
	old_chalk_color_override = null
	chalk_color_override = null


func get_chalk_color_by_name(name: String):
	for pair in chalk_Name_ID_array:
		if pair[0] == name:
			var id = pair[1]
			var col = color_map.get(id, Color8(0, 0, 0, 0))
			return [col.r8, col.g8, col.b8, col.a8]
	return [0, 0, 0, 255]
	
			
func _process(delta):
	if !is_instance_valid(player_node):
		Mommy.remove_children()
		set_process(false)  
		queue_free()
		return			

	var chalk_Name_ID_match = null
	var match_found = false
	
		
	#Sets chalk values without unnecessary reentry (sorry if it looks needlessly complex)
	for chalk_Name_ID in chalk_Name_ID_array:
		if player_node.held_item["id"] == chalk_Name_ID[0]:
			chalk_Name_ID_match = [chalk_Name_ID[0], chalk_Name_ID[1]]
			match_found = true
			break
			
	if match_found:			
		if not holding_chalk:
			chalk_dither_pattern = "default"
			color_picker.set_selected_color(get_chalk_color_by_name(chalk_Name_ID_match[0]), true)
			old_chalk_color_override = get_chalk_color_by_name(chalk_Name_ID_match[0])
		holding_chalk = true
		var old_chalk_name = chalk_item_name
		chalk_item_name = chalk_Name_ID_match[0]
		chalk_color = chalk_Name_ID_match[1]
		if old_chalk_name != null && old_chalk_name != chalk_item_name: #send reminder (in case they forget dithering is on)
			_communicate_pattern_change(true)
			color_picker.set_selected_color(get_chalk_color_by_name(chalk_item_name), true)
			old_chalk_color_override = get_chalk_color_by_name(chalk_item_name)
	elif holding_chalk: #reset relevant canvas and chalk variables once when no longer holding any chalk item
		holding_chalk = false 
		chalk_item_name = null
		chalk_color = null
		chalk_canvas_node = null
		GridMap_node = null
		TileMap_node = null
		last_grid_id = null
		last_grid_pos = null		
		chalk_dither_pattern == "default"
		chalk_dither_low_frequency = false
		allow_manual_drawing = true
		_using_world_canvas = true
		chalk_color_override = false
		
	
	if color_picking:
		_pick_process()
		return
	
	if holding_chalk:
		var grid_id = get_grid(paint_node.global_transform.origin)
		if grid_id == -1: return
			
		if grid_id != last_grid_id:
			
			last_grid_id = grid_id
		_paint_process()

#Function that gets mouse position and finds associated canvas actor
func get_grid(mouse_pos):
	var grid = null
	if current_zone == "main_zone" && mouse_pos:
		if (mouse_pos.x > 48.571999 - 10 and mouse_pos.x < 48.571999 + 10) and (mouse_pos.z > - 51.041 - 10 and mouse_pos.z < - 51.041 + 10):
			grid = 0
		elif (mouse_pos.x > 69.57199900000001 - 10 and mouse_pos.x < 69.57199900000001 + 10) and (mouse_pos.z > - 54.952999 - 10 and mouse_pos.z < - 54.952999 + 10):
			grid = 1
		elif (mouse_pos.x > - 54.7896 - 10 and mouse_pos.x < - 54.7896 + 10) and (mouse_pos.z > - 115.719002 - 10 and mouse_pos.z < - 115.719002 + 10):
			grid = 2
		elif (mouse_pos.x > - 25.781099 - 10 and mouse_pos.x < - 25.781099 + 10) and (mouse_pos.z > - 34.5681 - 10 and mouse_pos.z < - 34.5681 + 10):
			grid = 3
		else:
			return -1
		return grid


#for selecting colors
func _pick_process():
	if color_picker.cursor_over():
		return
		
	if m1_state:
		var grid_diff = Mommy.replacement_tilemap_nodes[last_grid_id].get_parent().get_parent().global_transform.origin - paint_node.global_transform.origin
		if grid_diff.length() > Mommy.replacement_tilemap_nodes[last_grid_id].get_parent().get_parent().canvas_size:
			color_picker.set_selected_color(chalk_color_override, false)
			return
			
		var x = int(floor(100 - grid_diff.x * 10))
		var z = int(floor(100 - grid_diff.z * 10))
		var new_grid_pos = Vector2(x, z)
		color_picker.set_selected_color(Mommy.replacement_tilemap_nodes[last_grid_id].get_rgba_at(new_grid_pos), true)
		
func _paint_process(): # start point for all tilemap changes

	if not m1_state:
		last_grid_pos = null
		return

	var size = 2
	if shift_state:
		size = 4
	elif control_state:
		size = 1
		
	var grid_diff = Mommy.replacement_tilemap_nodes[last_grid_id].get_parent().get_parent().global_transform.origin - paint_node.global_transform.origin
	if grid_diff.length() > Mommy.replacement_tilemap_nodes[last_grid_id].get_parent().get_parent().canvas_size:
		return
		
	var x = int(floor(100 - grid_diff.x * 10))
	var z = int(floor(100 - grid_diff.z * 10))
	var new_grid_pos = Vector2(x, z)
		
	var data := []
	
	#testing color match
	if chalk_color_override:
		chalk_color = chalk_color_override
	
	if last_grid_pos:
		# Fill gap between last and new
		var dist = last_grid_pos.distance_to(new_grid_pos)
		var steps = 1 + int(floor(dist / size))
		for s in range(steps):
			var dir = (last_grid_pos - new_grid_pos).normalized()
			var interp = new_grid_pos + dir * (s * size)
			var ix = int(interp.x)
			var iz = int(interp.y) # y component now used as z index

			for dx in range(size):
				for dz in range(size): # swapped dy for dz
					data.append([ix + dx, iz + dz, chalk_color])
	else:
		for dx in range(size):
			for dz in range(size): # swapped dy for dz
				data.append([x + dx, z + dz, chalk_color])

	#apply dithering pattern
	
	if chalk_dither_pattern == "grid":
		data = _apply_grid_pattern(data)
	elif chalk_dither_pattern == "checkerboard":
		data = _apply_checkerboard_pattern(data)

	_update_canvas_node(data, last_grid_id)

	last_grid_pos = new_grid_pos
	

# Returns a checkerboard pattern by keeping only alternating cells
func _apply_checkerboard_pattern(array):
	var result := []
	for entry in array:
		var x = entry[0]
		var z = entry[1]
		if (x + z) % 2 == 0:
			result.append(entry)
	return result


func _apply_grid_pattern(array):
	var result := []
	for entry in array:
		var x = entry[0]
		var z = entry[1]
		if x % 2 == 0 or z % 2 == 0:
			continue
		result.append(entry)
	return result


#matching rgba values to in game colors
func _match_closest_ingame_color(rgba: Array) -> int:
	if rgba.size() < 3:
		return -1
	var r = rgba[0]
	var g = rgba[1]
	var b = rgba[2]
	var best_id = -1
	var best_dist = INF
	for id in color_map.keys():
		if id == 5:
			continue
		var col = color_map[id]
		var dr = col.r8 - r
		var dg = col.g8 - g
		var db = col.b8 - b
		var dist = dr * dr + dg * dg + db * db
		if dist < best_dist:
			best_dist = dist
			best_id = id
	return best_id


func _update_canvas_node(data, canvasActorID): # data is expected to be an array of [ [x, y, colorTile/rgbaarray], [x, y, colorTile/rgbaarray], ... ]
	var colorCanvasData = []
	var vanillaCanvasData = []

	for pixelData in data:
		var posX = pixelData[0]
		var posY = pixelData[1]
		if typeof(pixelData[2]) == TYPE_INT:
			var colorTile = pixelData[2]
			vanillaCanvasData.append([Vector2(posX, posY), colorTile])
		else:
			var colorTile = pixelData[2]
			var vanillaTile = _match_closest_ingame_color(pixelData[2])
			colorCanvasData.append([Vector2(posX, posY), colorTile])
			vanillaCanvasData.append([Vector2(posX, posY), vanillaTile])
		
	if colorCanvasData:
		Mommy.replacement_tilemap_nodes[canvasActorID].set_pixel_array(colorCanvasData, canvasActorID)
	else:
		Mommy.replacement_tilemap_nodes[canvasActorID].set_pixel_array(vanillaCanvasData, canvasActorID)
	
	
	if colorCanvasData.empty(): #No special colors
		_send_canvas_update_packet(vanillaCanvasData, canvasActorID)
	else:
		_send_selective_canvas_update_packet(colorCanvasData, vanillaCanvasData, canvasActorID) #YEAHHH BABY
	

func _send_selective_canvas_update_packet(colorCanvasData, vanillaCanvasData, canvasActorID):
	
	var cnt = Steam.getNumLobbyMembers(Mommy.lobby_id)
	var owners := []
	for i in range(cnt):
		var steam_id = int(Steam.getLobbyMemberByIndex(Mommy.lobby_id, i))

		if steam_id in Mommy.mod_user_id_array:
			Network._send_P2P_Packet(
				{"type": "chalk_packet", "data": colorCanvasData, "canvas_id": canvasActorID},
				str(steam_id),
				2,
				Network.CHANNELS.CHALK
			)
		else:
			Network._send_P2P_Packet(
				{"type": "chalk_packet", "data": vanillaCanvasData, "canvas_id": canvasActorID},
				str(steam_id),
				2,
				Network.CHANNELS.CHALK
			)


func _send_canvas_update_packet(canvasData, canvasActorID):
	Network._send_P2P_Packet(
		{"type": "chalk_packet", "data": canvasData, "canvas_id": canvasActorID},
		"peers",
		2,
		Network.CHANNELS.CHALK
	)
