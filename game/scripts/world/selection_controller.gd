class_name SelectionController extends Node2D

signal selection_changed(kind: String, uid: int)

var selected_kind: String = ""
var selected_uid: int = 0

var _state: GameState
var _removed_selected_uid: int = 0
var _weather_cache_day: int = -1
var _weather_cache_phase: int = -1
var _weather_delta_tiles: float = 0.0

func bind(state: GameState) -> void:
	_state = state
	_state.survivors.survivor_removed.connect(_on_survivor_removed)
	_state.buildings.building_removed.connect(_on_building_removed)
	_state.building_replaced.connect(_on_building_replaced)

func _on_survivor_removed(s: Survivor) -> void:
	if selected_kind == "survivor" and selected_uid == s.uid:
		clear()

func _on_building_removed(b: Building) -> void:
	if selected_kind == "building" and selected_uid == b.uid:
		clear()
		_removed_selected_uid = b.uid

func _on_building_replaced(old_uid: int, replacement: Building) -> void:
	if _removed_selected_uid == old_uid:
		select_building(replacement.uid)
	_removed_selected_uid = 0

func select_at_world(p: Vector2) -> void:
	if not _state:
		return
		
	var closest_s: Survivor = null
	var closest_dist: float = 24.0
	for s in _state.survivors.all():
		if s.sheltered or s.away:
			continue
		var dist: float = s.pos.distance_to(p)
		if dist <= closest_dist:
			closest_dist = dist
			closest_s = s
			
	if closest_s != null:
		select_survivor(closest_s.uid)
		return
		
	var tile: Vector2i = Grid.world_to_tile(p)
	var b: Building = _state.buildings.get_at(tile)
	if b != null:
		select_building(b.uid)
		return
		
	clear()

func select_survivor(uid: int) -> void:
	_removed_selected_uid = 0
	if _state:
		var s: Survivor = _state.survivors.get_by_uid(uid)
		if s == null or s.sheltered or s.away:
			return
	if selected_kind != "survivor" or selected_uid != uid:
		selected_kind = "survivor"
		selected_uid = uid
		selection_changed.emit(selected_kind, selected_uid)

func select_building(uid: int) -> void:
	_removed_selected_uid = 0
	if selected_kind != "building" or selected_uid != uid:
		selected_kind = "building"
		selected_uid = uid
		selection_changed.emit(selected_kind, selected_uid)

func clear() -> void:
	_removed_selected_uid = 0
	if selected_kind != "":
		selected_kind = ""
		selected_uid = 0
		selection_changed.emit(selected_kind, selected_uid)
		queue_redraw()

func _draw() -> void:
	if not _state:
		return
	if selected_kind == "survivor":
		var s: Survivor = _state.survivors.get_by_uid(selected_uid)
		if s:
			draw_arc(s.pos, 22.0, 0, TAU, 32, Color.LIGHT_GREEN, 2.0)
	elif selected_kind == "building":
		var b: Building = _state.buildings.get_by_uid(selected_uid)
		if b:
			var color: Color = Color.YELLOW if b.complete else Color.LIGHT_BLUE
			var b_data: Dictionary = _state.data.get_building(b.type_id)
			var sz: Array = b_data.get("size", [1, 1])
			var w: float = float(sz[0]) * Grid.TILE
			var h: float = float(sz[1]) * Grid.TILE
			var px: float = float(b.origin.x) * Grid.TILE
			var py: float = float(b.origin.y) * Grid.TILE
			var rect: Rect2 = Rect2(px, py, w, h)
			draw_rect(rect, color, false, 2.0)
	var preview: Dictionary = range_preview()
	if not preview.is_empty():
		draw_arc(preview["center"], float(preview["radius"]), 0.0, TAU, 96,
			Color(0.35, 0.9, 1.0), 2.0, true)

func range_preview() -> Dictionary:
	if not _state:
		return {}
	if selected_kind == "building":
		var building: Building = _state.buildings.get_by_uid(selected_uid)
		if building == null or not building.complete:
			return {}
		if building.type_id == "turret":
			var turret_data: Dictionary = _state.data.get_building("turret")
			var turret_tiles: float = float(turret_data.get("range_tiles", 0.0))
			return _range_preview(building.center_world(), turret_tiles)
		if building.type_id == "watchtower":
			return _guard_range_preview(building.center_world(), building)
	elif selected_kind == "survivor":
		var survivor: Survivor = _state.survivors.get_by_uid(selected_uid)
		if survivor == null or survivor.job != Survivor.Job.GUARD:
			return {}
		var post: Building = _state.buildings.get_by_uid(survivor.post_uid)
		if post != null and post.complete:
			return _guard_range_preview(post.center_world(), post)
		var center: Vector2 = Grid.tile_to_world(survivor.post_tile) if survivor.post_tile != Vector2i(-1, -1) else survivor.pos
		return _range_preview(center, float(_state.data.balance("guard_range_tiles")) + _state.tech.bonus("guard_range_tiles"))
	return {}

func _guard_range_preview(center: Vector2, post: Building) -> Dictionary:
	var post_data: Dictionary = _state.data.get_building(post.type_id)
	var radius_tiles: float = (float(_state.data.balance("guard_range_tiles")) + _state.tech.bonus("guard_range_tiles")) * float(post_data.get("guard_range_mult", 1.0))
	return _range_preview(center, radius_tiles)

func _range_preview(center: Vector2, radius_tiles: float) -> Dictionary:
	_refresh_weather_cache()
	var clear_radius_tiles: float = radius_tiles
	var effective_radius_tiles: float = maxf(1.0, radius_tiles + _weather_delta_tiles)
	var fog_config: Dictionary = _state.data.weather_config().get("fog", {})
	var forecast_radius_tiles: float = maxf(1.0, radius_tiles + float(fog_config.get("range_delta_tiles", 0.0)))
	var shown_radius_tiles: float = effective_radius_tiles if _state.clock.phase == GameClock.Phase.NIGHT else clear_radius_tiles
	return {"center": center, "radius": shown_radius_tiles * Grid.TILE,
		"radius_tiles": shown_radius_tiles, "clear_radius_tiles": clear_radius_tiles,
		"fog_radius_tiles": effective_radius_tiles, "forecast_fog_radius_tiles": forecast_radius_tiles}

func _refresh_weather_cache() -> void:
	if _state == null:
		return
	if _weather_cache_day != _state.clock.day or _weather_cache_phase != _state.clock.phase:
		_weather_cache_day = _state.clock.day
		_weather_cache_phase = _state.clock.phase
		_weather_delta_tiles = Weather.range_delta_px(_state) / Grid.TILE

func _process(_delta: float) -> void:
	if _state and selected_kind == "survivor":
		var s: Survivor = _state.survivors.get_by_uid(selected_uid)
		if s == null or s.sheltered or s.away:
			clear()
	if selected_kind != "":
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			select_at_world(get_global_mouse_position())
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if selected_kind != "":
				clear()
				get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel"):
		if selected_kind != "":
			clear()
			get_viewport().set_input_as_handled()
