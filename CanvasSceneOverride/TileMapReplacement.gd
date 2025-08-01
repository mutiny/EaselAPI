extends Node2D

export var width := 200
export var height := 200
var parentid

var replaced = true

var image: Image
var texture: ImageTexture

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

var pending_pixels := []

onready var Mommy = get_tree().get_nodes_in_group("Mommy")[0] #Mommy??

func _ready() -> void:
	name = "TileMap"
	image = Image.new()
	image.create(width, height, false, Image.FORMAT_RGBA8)
	image.lock()
	image.fill(Color(0, 0, 0, 0))
	image.unlock()
	
	PlayerData.connect("_chalk_recieve", self, "set_pixel_array")
	OptionsMenu.connect("_options_update", self, "_options_update")
	Network.connect("_new_player_join", self, "update_joiner")
	
	texture = ImageTexture.new()
	texture.create_from_image(image)

	$CanvasSprite.texture = texture
	$CanvasSprite.position = Vector2.ZERO
	$CanvasSprite.scale = Vector2.ONE
	$CanvasSprite.position = Vector2(100, 100)
	set_process(true)


#if ur the lobby host gotta find out if they have the mod and send them the right stuff right?
func update_joiner(id):
	
	var steam_id = int(id)
	if Network.GAME_MASTER:
		if steam_id in Mommy.mod_user_id_array:
			#you get colors lol
			var pixel_data = export_pixel_data()
			
			Network._send_P2P_Packet(
				{"type": "chalk_packet", "data": pixel_data, "canvas_id": parentid},
				str(steam_id),
				2,
				Network.CHANNELS.CHALK
			)
			
		else:
			#you dont get colors lol
			var pixel_data = export_pixel_data()
			for i in range(pixel_data.size()):
				var cd = pixel_data[i][1]
				if typeof(cd) == TYPE_ARRAY:
					pixel_data[i][1] = _match_closest_ingame_color(cd)

			Network._send_P2P_Packet(
				{"type": "chalk_packet", "data": pixel_data, "canvas_id": parentid},
				str(steam_id),
				2,
				Network.CHANNELS.CHALK
			)
	elif steam_id in Mommy.mod_user_id_array:
		yield(get_tree().create_timer(3.0), "timeout")
		#well, make sure they get the updated colors... 
		var pixel_data = export_pixel_data()
		
		var rgba_data = []
		
		for entry in pixel_data:
			var cd = entry[1]
			if typeof(cd) == TYPE_ARRAY:
				rgba_data.append(entry)
				
		Network._send_P2P_Packet(
			{"type": "chalk_packet", "data": rgba_data, "canvas_id": parentid},
			str(steam_id),
			2,
			Network.CHANNELS.CHALK
		)
		
# Sets a single pixel by color ID or raw RGBA
# x, y: coordinates (int), color_data: int or Array [r,g,b,a]
func set_cell(x: int, y: int, color_data) -> void:
	pending_pixels.append([Vector2(x, y), color_data])

# Queues a batch by detecting type from first entry
# pixels: Array of [Vector2, int] or [Vector2, [r, g, b, a]]
func set_pixel_array(pixels, id = get_parent().get_parent().canvas_id) -> void:
	if id != get_parent().get_parent().canvas_id or pixels.empty():
		return
	if pending_pixels.empty():
		pending_pixels = pixels
	else:
		for entry in pixels:
			pending_pixels.append(entry)

func _process(delta: float) -> void:
	if pending_pixels.empty():
		return
	_draw_pending()

# Draws all queued pixels
func _draw_pending() -> void:
	image.lock()
	for entry in pending_pixels:
		var pos = entry[0]
		var cd  = entry[1]
		if not _in_bounds(pos.x, pos.y):
			continue
		if cd is int:
			image.set_pixel(pos.x, pos.y, color_map.get(cd, Color(0, 0, 0, 1)))
		elif cd is Array and cd.size() >= 4:
			image.set_pixel(pos.x, pos.y, Color8(cd[0], cd[1], cd[2], cd[3]))
	image.unlock()
	texture.set_data(image)
	pending_pixels.clear()
	
# Checks if (x, y) is inside the canvas bounds
func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height

# Clears the entire canvas to transparent
func clear() -> void:
	image.lock()
	image.fill(Color(0, 0, 0, 0))
	image.unlock()
	texture.set_data(image)

# Returns pixel data at a given position
# pos: Vector2 -> returns int color_id or [r, g, b, a]
func get_pixel_data(pos: Vector2):
	var x = int(pos.x)
	var y = int(pos.y)
	if not _in_bounds(x, y):
		return null
	image.lock()   
	var c = image.get_pixel(x, y)
	image.unlock()       
	for id in color_map.keys():
		var cm = color_map[id]
		if Color8(int(round(c.r*255)), int(round(c.g*255)), int(round(c.b*255)), int(round(c.a*255))) == cm:
			return id
	return [int(round(c.r*255)), int(round(c.g*255)), int(round(c.b*255)), int(round(c.a*255))]


# Emulates TileMap.get_used_cells()
func get_used_cells() -> Array:
	var cells := []
	image.lock() 
	for x in range(width):
		for y in range(height):
			var c = image.get_pixel(x, y)
			if c.a != 0:
				cells.append(Vector2(x, y))
	image.unlock() 
	return cells

# Emulates TileMap.get_cell(x,y)
func get_cell(x: int, y: int) -> int:
	if not _in_bounds(x, y):
		return -1
	var pd = get_pixel_data(Vector2(x, y))
	if typeof(pd) == TYPE_INT:
		return pd
	return -1

# Returns true if the cell at pos is non-transparent
func is_cell_used(pos: Vector2) -> bool:
	var x = int(pos.x)
	var y = int(pos.y)
	if not _in_bounds(x, y):
		return false
	image.lock()
	var c = image.get_pixel(x, y)
	image.unlock()
	return c.a != 0
	
	
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
	
# Exports all non-transparent pixel data
# returns Array of [Vector2, int or [r,g,b,a]]
func export_pixel_data() -> Array:
	var data := []
	image.lock()
	for x in range(width):
		for y in range(height):
			var c = image.get_pixel(x, y)
			if c.a == 0:
				continue
			var pos = Vector2(x, y)
			var found = false
			for id in color_map.keys():
				var cm = color_map[id]
				if Color8(int(round(c.r*255)), int(round(c.g*255)), int(round(c.b*255)), int(round(c.a*255))) == cm:
					data.append([pos, id])
					found = true
					break
			if not found:
				data.append([pos, [int(round(c.r*255)), int(round(c.g*255)), int(round(c.b*255)), int(round(c.a*255))]])
	image.unlock()
	return data
	
func _options_update():
	visible = not OptionsMenu.chalk_disabled

func get_rgba_at(pos):
	var x = pos.x
	var y = pos.y
	if not _in_bounds(x, y):
		return false
	image.lock()   
	var c: Color = image.get_pixel(x, y)
	image.unlock()   
	if c.a == 0:
		return false
	return [
		int(round(c.r * 255)),
		int(round(c.g * 255)),
		int(round(c.b * 255)),
		int(round(c.a * 255))
	]


#add screen entered or exited
