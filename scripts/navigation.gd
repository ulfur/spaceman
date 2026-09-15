extends RefCounted
## One camera gesture across discrete simulation scales. Navigation never travels the ship.
static var busy := false
static var direction := 1
static var pending := false
static var duration := 0.72
static var arrival_anchor := Vector2.ZERO

static func go(owner: Control, scene: String, anchor: Vector2, inward: bool = true) -> void:
	if busy: return
	direction = 1 if inward else -1
	pending = true
	if DisplayServer.get_name() == "headless":
		owner.get_tree().change_scene_to_file(scene)
		return
	busy = true
	var tree := owner.get_tree()
	arrival_anchor = owner.size * Vector2(0.36, 0.52)
	var overlay := CanvasLayer.new()
	overlay.name = "ScaleTransition"
	overlay.layer = 100
	var screen := TextureRect.new()
	screen.texture = ImageTexture.create_from_image(owner.get_viewport().get_texture().get_image())
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.size = owner.get_viewport_rect().size
	screen.pivot_offset = anchor
	var aperture := ShaderMaterial.new()
	aperture.shader = preload("res://shaders/navigation.gdshader")
	aperture.set_shader_parameter("focus_uv", anchor / screen.size)
	aperture.set_shader_parameter("source_size", screen.size)
	screen.material = aperture
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(screen)
	tree.root.add_child(overlay)
	var fade := screen.create_tween().set_parallel(true)
	fade.tween_method(func(value: float): aperture.set_shader_parameter("progress", value), 0.0, 1.0, duration)
	fade.tween_property(screen, "scale", Vector2.ONE * (4.0 if inward else 0.2), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	fade.tween_method(func(value: float): screen.position = (arrival_anchor - anchor) * value, 0.0, 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	fade.tween_property(screen, "modulate:a", 0.0, duration * 0.76).set_delay(duration * 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tree.change_scene_to_file(scene)
	await fade.finished
	overlay.queue_free()
	busy = false

static func arrive(owner: Control, visual: Control, focus: Vector2 = Vector2(-1, -1)) -> void:
	if not pending: return
	pending = false
	if DisplayServer.get_name() == "headless": return
	# Only the world scales. The new controls settle into their final positions.
	visual.pivot_offset = visual.size * 0.5 if focus.x < 0 else focus
	arrival_anchor = visual.position + visual.pivot_offset
	visual.scale = Vector2.ONE * (0.35 if direction > 0 else 2.6)
	visual.modulate.a = 0.0
	var tween := owner.create_tween().set_parallel(true)
	tween.tween_property(visual, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "modulate:a", 1.0, duration * 0.8).set_delay(duration * 0.2)
