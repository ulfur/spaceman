extends ColorRect
## Cursor parallax is an instrument-camera effect; stars do not drift physically.
var drift := Vector2.ZERO
var shader_material := ShaderMaterial.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shader_material.shader = preload("res://shaders/deep_space.gdshader")
	material = shader_material
	resized.connect(update_aspect)
	update_aspect()

func update_aspect() -> void:
	shader_material.set_shader_parameter("aspect", size.x / maxf(1.0, size.y))

func _process(delta: float) -> void:
	var universe := get_tree().root.get_node_or_null("Universe")
	visible = universe == null or not universe.active
	if not visible: return
	var target := (get_local_mouse_position() / size.max(Vector2.ONE) - Vector2(0.5, 0.5)).clamp(Vector2(-1, -1), Vector2.ONE)
	drift = drift.lerp(target, 1.0 - exp(-delta * 2.0))
	shader_material.set_shader_parameter("drift", drift)
