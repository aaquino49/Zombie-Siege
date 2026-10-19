class_name BuildMode
extends Node2D

var _state: GameState
var active_type: String = ""
var _preview_origin: Vector2i = Vector2i(-9999, -9999)
var _is_preview_pinned: bool = false
var _drag_start: Vector2i = Vector2i(-9999, -9999)
var _is_dragging: bool = false

var _ghost_sprites: Array[Sprite2D] = []
var _ghost_rects: Array[ColorRect] = []
var _ghost_labels: Array[Label] = []
var _range_preview: Dictionary = {}
var _weather_cache_day: int = -1
var _weather_cache_phase: int = -1
var _weather_delta_tiles: float = 0.0

signal mode_changed(type_id: String)
signal placement_attempted(ok: bool)

func bind(state: GameState) -> void:
	_state = state
	
func select(type_id: String) -> void:
	if type_id == "":
		cancel()
		return
	active_type = type_id
	_is_preview_pinned = false
	_is_dragging = false
	mode_changed.emit(type_id)

func cancel() -> void:
	active_type = ""
	_is_preview_pinned = false
	_is_dragging = false
	_hide_all_ghosts()
	mode_changed.emit("")

func preview_at(origin: Vector2i) -> void:
	_preview_origin = origin
	_is_preview_pinned = true

func place_at(origin: Vector2i, keep_mode: bool) -> int:
	var res: int = _state.try_place(active_type, origin)
	var ok: bool = (res == Placement.Result.OK)
	placement_attempted.emit(ok)
	if ok and not keep_mode:
		cancel()
	return res

func begin_drag(start: Vector2i) -> void:
	_is_dragging = true
	_drag_start = start

func end_drag(end: Vector2i, keep_mode: bool) -> int:
	var tiles: Array[Vector2i] = Placement.line_tiles(_drag_start, end)
	var placed_count: int = 0
	for t in tiles:
		var res: int = _state.try_place(active_type, t)
		if res == Placement.Result.OK:
			placed_count += 1
	_is_dragging = false
	placement_attempted.emit(placed_count > 0)
	if not keep_mode:
		cancel()
	return placed_count

func _unhandled_input(event: InputEvent) -> void:
	if _state == null or active_type == "":
		return
		
	if event.is_action_pressed("cancel") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
		cancel()
		get_viewport().set_input_as_handled()
		return
		
	if event is InputEventMouseMotion:
		if _is_preview_pinned:
			_is_preview_pinned = false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var b_data: Dictionary = _state.data.get_building(active_type)
			if b_data.has("drag_line") and b_data["drag_line"] == true:
				begin_drag(_get_hovered_tile())
				get_viewport().set_input_as_handled()
			else:
				place_at(_get_hovered_tile(), event.shift_pressed)
				get_viewport().set_input_as_handled()
		else:
			if _is_dragging:
				end_drag(_get_hovered_tile(), event.shift_pressed)
				get_viewport().set_input_as_handled()

func _get_hovered_tile() -> Vector2i:
	if _state == null:
		return _preview_origin
	if _is_preview_pinned or not is_inside_tree():
		return _preview_origin
	var b_data: Dictionary = _state.data.get_building(active_type)
	var sz: Array = b_data.get("size", [1, 1])
	var size: Vector2 = Vector2(sz[0], sz[1])
	var mpos: Vector2 = get_global_mouse_position()
	var offset: Vector2 = (size - Vector2.ONE) * Grid.TILE / 2.0
	return Grid.world_to_tile(mpos - offset)

func _footprint_center(origin: Vector2i, size: Vector2i) -> Vector2:
	return Vector2(origin) * Grid.TILE + Vector2(size) * Grid.TILE / 2.0
	
func _process(_delta: float) -> void:
	if _state == null or active_type == "":
		_range_preview.clear()
		_hide_all_ghosts()
		queue_redraw()
		return
		
	var target_tile: Vector2i = _get_hovered_tile()
	var tiles: Array[Vector2i] = [target_tile]
	
	if _is_dragging:
		tiles = Placement.line_tiles(_drag_start, target_tile)
		
	_hide_all_ghosts()
	_range_preview.clear()
	
	var b_data: Dictionary = _state.data.get_building(active_type)
	var sz: Array = b_data.get("size", [1, 1])
	var size_tiles: Vector2i = Vector2i(int(sz[0]), int(sz[1]))
	var tex: Texture2D = BuildingSprites.texture_for(_state.data, active_type)
	
	# To properly handle cost during drag
	var cost_multiplier: int = 0
	
	for i in range(tiles.size()):
		var t: Vector2i = tiles[i]
		var check: int = Placement.check(_state, active_type, t)
		var ok: bool = (check == Placement.Result.OK)
		
		# If dragging, cost is multiplicative
		if ok and _is_dragging:
			var cost: Dictionary = b_data.get("cost", {})
			var total_cost: Dictionary = {}
			for k in cost.keys():
				total_cost[k] = cost[k] * (cost_multiplier + 1)
			if not _state.resources.can_afford(total_cost):
				ok = false
				check = Placement.Result.UNAFFORDABLE
			else:
				cost_multiplier += 1
		if i == 0:
			_range_preview = range_preview_for(active_type, t, ok)
		
		_ensure_ghost_nodes(i)
		var center_world: Vector2 = _footprint_center(t, size_tiles)
		
		var modulate_color: Color = Color(0.4, 1.0, 0.4, 0.6) if ok else Color(1.0, 0.35, 0.35, 0.6)
		
		if tex:
			var sprite: Sprite2D = _ghost_sprites[i]
			var footprint_px: Vector2 = Vector2(size_tiles) * Grid.TILE
			BuildingSprites.apply_pixel_sprite(sprite, tex, footprint_px)
			sprite.position += center_world
			sprite.modulate = modulate_color
			sprite.show()
			_ghost_rects[i].hide()
		else:
			var rect: ColorRect = _ghost_rects[i]
			var footprint_px: Vector2 = Vector2(size_tiles) * Grid.TILE
			rect.size = footprint_px
			rect.position = center_world - footprint_px / 2.0
			rect.color = modulate_color
			rect.show()
			_ghost_sprites[i].hide()
			
		var label: Label = _ghost_labels[i]
		if not ok:
			label.text = Placement.result_text(check)
			var font: Font = label.get_theme_font("font")
			var font_size: int = label.get_theme_font_size("font_size")
			var text_size: Vector2 = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			label.position = center_world - text_size / 2.0
			label.show()
		else:
			label.hide()
	queue_redraw()

func range_preview_for(type_id: String, origin: Vector2i, valid: bool) -> Dictionary:
	if _state == null or type_id not in ["turret", "watchtower"]:
		return {}
	var radius_tiles: float = 0.0
	if type_id == "turret":
		radius_tiles = float(_state.data.get_building("turret").get("range_tiles", 0.0))
	else:
		var tower_data: Dictionary = _state.data.get_building("watchtower")
		radius_tiles = (float(_state.data.balance("guard_range_tiles")) + _state.tech.bonus("guard_range_tiles")) * float(tower_data.get("guard_range_mult", 1.0))
	var size_data: Array = _state.data.get_building(type_id).get("size", [1, 1])
	var center: Vector2 = _footprint_center(origin, Vector2i(int(size_data[0]), int(size_data[1])))
	_refresh_weather_cache()
	var clear_radius_tiles: float = radius_tiles
	var fog_radius_tiles: float = maxf(1.0, radius_tiles + _weather_delta_tiles)
	var fog_config: Dictionary = _state.data.weather_config().get("fog", {})
	var forecast_fog_radius_tiles: float = maxf(1.0, radius_tiles + float(fog_config.get("range_delta_tiles", 0.0)))
	if _state.clock.phase == GameClock.Phase.NIGHT:
		radius_tiles = fog_radius_tiles
	return {"center": center, "radius": radius_tiles * Grid.TILE,
		"radius_tiles": radius_tiles, "clear_radius_tiles": clear_radius_tiles,
		"fog_radius_tiles": fog_radius_tiles, "forecast_fog_radius_tiles": forecast_fog_radius_tiles,
		"color": Color(0.2, 1.0, 0.35) if valid else Color(1.0, 0.2, 0.2)}

func _refresh_weather_cache() -> void:
	if _state == null:
		return
	if _weather_cache_day != _state.clock.day or _weather_cache_phase != _state.clock.phase:
		_weather_cache_day = _state.clock.day
		_weather_cache_phase = _state.clock.phase
		_weather_delta_tiles = Weather.range_delta_px(_state) / Grid.TILE

func _draw() -> void:
	if _range_preview.is_empty():
		return
	draw_arc(_range_preview["center"], float(_range_preview["radius"]), 0.0, TAU, 96,
		_range_preview["color"], 2.0, true)

func _ensure_ghost_nodes(idx: int) -> void:
	while _ghost_sprites.size() <= idx:
		var s: Sprite2D = Sprite2D.new()
		add_child(s)
		_ghost_sprites.append(s)
		
		var r: ColorRect = ColorRect.new()
		add_child(r)
		_ghost_rects.append(r)
		
		var l: Label = Label.new()
		l.add_theme_font_size_override("font_size", UiFont.SMALL)
		l.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		l.add_theme_constant_override("outline_size", 4)
		add_child(l)
		_ghost_labels.append(l)
		
func _hide_all_ghosts() -> void:
	for s in _ghost_sprites: s.hide()
	for r in _ghost_rects: r.hide()
	for l in _ghost_labels: l.hide()
