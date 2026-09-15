extends RefCounted
## Shared presentation primitives. No simulation state or commands live here.
const INK := Color("e0e8e4")
const MUTED := Color("91a5af")
const ACCENT := Color("98d4c3")
const AMBER := Color("dfbc82")
const BG := Color("080f16")

static func style(background: Color, border: Color = Color("263943"), padding: int = 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.border_width_bottom = 1
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box

static func install(owner: Control) -> void:
	var skin := Theme.new()
	skin.default_font_size = 16
	skin.set_color("font_color", "Label", INK)
	skin.set_color("font_color", "Button", INK)
	skin.set_color("font_hover_color", "Button", Color.WHITE)
	skin.set_color("font_pressed_color", "Button", ACCENT)
	skin.set_color("font_disabled_color", "Button", Color("687d86"))
	skin.set_stylebox("normal", "Button", style(Color("13212a")))
	skin.set_stylebox("hover", "Button", style(Color("21333b"), ACCENT))
	skin.set_stylebox("pressed", "Button", style(Color("243d3d"), ACCENT))
	skin.set_stylebox("disabled", "Button", style(Color("0d1820"), Color("1a2b34")))
	var focus := style(Color(0, 0, 0, 0), AMBER, 0)
	focus.set_border_width_all(1)
	skin.set_stylebox("focus", "Button", focus)
	skin.set_stylebox("panel", "PanelContainer", style(Color(0.035, 0.065, 0.085, 0.96), Color("2b424d"), 20))
	skin.set_stylebox("panel", "PopupPanel", style(Color("101e28"), Color("3b535d"), 12))
	skin.set_constant("separation", "VBoxContainer", 12)
	skin.set_constant("separation", "HBoxContainer", 8)
	owner.theme = skin

static func label(value: String, font_size: int = 16, color: Color = INK, wrap: bool = false) -> Label:
	var node := Label.new()
	node.text = value
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	if wrap: node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node

static func button(value: String, callback: Callable, id: String, primary: bool = false) -> Button:
	var node := Button.new()
	node.name = id
	node.text = value
	node.custom_minimum_size.y = 42
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_size_override("font_size", 15)
	if primary:
		node.add_theme_stylebox_override("normal", style(Color("26433f"), ACCENT))
		node.add_theme_color_override("font_color", Color("b9e5d5"))
	node.pressed.connect(callback)
	return node

static func selected(node: Button, active: bool) -> void:
	node.toggle_mode = true
	node.set_pressed_no_signal(active)

static func mount(owner: Control, preset: int, offsets: Vector4) -> MarginContainer:
	var node := MarginContainer.new()
	owner.add_child(node)
	node.set_anchors_and_offsets_preset(preset)
	node.offset_left = offsets.x
	node.offset_top = offsets.y
	node.offset_right = offsets.z
	node.offset_bottom = offsets.w
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func column(parent: Node, separation: int = 12) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_constant_override("separation", separation)
	parent.add_child(node)
	return node

static func row(parent: Node, separation: int = 8) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_constant_override("separation", separation)
	parent.add_child(node)
	return node

static func spacer(parent: Node, vertical: bool = false) -> Control:
	var node := Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vertical: node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else: node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(node)
	return node

static func scroll(parent: Node, id: String = "ContentScroll") -> VBoxContainer:
	var node := ScrollContainer.new()
	node.name = id
	node.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(node)
	return column(node)

static func header(owner: Control) -> HBoxContainer:
	var row_node := row(mount(owner, Control.PRESET_TOP_WIDE, Vector4(24, 18, -24, 68)), 12)
	row_node.name = "Navigation"
	row_node.add_child(label("SPACEMAN", 18))
	row_node.add_child(label("/", 18, MUTED))
	return row_node

static func inspector(owner: Control, top: int = 140, bottom: int = -110) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = "Inspector"
	mount(owner, Control.PRESET_RIGHT_WIDE, Vector4(-382, top, -24, bottom)).add_child(panel)
	return column(panel, 14)

static func footer(owner: Control) -> VBoxContainer:
	return column(mount(owner, Control.PRESET_BOTTOM_WIDE, Vector4(24, -91, -24, -18)), 7)

static func status(parent: Node) -> Label:
	var node := label("", 14, ACCENT)
	node.name = "Status"
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(node)
	return node

static func menu(owner: Control, header_row: HBoxContainer, entries: Array) -> Control:
	var layer := Control.new()
	layer.name = "ExpeditionMenu"
	owner.add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.hide()
	var shade := ColorRect.new()
	layer.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.25)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	mount(layer, Control.PRESET_TOP_RIGHT, Vector4(-300, 76, -24, 100 + entries.size() * 50)).add_child(panel)
	var items := column(panel, 4)
	for entry in entries: items.add_child(button(entry[0], _menu_action.bind(layer, entry[1]), entry[2]))
	layer.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed: layer.hide()
	)
	header_row.add_child(button("Menu", func():
		owner.move_child(layer, -1)
		layer.visible = not layer.visible
	, "Menu"))
	return layer

static func _menu_action(layer: Control, callback: Callable) -> void:
	layer.hide()
	callback.call()

static func menu_key(owner: Control, event: InputEvent) -> bool:
	var layer: Control = owner.get_node_or_null("ExpeditionMenu")
	if layer == null or not layer.visible: return false
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		layer.hide()
		owner.get_viewport().set_input_as_handled()
	return true

static func text_dialog(owner: Control, title: String, contents: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title
	var text := RichTextLabel.new()
	text.custom_minimum_size = Vector2(530, 320)
	text.text = contents
	text.add_theme_font_size_override("normal_font_size", 17)
	dialog.add_child(text)
	owner.add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(590, 400))

static func clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
