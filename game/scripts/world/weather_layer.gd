class_name WeatherLayer extends Node2D

const PARTICLE_COUNT: int = 156
const FOG_PATCH_COUNT: int = 6
const PIXEL_STEP: float = 4.0
const RAIN_ALPHA: float = 0.30
const FOG_ALPHA: float = 0.23

var _state: GameState
var _camera: Camera2D
var _rain_points: Array[Vector2] = []
var _rain_lengths: Array[float] = []
var _fog_points: Array[Vector2] = []
var _opacity: float = 0.0
var _target_opacity: float = 0.0
var _target_kind: String = ""
var _display_kind: String = ""
var _drift: float = 0.0
var _weather_day: int = -1
var _weather_phase: int = -1

func bind(state: GameState, camera: Camera2D = null) -> void:
	_state = state
	_camera = camera
	_refresh_target()

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 194
	for i: int in range(PARTICLE_COUNT):
		_rain_points.append(Vector2(rng.randf(), rng.randf()))
		_rain_lengths.append(float(rng.randi_range(12, 24)))
	var fog_layout: Array[Vector2] = [Vector2(0.15, 0.25), Vector2(0.50, 0.18),
		Vector2(0.85, 0.27), Vector2(0.15, 0.75), Vector2(0.50, 0.82), Vector2(0.85, 0.74)]
	for i: int in range(FOG_PATCH_COUNT):
		_fog_points.append(fog_layout[i])
	set_process(true)

func _refresh_target() -> void:
	_weather_day = _state.clock.day if _state != null else -1
	_weather_phase = _state.clock.phase if _state != null else -1
	_target_kind = ""
	if _state == null:
		_target_opacity = 0.0
	elif _state.clock.phase == GameClock.Phase.DAY and _state.weather_day() == "rain":
		_target_kind = "rain"
		_target_opacity = RAIN_ALPHA
	elif _state.clock.phase == GameClock.Phase.NIGHT and _state.weather_night() == "fog":
		_target_kind = "fog"
		_target_opacity = FOG_ALPHA
	else:
		_target_opacity = 0.0

func _process(delta: float) -> void:
	if _state == null:
		return
	if _weather_day != _state.clock.day or _weather_phase != _state.clock.phase:
		_refresh_target()
	if _target_kind != "":
		_display_kind = _target_kind
	_opacity = move_toward(_opacity, _target_opacity, delta * maxf(RAIN_ALPHA, FOG_ALPHA))
	if _opacity > 0.0:
		_drift = fposmod(_drift + delta * 8.0, 4096.0)
	else:
		_display_kind = ""
	queue_redraw()

func _draw() -> void:
	if _state == null or _opacity <= 0.001 or _camera == null:
		return
	var zoom: Vector2 = _camera.zoom
	var viewport_size: Vector2 = get_viewport_rect().size / zoom
	var view_origin: Vector2 = _camera.global_position - viewport_size * 0.5
	if _display_kind == "rain":
		_draw_rain(view_origin, viewport_size)
	elif _display_kind == "fog":
		_draw_fog(view_origin, viewport_size)

func _draw_rain(view_origin: Vector2, viewport_size: Vector2) -> void:
	var color := Color(0.60, 0.82, 1.0, _opacity)
	for i: int in range(_rain_points.size()):
		var normalized: Vector2 = _rain_points[i]
		var x: float = fposmod(normalized.x * viewport_size.x - _drift * 0.72, viewport_size.x)
		var y: float = fposmod(normalized.y * viewport_size.y + _drift * 1.8, viewport_size.y)
		var start := _snap(view_origin + Vector2(x, y))
		var finish := _snap(start + Vector2(-8.0, _rain_lengths[i]))
		draw_line(start, finish, color, PIXEL_STEP, false)

func _draw_fog(view_origin: Vector2, viewport_size: Vector2) -> void:
	var color := Color(0.77, 0.87, 0.92, _rendered_fog_alpha())
	for i: int in range(_fog_points.size()):
		var normalized: Vector2 = _fog_points[i]
		var cx: float = fposmod(normalized.x * viewport_size.x + _drift * 0.55, viewport_size.x)
		var cy: float = fposmod(normalized.y * viewport_size.y + _drift * 0.22, viewport_size.y)
		var center := _snap(view_origin + Vector2(cx, cy))
		# Rounded, soft-stepped 19x13 block silhouettes read as broad mist banks.
		for row: int in range(13):
			for col: int in range(19):
				var dx: int = col - 9
				var dy: int = row - 6
				var edge_variation: int = ((dx * 7 + dy * 11 + i * 5) % 5) - 2
				var distance: float = (float(dx * dx) / 81.0) + (float(dy * dy) / 36.0)
				if distance > 1.0 + float(edge_variation) * 0.055:
					continue
				var softness: float = clampf(1.0 - maxf(0.0, distance - 0.35) * 0.9, 0.38, 1.0)
				var patch_color := color
				patch_color.a *= softness
				var block := Vector2(float(dx * 8), float(dy * 8))
				draw_rect(Rect2(center + block, Vector2(8.0, 8.0)), patch_color, true)

func _rendered_fog_alpha() -> float:
	return minf(_opacity, FOG_ALPHA)

func _snap(point: Vector2) -> Vector2:
	return Vector2(roundf(point.x / PIXEL_STEP) * PIXEL_STEP, roundf(point.y / PIXEL_STEP) * PIXEL_STEP)
