extends Node

onready var _PlayerData = get_node_or_null("/root/PlayerData")
onready var Mommy = get_tree().get_nodes_in_group("Mommy")[0]

var Players
var KeybindAPI
var player_node = null
var paint_node = null
const ColorPickerScene  = preload("res://mods/PurplePuppy-Testing/ColorPicker/TempColorPicker.tscn")
var _picker: CanvasLayer = null

# Relevant Chalk Canvas node variables
var chalk_canvas_node_array = null
var chalk_canvas_node = null
var GridMap_node = null
var TileMap_node = null


# Data relevant Chalk Canvas variables
	
var last_grid_id = null
var current_zone = "main_zone"
var mouse_pos = null
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

	Players = get_node_or_null("/root/ToesSocks/Players")
	Players.connect("player_added", self, "_on_player_join")
	
	Mommy.connect("_cycle_pattern", self, "_cycle_pattern")
	
	
	_picker = ColorPickerScene.instance()
	add_child(_picker)
	var color_picker = _picker.get_node("PanelContainer/VBoxContainer/Control/ColorPicker")
	color_picker.connect("color_updated", self, "_on_picker_color_updated")

#color picker stuff


func show_color_picker() -> void:
	if not _picker:
		_picker = ColorPickerScene.instance()
		add_child(_picker)
		var color_picker = _picker.get_node("PanelContainer/VBoxContainer/Control/ColorPicker")
		color_picker.connect("color_updated", self, "_on_picker_color_updated")
		
	if _picker:
		var panel = _picker.get_node("PanelContainer")
		_picker.show()
		panel.show()

func hide_color_picker() -> void:
	if _picker:
		var panel = _picker.get_node("PanelContainer")
		panel.hide()

func _on_picker_color_updated(rgba: Array) -> void:
	chalk_color_override = rgba
	
func _replicate_canvas_RGBA_data(playernode):
	var steam_id = int(playernode.owner_id)
	if steam_id in Mommy.mod_user_id_array && chalk_canvas_node_array:
		
		for node in chalk_canvas_node_array:
			
			var tilemapnode = node.get_node("Viewport/TileMap")
			var pixel_data = tilemapnode.export_pixel_data()
			
			var PACKET_DATA: PoolByteArray = []
			PACKET_DATA.append_array(var2bytes(pixel_data).compress(File.COMPRESSION_GZIP))
			
			Network._send_p2p_message(steam_id, PACKET_DATA, 2, Network.CHANNELS.CHALK)


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
	
func test_network():
	Mommy._refresh_all_members()
	
func _cycle_pattern():
	
	if !(player_node and player_node.busy) && alt_state:  #debugger for network stuff
		test_network()
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
	
	#if chalk_dither_pattern == "default": 
		#_allow_manual_drawing(true)
	#else:
		#_allow_manual_drawing(false)
				
	_allow_manual_drawing(false)
	
	_communicate_pattern_change()
			
			
func _communicate_pattern_change(reset_override = false): #let em know what they are using so no flying blind. only temporary until ui is made
	var sparce_check = ""
	if chalk_dither_low_frequency: sparce_check = "sparce "
	
	if chalk_color_override && reset_override:
		old_chalk_color_override = chalk_color_override
		chalk_color_override = false
		PlayerData._send_notification("Using " + chalk_dither_pattern + ", RGB color reset!", 0)
	else:
		PlayerData._send_notification("Using " + sparce_check + chalk_dither_pattern + " pattern!", 0)
			
			
func _process(delta):
	
	if not player_node: #is this practical and efficient? lol
		player_node = get_tree().current_scene.get_node_or_null("Viewport/main/entities/player")
		if not player_node: 
			return
		elif not paint_node:
			paint_node = player_node.get_node("paint_node")
			if not paint_node: 
				return
					
	
	if not Players.is_player_valid(player_node):  #here only until i make this node a child of a load manager
		chalk_dither_pattern = "default"
		chalk_dither_low_frequency = false
		player_node = null
		holding_chalk = false 
		chalk_item_name = null
		chalk_color = null
		chalk_canvas_node_array = null
		chalk_canvas_node = null
		GridMap_node = null
		TileMap_node = null
		last_grid_id = null
		allow_manual_drawing = true
		_using_world_canvas = true
		paint_node = null
		player_node = null
		last_grid_pos = null
		return

	var chalk_Name_ID_match = null
	var match_found = false
	
	mouse_pos = paint_node.global_transform.origin
	
	if alt_state and holding_chalk:
		if not _picker or not _picker.get_node("PanelContainer").is_visible():
			show_color_picker()
	else:
		hide_color_picker()
		
	#Sets chalk values without unnecessary reentry (sorry if it looks needlessly complex)
	for chalk_Name_ID in chalk_Name_ID_array:
		if player_node.held_item["id"] == chalk_Name_ID[0]:
			chalk_Name_ID_match = [chalk_Name_ID[0], chalk_Name_ID[1]]
			match_found = true
			break
			
	if match_found:			
		if not holding_chalk:
			chalk_dither_pattern = "default"
		holding_chalk = true
		var old_chalk_name = chalk_item_name
		chalk_item_name = chalk_Name_ID_match[0]
		chalk_color = chalk_Name_ID_match[1]
		if old_chalk_name != null && old_chalk_name != chalk_item_name && (!chalk_dither_pattern == "default"): #send reminder (in case they forget dithering is on)
			_communicate_pattern_change(true)
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
		_allow_manual_drawing(true)
		chalk_dither_low_frequency = false
		allow_manual_drawing = true
		_using_world_canvas = true
		chalk_color_override = false
		
			
	if holding_chalk:
		var grid_id = get_grid(mouse_pos)
		if grid_id == -1: return
			
		if grid_id != last_grid_id:
			
			last_grid_id = grid_id
			_assign_game_canvas_nodes(last_grid_id)
			if not chalk_canvas_node:
				return
			
			#if chalk_dither_pattern == "default": return
			#_allow_manual_drawing(false)
			
		#if chalk_dither_pattern == "default": return
		_paint_process()


func _allow_manual_drawing(on): #make sure canvases dont get locked out of being drawn on before switching
	allow_manual_drawing = on
	if chalk_canvas_node_array:
		for node in chalk_canvas_node_array:
			if node: node.chalkOn = on
		#print("allow manual draw: " + str(on)) #debugging


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

#updates node assignments
func _assign_game_canvas_nodes(grid_id):
	chalk_canvas_node = null
	
	if not chalk_canvas_node_array:
		chalk_canvas_node_array = 	[
			get_tree().current_scene.get_node_or_null("Viewport/main/map/main_map/zones/main_zone/chalk_zones/chalk_canvas"),
			get_tree().current_scene.get_node_or_null("Viewport/main/map/main_map/zones/main_zone/chalk_zones/chalk_canvas2"),
			get_tree().current_scene.get_node_or_null("Viewport/main/map/main_map/zones/main_zone/chalk_zones/chalk_canvas3"),
			get_tree().current_scene.get_node_or_null("Viewport/main/map/main_map/zones/main_zone/chalk_zones/chalk_canvas4")
		]

	if chalk_canvas_node_array[grid_id]:
		chalk_canvas_node = chalk_canvas_node_array[grid_id]
		TileMap_node = chalk_canvas_node.get_node("Viewport/TileMap")
		#GridMap_node = chalk_canvas_node.get_node("GridMap") #unsure if i need this
	else:
		chalk_canvas_node_array = null
		#print("Failed to retrieve chalknodes") #debugging
		return false
		
	return true


func _paint_process(): # start point for all tilemap changes
	_allow_manual_drawing(false)
	if not m1_state:
		last_grid_pos = null
		return

	var size = 2
	if shift_state:
		size = 4
	elif control_state:
		size = 1
		
	mouse_pos = paint_node.global_transform.origin
	
	var grid_diff = chalk_canvas_node.global_transform.origin - mouse_pos
	if grid_diff.length() > chalk_canvas_node.canvas_size:
		return
		
	var x = int(floor(100 - grid_diff.x * 10))
	var z = int(floor(100 - grid_diff.z * 10)) # replaced y with z
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
			TileMap_node.set_cell(posX, posY, colorTile)
		else:
			var colorTile = pixelData[2]
			var vanillaTile = _match_closest_ingame_color(pixelData[2])
			colorCanvasData.append([Vector2(posX, posY), colorTile])
			vanillaCanvasData.append([Vector2(posX, posY), vanillaTile])
			TileMap_node.set_cell(posX, posY, colorTile)
	
	
	if colorCanvasData.empty(): #No special colors
		_send_canvas_update_packet(vanillaCanvasData, canvasActorID)
	else:
		_send_selective_canvas_update_packet(colorCanvasData, vanillaCanvasData, canvasActorID) #YEAHHH BABY
	

func _send_selective_canvas_update_packet(colorCanvasData, vanillaCanvasData, canvasActorID):
	
	var playerNodeArray = Players.get_players(false)
	
	for player in playerNodeArray:
		var steam_id = int(player.owner_id)

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
