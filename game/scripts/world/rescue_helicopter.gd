class_name RescueHelicopter extends Node2D

signal rescue_finished

const FLY_SECONDS := 4.0
const HOVER_SECONDS := 1.5
const ROTOR_DEG_PER_SEC := 900.0
const START_OFFSET := Vector2(900, -600)

var _shadow: Sprite2D
var _body: Sprite2D
var _rotor: Sprite2D
var _state: GameState
var _camera: Camera2D
var _target: Vector2
var _start_pos: Vector2
var _active_tween: Tween
var _finished: bool = false

func _init() -> void:
	visible = false
	
	_shadow = Sprite2D.new()
	_shadow.name = "Shadow"
	_shadow.texture = load("res://assets/fx/helicopter_body.png")
	_shadow.modulate = Color(0, 0, 0, 0.35)
	_shadow.position = Vector2(24, 32)
	add_child(_shadow)
	
	_body = Sprite2D.new()
	_body.name = "Body"
	_body.texture = load("res://assets/fx/helicopter_body.png")
	add_child(_body)
	
	_rotor = Sprite2D.new()
	_rotor.name = "Rotor"
	_rotor.texture = load("res://assets/fx/helicopter_rotor.png")
	_body.add_child(_rotor)

func bind(state: GameState, camera: Camera2D) -> void:
	_state = state
	_camera = camera
	if not _state.game_won.is_connected(start):
		_state.game_won.connect(start)
	if _state.won and not _state.endless:
		start()

func start() -> void:
	var cc := _state.buildings.all_of_type("command_center")
	if cc.is_empty():
		return
	_target = cc[0].center_world()
	
	if _camera != null:
		_camera.position = _target
	
	_start_pos = _target + START_OFFSET
	position = _start_pos
	
	var dir = _target - _start_pos
	var target_rotation = dir.angle()
	_body.rotation = target_rotation
	_shadow.rotation = target_rotation
	
	visible = true
	
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
		
	_finished = false
	_active_tween = create_tween()
	_active_tween.tween_method(_set_t, 0.0, 1.0, FLY_SECONDS)
	_active_tween.tween_callback(_finish_fly)

func _set_t(t: float) -> void:
	position = position_at(_start_pos, _target, t)

func _finish_fly() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.tween_interval(HOVER_SECONDS)
	_active_tween.tween_callback(func():
		if not _finished:
			_finished = true
			rescue_finished.emit()
	)

func _process(delta: float) -> void:
	if visible:
		_rotor.rotation_degrees += ROTOR_DEG_PER_SEC * delta

func skip() -> void:
	if _finished:
		return
		
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
		_active_tween = null
		
	var cc := _state.buildings.all_of_type("command_center")
	if not cc.is_empty():
		_target = cc[0].center_world()
		position = _target
		if _camera != null:
			_camera.position = _target
	visible = true
	
	_finished = true
	rescue_finished.emit()

static func position_at(start: Vector2, target: Vector2, t: float) -> Vector2:
	t = clampf(t, 0.0, 1.0)
	var ease_t := sin(t * PI / 2.0)
	return start.lerp(target, ease_t)
