extends Node2D

export var width := 200
export var height := 200

var replaced = true

var image: Image
var texture: ImageTexture
var parentid = 0

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

var pending_vanilla_arrays := []
var pending_rgb_arrays := []				 

onready var Mommy = get_tree().get_nodes_in_group("Mommy")[0] #Mommy??

func _ready() -> void:
	name = "TileMap"
	image = Image.new()
	image.create(width, height, false, Image.FORMAT_RGBA8)
	image.lock()
	image.fill(Color(0, 0, 0, 0))
	image.unlock()

	texture = ImageTexture.new()
	texture.create_from_image(image)

	$CanvasSprite.texture = texture
	$CanvasSprite.position = Vector2.ZERO
	$CanvasSprite.scale = Vector2.ONE
	$CanvasSprite.position = Vector2(100, 100)
	set_process(true)

#if ur the lobby host gotta find out if they have the mod and send them the right stuff right?
func update_joiner(id):
	if not Network.GAME_MASTER: return
	
	var steam_id = int(id)
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

# Sets a single pixel by color ID or raw RGBA
# x, y: coordinates (int), color_data: int or Array [r,g,b,a]
func set_cell(x: int, y: int, color_data) -> void:
	
	if not _in_bounds(x, y):
		return
	var color: Color
	if color_data is int:
		color = color_map.get(color_data, Color(0, 0, 0, 1))
	elif color_data is Array and color_data.size() >= 4:
		color = Color8(color_data[0], color_data[1], color_data[2], color_data[3])
	else:
		return
	image.lock()
	image.set_pixel(x, y, color)
	image.unlock()
	texture.set_data(image)

# Queues a batch by detecting type from first entry
# pixels: Array of [Vector2, int] or [Vector2, [r, g, b, a]]
func set_array(pixels: Array) -> void:
	if pixels.empty():
		return
	var first = pixels[0]
	if first.size() != 2:
		return
	var cd = first[1]
	if cd is int:
		pending_vanilla_arrays.append(pixels)
	elif cd is Array:
		pending_rgb_arrays.append(pixels)

func _process(delta: float) -> void:
	if pending_vanilla_arrays.empty() and pending_rgb_arrays.empty():
		return
	_draw_pending()

# Draws all queued pixel batches in one go
func _draw_pending() -> void:
	image.lock()
	for pixels in pending_vanilla_arrays:
		for p in pixels:
			var pos = p[0]
			var id = p[1]
			if _in_bounds(pos.x, pos.y):
				image.set_pixel(pos.x, pos.y, color_map.get(id, Color(0, 0, 0, 1)))
	for pixels in pending_rgb_arrays:
		for p in pixels:
			var pos = p[0]
			var arr = p[1]
			image.set_pixel(pos.x-1, pos.y, Color8(arr[0], arr[1], arr[2], arr[3]))
	image.unlock()
	texture.set_data(image)
	pending_vanilla_arrays.clear()
	pending_rgb_arrays.clear()

# Checks if (x, y) is inside the canvas bounds
func _in_bounds(x: int, y: int) -> bool:
	return true
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
	var c = image.get_pixel(x, y)
	for id in color_map.keys():
		var cm = color_map[id]
		if Color8(int(round(c.r*255)), int(round(c.g*255)), int(round(c.b*255)), int(round(c.a*255))) == cm:
			return id
	return [int(round(c.r*255)), int(round(c.g*255)), int(round(c.b*255)), int(round(c.a*255))]


# Emulates TileMap.get_used_cells()
func get_used_cells() -> Array:
	var cells := []
	for x in range(width):
		for y in range(height):
			var c = image.get_pixel(x, y)
			if c.a != 0:
				cells.append(Vector2(x, y))
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
	var c = image.get_pixel(x, y)
	return c.a != 0
	
	
#matching rgba values to in game colors
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
