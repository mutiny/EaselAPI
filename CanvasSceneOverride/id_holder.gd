extends Spatial

onready var notifier = $VisibilityNotifier

var canvas_size
var canvas_id

var aabb_padding : float = 15.0

func _ready():
	var mesh_aabb = $MeshInstance.get_aabb()    
	var pad = Vector3(aabb_padding, aabb_padding, aabb_padding)
	var big_aabb = AABB(
		mesh_aabb.position - pad,
		mesh_aabb.size + pad * 2
	)
	notifier.aabb = big_aabb

	notifier.connect("screen_entered", self, "_on_screen_entered")
	notifier.connect("screen_exited",  self, "_on_screen_exited")


func _on_screen_entered():
	visible = true

func _on_screen_exited():
	visible = false
