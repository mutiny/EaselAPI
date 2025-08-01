extends ColorPicker

signal color_updated


onready var save_button = $"../../Button"
onready var panel = $"../../../../PanelContainer"

var selected_color := Color(1, 1, 1, 1)
var selected_r := 255
var selected_g := 255
var selected_b := 255
var selected_a := 255

func _ready() -> void:
	save_button.connect("pressed", self, "button_pressed")
	# enable the alpha slider
	edit_alpha = true
	hsv_mode = false
	# initialize to full-opacity white
	color = Color(1, 1, 1, 1)
	_on_color_changed(color)

	# react whenever the user picks a new color
	connect("color_changed", self, "_on_color_changed")

# internal handler: updates all state and emits our signal
func _on_color_changed(color: Color) -> void:
	selected_color = color
	selected_r = int(round(color.r * 255))
	selected_g = int(round(color.g * 255))
	selected_b = int(round(color.b * 255))
	selected_a = int(round(color.a * 255))
	emit_signal("color_updated", [selected_r, selected_g, selected_b, selected_a])

func button_pressed():
	emit_signal("color_updated", [selected_r, selected_g, selected_b, selected_a])

func set_selected_color(rgba, apply) -> void:
	if rgba:
		if rgba.size() >= 4:
			var c = Color8(rgba[0], rgba[1], rgba[2], rgba[3])
			color = c
			if apply:
				_on_color_changed(c)

#Mouse pos
func cursor_over():
	return panel.is_cursor_over()
