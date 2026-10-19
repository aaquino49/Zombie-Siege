extends Camera2D
class_name CameraController

const PAN_SPEED := 900.0
const EDGE_PAN_ENABLED := true
const EDGE_MARGIN := 12.0
const ZOOM_STEP := 1.1
const SETTINGS_POLL_SECONDS := 0.5

var map_px: Vector2
var shake: ScreenShake
var _cc_cooldown: float = 0.0
var _settings_poll: float = 0.0

func bind(state: GameState) -> void:
	if shake == null:
		shake = ScreenShake.new(randi())
	shake.enabled = GameSettings.load_screen_shake()
	if not state.building_damaged.is_connected(_on_building_damaged):
		state.building_damaged.connect(_on_building_damaged)
	if not state.building_destroyed.is_connected(_on_building_destroyed):
		state.building_destroyed.connect(_on_building_destroyed)
	if not state.command_center_destroyed.is_connected(_on_cc_destroyed):
		state.command_center_destroyed.connect(_on_cc_destroyed)

func _on_building_damaged(b: Building, _amount: int) -> void:
	if shake == null or b == null or b.type_id != "command_center":
		return
	if _cc_cooldown > 0.0:
		return
	_cc_cooldown = CCAlarm.RETRIGGER_SECONDS
	shake.add(0.15)

func _on_building_destroyed(_b: Building) -> void:
	if shake != null:
		shake.add(0.5)

func _on_cc_destroyed() -> void:
	if shake != null:
		shake.add(1.0)

func _ready() -> void:
	# map_px is initialized by whoever sets up the world (e.g. WorldView or scenarios)
	pass

func center_on(world_pos: Vector2) -> void:
	position = world_pos
	if map_px.x > 0.0 and map_px.y > 0.0:
		position = CameraMath.clamp_position(position, zoom.x, get_viewport_rect().size, map_px)

func _process(delta: float) -> void:
	if map_px.x == 0: return
	var move_vec := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	
	if EDGE_PAN_ENABLED and get_window().has_focus():
		var mpos := get_viewport().get_mouse_position()
		var vrect := get_viewport_rect()
		if vrect.has_point(mpos):
			if mpos.x <= EDGE_MARGIN: move_vec.x -= 1.0
			if mpos.x >= vrect.size.x - EDGE_MARGIN: move_vec.x += 1.0
			if mpos.y <= EDGE_MARGIN: move_vec.y -= 1.0
			if mpos.y >= vrect.size.y - EDGE_MARGIN: move_vec.y += 1.0
			# Just clamp components to avoid edge pan stacking with keys and exceeding max speed
			move_vec.x = clampf(move_vec.x, -1.0, 1.0)
			move_vec.y = clampf(move_vec.y, -1.0, 1.0)
			# Normalize if necessary so diagonals aren't faster, but simple clamp is fine for WASD+Edge feeling
			if move_vec.length_squared() > 1.0:
				move_vec = move_vec.normalized()

	if move_vec != Vector2.ZERO:
		position += move_vec * (PAN_SPEED * delta / zoom.x)
	
	position = CameraMath.clamp_position(position, zoom.x, get_viewport_rect().size, map_px)
	_tick_shake(delta)

func _tick_shake(delta: float) -> void:
	if shake == null:
		return
	_cc_cooldown = maxf(0.0, _cc_cooldown - delta)
	_settings_poll += delta
	if _settings_poll >= SETTINGS_POLL_SECONDS:
		_settings_poll = 0.0
		shake.enabled = GameSettings.load_screen_shake()
	shake.tick(delta)
	var s: Vector2 = shake.offset()
	if s == Vector2.ZERO:
		offset = Vector2.ZERO
	else:
		# Whole screen pixels, zoom-compensated so the on-screen shift is s.
		offset = Vector2(roundf(s.x / zoom.x), roundf(s.y / zoom.y))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("zoom_in"):
		_do_zoom(ZOOM_STEP)
	elif event.is_action_pressed("zoom_out"):
		_do_zoom(1.0 / ZOOM_STEP)

func _do_zoom(factor: float) -> void:
	if map_px.x == 0: return
	var old_zoom := zoom.x
	var new_zoom: float = CameraMath.clamp_zoom(old_zoom * factor)
	if new_zoom == old_zoom:
		return
		
	var vrect := get_viewport_rect()
	var mpos := get_viewport().get_mouse_position()
	var cursor_offset := mpos - vrect.size / 2.0
	
	position = CameraMath.zoom_toward(position, old_zoom, new_zoom, cursor_offset)
	zoom = Vector2(new_zoom, new_zoom)
	position = CameraMath.clamp_position(position, new_zoom, vrect.size, map_px)
