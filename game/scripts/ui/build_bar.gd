class_name BuildBar extends CanvasLayer

const COST_ICON_SIZE: int = 32

var _state: GameState
var _active_type: String = ""
var _built_day: int = -1
var _layout_width: int = -1
## Cached InfoPanel lookup: the per-frame find_child is resolved once and
## reused (T-216 review). Re-resolved only if the cached node is freed.
var _info_layer: CanvasLayer
var _info_control: Control
signal building_selected(type_id: String)

func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_panel().resized.connect(_anchor_panel)
	# Bind may run before the first theme/layout pass.
	_on_viewport_size_changed.call_deferred()

func _on_viewport_size_changed() -> void:
	if _state != null and _available_width() != _layout_width:
		_rebuild_buttons(_state.clock.day)

func _panel() -> PanelContainer:
	return $Panel as PanelContainer

func _hbox() -> GridContainer:
	return $Panel/HBox as GridContainer

func _card() -> BuildInfoCard:
	return get_node_or_null("BuildInfoCard") as BuildInfoCard

func bind(state: GameState) -> void:
	_state = state
	_state.clock.dawn.connect(_rebuild_buttons)
	_state.resources.changed.connect(_update_affordability)

	_rebuild_buttons(_state.clock.day)
	hide_info()

func refresh(day: int = -1) -> void:
	if _state != null:
		_rebuild_buttons(day)

func refresh_if_stale() -> void:
	if _state != null and _built_day != _state.clock.day:
		_rebuild_buttons(_state.clock.day)

static func cost_text(cost: Dictionary) -> String:
	var keys: Array[String] = ["wood", "scrap", "food", "ammo"]
	var strs: Array[String] = []
	for k in keys:
		if cost.has(k) and typeof(cost[k]) in [TYPE_INT, TYPE_FLOAT] and int(cost[k]) > 0:
			strs.append(str(int(cost[k])) + " " + k)
	if strs.size() > 0:
		return " · ".join(strs)
	return "Free"

static func _caption_lines(text: String, font: Font, width: float) -> String:
	var lines: Array[String] = []
	var line := ""
	for word in text.split(" ", false):
		var candidate := word if line.is_empty() else line + " " + word
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.BODY).x <= width:
			line = candidate
			continue
		if not line.is_empty():
			lines.append(line)
		line = word
	if not line.is_empty():
		lines.append(line)
	return "\n".join(lines)

## Canonical order sums wood + scrap only (GDD 23.7); ties fall back to id.
func _cost_sum(c: Dictionary) -> int:
	return int(c.get("wood", 0)) + int(c.get("scrap", 0))

## Viewport minus 16 px; 1280 fallback for detached tests (no viewport).
func _available_width() -> int:
	var viewport_width: float = 1280.0
	if is_inside_tree() and get_viewport() != null:
		viewport_width = get_viewport().get_visible_rect().size.x
	return int(viewport_width) - 16 - ceili(_panel().get_theme_stylebox("panel").get_minimum_size().x)

func _rebuild_buttons(day: int = -1) -> void:
	if day == -1 and _state != null:
		day = _state.clock.day
	_built_day = day
		
	var hb := _hbox()
	for child in hb.get_children():
		hb.remove_child(child)
		child.queue_free()
		
	var unlocked_psa := _state.data.buildings_unlocked_on(day)
	var valid_types: Array[String] = []
	for t in unlocked_psa:
		if Placement.is_placeable_type(_state.data, t):
			valid_types.append(t)
			
	valid_types.sort_custom(func(a: String, b: String) -> bool:
		var b_a := _state.data.get_building(a)
		var b_b := _state.data.get_building(b)
		var u_a: int = b_a.get("unlock_day", 0)
		var u_b: int = b_b.get("unlock_day", 0)
		if u_a != u_b:
			return u_a < u_b
		var c_a := _cost_sum(b_a.get("cost", {}))
		var c_b := _cost_sum(b_b.get("cost", {}))
		if c_a != c_b:
			return c_a < c_b
		return a < b
	)
	
	# Fit complete words and BODY cost rows first, then distribute spare pixels.
	var font: Font = hb.get_theme_font("font")
	var widths: Array[int] = []
	var row_width: int = hb.get_theme_constant("h_separation") * maxi(0, valid_types.size() - 1)
	for type_id: String in valid_types:
		var building: Dictionary = _state.data.get_building(type_id)
		var longest_word: float = 0.0
		for word: String in str(building.get("name", type_id)).split(" ", false):
			longest_word = maxf(longest_word, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.BODY).x)
		var cost_width: float = 0.0
		var cost: Dictionary = building.get("cost", {})
		for kind: String in ["wood", "scrap"]:
			if int(cost.get(kind, 0)) <= 0:
				continue
			if cost_width > 0.0:
				cost_width += 4.0
			cost_width += COST_ICON_SIZE + 4.0 + font.get_string_size(str(int(cost[kind])), HORIZONTAL_ALIGNMENT_LEFT, -1, UiFont.BODY).x
		var width: int = ceili(maxf(longest_word, cost_width)) + 8
		widths.append(width)
		row_width += width
	var available_width: int = _available_width()
	_layout_width = available_width
	var columns: int = valid_types.size()
	if row_width > available_width and valid_types.size() > 6:
		columns = 6
	hb.columns = maxi(1, columns)
	# Two-row mode tightens padding so the day-8 bar stays near 200 px tall.
	var two_row: bool = valid_types.size() > columns
	# GridContainer shares column widths across rows; measure each column's
	# widest button rather than either row's sum.
	var column_widths: Array[int] = []
	column_widths.resize(columns)
	column_widths.fill(0)
	for index: int in range(widths.size()):
		column_widths[index % columns] = maxi(column_widths[index % columns], widths[index])
	var grid_width: int = hb.get_theme_constant("h_separation") * maxi(0, columns - 1)
	for width: int in column_widths:
		grid_width += width
	var spare: int = maxi(0, available_width - grid_width)
	for index: int in range(widths.size()):
		widths[index] = column_widths[index % columns] + spare / columns + (1 if index % columns < spare % columns else 0)
	# Keep the shared pixel panel texture and its horizontal margins. Compact
	# only the vertical content padding, without reducing icons or font sizes.
	var panel_style: StyleBox = _panel().get_theme_stylebox("panel").duplicate()
	panel_style.content_margin_top = 4.0 if two_row else 12.0
	panel_style.content_margin_bottom = 4.0 if two_row else 12.0
	_panel().add_theme_stylebox_override("panel", panel_style)
	var button_index: int = 0
	for type_id in valid_types:
		var btn := Button.new()
		var btn_width: int = widths[button_index]
		button_index += 1
		btn.custom_minimum_size.x = btn_width
		btn.focus_mode = Control.FOCUS_NONE
		btn.toggle_mode = true
		btn.theme_type_variation = &"ToggleButton"
		btn.clip_contents = true
		hb.add_child(btn)
		
		var b_data := _state.data.get_building(type_id)
		var cost_dict: Dictionary = b_data.get("cost", {})
		var b_name: String = b_data.get("name", type_id)
		btn.tooltip_text = ""
		
		var vbox := VBoxContainer.new()
		vbox.name = "Content"
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vbox.add_theme_constant_override("separation", 0)
		btn.add_child(vbox)
		if button_index <= 9:
			var hotkey := Label.new()
			hotkey.name = "Hotkey"
			hotkey.text = "F%d" % (button_index)
			hotkey.anchor_left = 1.0
			hotkey.anchor_right = 1.0
			hotkey.offset_left = -28.0
			hotkey.offset_top = 2.0
			hotkey.offset_right = -3.0
			hotkey.offset_bottom = 16.0
			hotkey.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			hotkey.add_theme_font_size_override("font_size", 11)
			hotkey.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(hotkey)
		
		var tex := BuildingSprites.texture_for(_state.data, type_id)
		var icon_rect := TextureRect.new()
		icon_rect.name = "Icon"
		var icon_size: float = 32.0
		icon_rect.custom_minimum_size = Vector2(icon_size, icon_size)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.texture = tex
		vbox.add_child(icon_rect)
		
		var name_lines: PackedStringArray = _caption_lines(b_name, btn.get_theme_font("font"), btn_width - 8.0).split("\n")
		var name_font: Font = btn.get_theme_font("font")
		var name_line_height: float = name_font.get_height(UiFont.BODY)
		for line_index in range(name_lines.size()):
			var name_lbl := Label.new()
			name_lbl.name = "Name" if line_index == 0 else "NameContinuation%d" % line_index
			name_lbl.text = name_lines[line_index]
			name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			name_lbl.add_theme_font_size_override("font_size", UiFont.BODY)
			name_lbl.custom_minimum_size.y = name_line_height
			name_lbl.clip_text = true
			name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(name_lbl)
		
		var cost_row := HBoxContainer.new()
		cost_row.name = "Cost"
		cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
		cost_row.add_theme_constant_override("separation", 2 if two_row else 4)
		cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(cost_row)
		for kind: String in ["wood", "scrap"]:
			if int(cost_dict.get(kind, 0)) <= 0:
				continue
			var resource_icon := TextureRect.new()
			resource_icon.name = kind.capitalize() + "Icon"
			resource_icon.texture = load("res://assets/pixel/ui/x2/icon_%s.png" % kind) as Texture2D
			resource_icon.custom_minimum_size = Vector2(COST_ICON_SIZE, COST_ICON_SIZE)
			resource_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			resource_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			resource_icon.stretch_mode = TextureRect.STRETCH_KEEP
			resource_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cost_row.add_child(resource_icon)
			var backing := Panel.new()
			backing.name = "Backing"
			backing.show_behind_parent = true
			backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
			resource_icon.add_child(backing)
			backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var backing_style := StyleBoxFlat.new()
			var backing_color: Color = btn.get_theme_color("font_color")
			# Keep dark silhouettes legible through affordability and modal dimming.
			backing_color.a = 0.4
			backing_style.bg_color = backing_color
			backing.add_theme_stylebox_override("panel", backing_style)
			var cost_lbl := Label.new()
			cost_lbl.name = kind.capitalize() + "Amount"
			cost_lbl.text = str(int(cost_dict[kind]))
			cost_lbl.add_theme_font_size_override("font_size", UiFont.BODY)
			cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cost_row.add_child(cost_lbl)
		# Reserve the actual caption lines and the taller of the icon or BODY cost line.
		var pad: float = 2.0 if two_row else 4.0
		btn.custom_minimum_size.y = ceili(icon_size + name_lines.size() * name_line_height + maxf(COST_ICON_SIZE, name_line_height) + pad)

		btn.set_meta("type_id", type_id)
		btn.toggled.connect(_on_btn_toggled.bind(btn))
		btn.mouse_entered.connect(_on_btn_hovered.bind(type_id))
		btn.mouse_exited.connect(_on_btn_unhovered)

	# Containers grow to their minimum automatically, but do not shrink an
	# already expanded panel unless its old size is cleared.
	_anchor_panel()
	_update_affordability()
	set_active_type(_active_type)

func _anchor_panel() -> void:
	if not is_inside_tree():
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var minimum: Vector2 = _panel().get_combined_minimum_size()
	_panel().size = minimum
	_panel().position = Vector2((viewport_size.x - minimum.x) / 2.0, viewport_size.y - minimum.y - 8.0)

func _update_affordability(_kind: String = "", _amount: int = 0) -> void:
	for child in _hbox().get_children():
		var btn := child as Button
		var type_id: String = btn.get_meta("type_id")
		var b_data := _state.data.get_building(type_id)
		var cost: Dictionary = b_data.get("cost", {})
		if _state.resources.can_afford(cost):
			btn.modulate.a = 1.0
		else:
			btn.modulate.a = 0.5
	refresh_info()

func _on_btn_toggled(on: bool, btn: Button) -> void:
	var type_id: String = btn.get_meta("type_id")
	if on:
		building_selected.emit(type_id)
	else:
		building_selected.emit("")

func set_active_type(type_id: String) -> void:
	_active_type = type_id
	for child in _hbox().get_children():
		var btn := child as Button
		btn.set_pressed_no_signal(btn.get_meta("type_id") == type_id)
	if type_id == "":
		hide_info()
	else:
		show_info(type_id)

func show_info(type_id: String) -> void:
	var card := _card()
	if card == null or _state == null:
		return
	if type_id == "" or not _state.data.building_ids().has(type_id):
		return
	if not _panel().visible:
		return
	if _state.clock != null and _state.clock.locked and _state.clock.paused:
		return
	card.show_for(_state.data, _state.resources, type_id, _hotkey_for_type(type_id))
	_position_card(type_id)

func hide_info() -> void:
	var card := _card()
	if card == null:
		return
	card.hide_card()

func refresh_info() -> void:
	var card := _card()
	if card == null or not card.visible:
		return
	if _state == null:
		return
	var current: String = card.current_type()
	if current == "":
		return
	if not _panel().visible:
		card.hide_card()
		return
	card.show_for(_state.data, _state.resources, current, _hotkey_for_type(current))
	_position_card(current)

func _hotkey_for_type(type_id: String) -> String:
	for index: int in range(_hbox().get_child_count()):
		var btn := _hbox().get_child(index) as Button
		if str(btn.get_meta("type_id")) == type_id:
			return "F%d" % (index + 1) if index < 9 else ""
	return ""

func _modal_screen_open() -> bool:
	if _state == null or _state.game_over or (_state.won and not _state.endless):
		return true
	if _state.clock != null and _state.clock.locked and _state.clock.paused:
		return true
	if not is_inside_tree():
		return false
	var root := get_tree().root
	for screen_name: String in ["PauseMenu", "MainMenu", "SettingsScreen", "HowToPlay",
			"CreditsScreen", "DawnReport", "GameOverScreen", "VictoryScreen"]:
		var screen := root.find_child(screen_name, true, false) as CanvasLayer
		if screen != null and screen.visible:
			return true
	return false

func show_card_for(type_id: String) -> void:
	show_info(type_id)

func _on_btn_hovered(type_id: String) -> void:
	show_info(type_id)

func _on_btn_unhovered() -> void:
	if _active_type != "":
		show_info(_active_type)
	else:
		hide_info()

func _button_for(type_id: String) -> Button:
	for child in _hbox().get_children():
		var btn := child as Button
		if btn != null and str(btn.get_meta("type_id")) == type_id:
			return btn
	return null

func _position_card(type_id: String) -> void:
	var card := _card()
	if card == null or not card.visible:
		return
	if not is_inside_tree():
		return
	var vp := get_viewport()
	if vp == null:
		return
	var vp_size: Vector2 = vp.get_visible_rect().size
	if vp_size.x <= 0.0:
		return
	var btn := _button_for(type_id)
	if btn == null:
		return
	if not btn.is_inside_tree():
		return
	var btn_rect: Rect2 = btn.get_global_rect()
	var min_size: Vector2 = card.get_combined_minimum_size()
	# Assume the full 420 px width when clamping so the card never leaves the
	# viewport even before its first layout pass; the real width is at most this.
	var card_w: float = BuildInfoCard.MAX_WIDTH
	var cx: float = btn_rect.get_center().x - card_w / 2.0
	cx = clampf(cx, 8.0, maxf(8.0, vp_size.x - 8.0 - card_w))
	var panel_rect: Rect2 = _panel().get_global_rect()
	var card_h: float = maxf(min_size.y, card.size.y)
	if card_h <= 0.0:
		card_h = 120.0
	var cy: float = panel_rect.position.y - card_h - 8.0
	card.position = Vector2(cx, cy)

static func position_above_bar(control: Control, viewport_height: float, bar_top: float) -> void:
	var bottom_offset: float = bar_top - 8.0 - viewport_height
	var height: float = control.get_combined_minimum_size().y
	if height <= 0.0:
		height = control.offset_bottom - control.offset_top
	control.offset_bottom = bottom_offset
	control.offset_top = bottom_offset - height

func _info_panel_layer() -> CanvasLayer:
	if _info_layer != null and is_instance_valid(_info_layer):
		return _info_layer
	_info_layer = null
	_info_control = null
	if is_inside_tree():
		_info_layer = get_tree().root.find_child("InfoPanel", true, false) as CanvasLayer
	return _info_layer

func _position_selected_info_panel() -> void:
	if not is_inside_tree():
		return
	var info_layer: CanvasLayer = _info_panel_layer()
	if info_layer == null:
		return
	if _info_control == null or not is_instance_valid(_info_control):
		_info_control = info_layer.get_node_or_null("PanelContainer") as Control
	if _info_control == null or not info_layer.get("visible"):
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var panel: Rect2 = _panel().get_global_rect()
	position_above_bar(_info_control, viewport_size.y, panel.position.y)

func _process(_delta: float) -> void:
	_position_selected_info_panel()
	var card := _card()
	if card == null or not card.visible:
		return
	if not _panel().visible:
		card.hide_card()
		return
	if _state != null and _state.clock != null and _state.clock.locked and _state.clock.paused:
		card.hide_card()
		return
	_position_card(card.current_type())

func _unhandled_input(event: InputEvent) -> void:
	if _state == null or event.is_echo():
		return
	if _modal_screen_open():
		return
	if event.is_action_pressed("build_menu"):
		_panel().visible = not _panel().visible
		if not _panel().visible:
			hide_info()
		elif _active_type != "":
			show_info(_active_type)
		return
	if not _panel().visible:
		return
	for index: int in range(9):
		if not event.is_action_pressed("build_%d" % (index + 1)):
			continue
		if index >= _hbox().get_child_count():
			return
		var btn := _hbox().get_child(index) as Button
		if btn.disabled:
			return
		btn.button_pressed = not btn.button_pressed
		return
