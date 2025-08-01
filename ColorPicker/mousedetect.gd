extends PanelContainer

var left_offset := 10

func _ready():
	anchor_left   = 1.0
	anchor_right  = 1.0
	anchor_top    = 0.5
	anchor_bottom = 0.5
	var w = rect_min_size.x
	var h = rect_min_size.y
	margin_left   = -w - left_offset
	margin_right  =  0
	margin_top    = -h * 0.5
	margin_bottom =  h * 0.5

func is_cursor_over() -> bool:
	var local_pos = get_local_mouse_position()
	return Rect2(Vector2.ZERO, rect_size).has_point(local_pos)
