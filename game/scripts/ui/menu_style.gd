class_name MenuStyle extends RefCounted
## Shared typography and rows; all frames and buttons inherit the project Theme.

const CREAM := Color("d4ccab")
const NEUTRAL := Color("b6aeae")
const BLOOD := Color("e0451b")
const INK := Color("080707")
const BUTTON_SIZE := Vector2(320, 48)

static func apply(content: Control, title_color: Color, banner: bool = false) -> void:
	_style_children(content)
	var title: Label = content.get_node("Title")
	title.add_theme_font_size_override("font_size", UiFont.BANNER if banner else UiFont.TITLE)
	title.add_theme_color_override("font_color", title_color)
	title.add_theme_color_override("font_outline_color", INK)
	title.add_theme_constant_override("outline_size", 4)

static func _style_children(node: Node) -> void:
	if node is Label:
		var label := node as Label
		label.add_theme_font_size_override("font_size", UiFont.BODY)
		label.add_theme_color_override("font_color", CREAM)
	elif node is Button:
		var button := node as Button
		button.add_theme_font_size_override("font_size", UiFont.BODY)
		if not button is CheckButton:
			button.custom_minimum_size = BUTTON_SIZE
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for child: Node in node.get_children():
		_style_children(child)

static func fill_stats(grid: GridContainer, rows: Array[Array]) -> void:
	for child: Node in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for row: Array in rows:
		var label := Label.new()
		label.text = str(row[0])
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", UiFont.BODY)
		label.add_theme_color_override("font_color", CREAM)
		grid.add_child(label)
		var value := Label.new()
		value.text = str(row[1])
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value.add_theme_font_size_override("font_size", UiFont.BODY)
		value.add_theme_color_override("font_color", CREAM)
		grid.add_child(value)
