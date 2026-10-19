class_name GameClock extends RefCounted

enum Phase { DAY, NIGHT }

signal phase_changed(phase: int, day: int)
signal dawn(day: int)
signal speed_changed(paused: bool, speed: int)

var day: int = 1
var phase: int = Phase.DAY
var elapsed: float = 0.0
var paused: bool = false
var locked: bool = false
var speed: int = 1
var night_end_check: Callable = Callable()

var _day_length: float
var _night_min_length: float
var _night_max_length: float = 300.0
var _speed_mult: Array[float] = [0.0, 1.0, 2.0, 3.0] # 1-indexed

func _init(data: GameData = null) -> void:
	if data:
		_day_length = data.balance("day_length", 150.0)
		_night_min_length = data.balance("night_min_length", 45.0)
		_night_max_length = maxf(_night_min_length, data.balance("night_max_length", 300.0))
		_speed_mult[1] = data.balance("speed_mult_1", 1.0)
		_speed_mult[2] = data.balance("speed_mult_2", 2.0)
		_speed_mult[3] = data.balance("speed_mult_3", 3.0)
	else:
		_day_length = 150.0
		_night_min_length = 45.0
		_speed_mult[1] = 1.0
		_speed_mult[2] = 2.0
		_speed_mult[3] = 3.0

func scale(real_delta: float) -> float:
	if paused:
		return 0.0
	return real_delta * _speed_mult[speed]

func advance(sim_delta: float) -> void:
	if sim_delta <= 0:
		return
	
	var remaining := sim_delta
	while remaining > 0:
		if phase == Phase.NIGHT and _night_can_end():
			_transition()
		var left := time_to_boundary()
		if left > 0:
			var step := minf(remaining, left)
			elapsed += step
			remaining -= step
			left -= step
			
		if left <= 0 and (phase == Phase.DAY or _night_can_end()):
			_transition()
		# If hostiles remain at the minimum, the next boundary is the cap.

func _transition() -> void:
	if phase == Phase.DAY:
		phase = Phase.NIGHT
		elapsed = 0.0
		phase_changed.emit(phase, day)
	else:
		if _night_can_end():
			phase = Phase.DAY
			elapsed = 0.0
			day += 1
			dawn.emit(day)
			phase_changed.emit(phase, day)

func time_left() -> float:
	if phase == Phase.DAY:
		return maxf(0.0, _day_length - elapsed)
	else:
		return maxf(0.0, _night_min_length - elapsed)

# Simulation ticks split at both the minimum and the hard night cap.
# The HUD keeps using time_left(), which never becomes negative.
func time_to_boundary() -> float:
	var left: float = time_left()
	if phase == Phase.NIGHT and left <= 0.0:
		return maxf(0.0, _night_max_length - elapsed)
	return left

func set_speed(n: int) -> void:
	if locked:
		return
	var clamped := clampi(n, 1, 3)
	var changed: bool = (clamped != speed) or paused
	speed = clamped
	paused = false
	if changed:
		speed_changed.emit(paused, speed)

func set_paused(p: bool) -> void:
	if locked and not p:
		return
	if paused != p:
		paused = p
		speed_changed.emit(paused, speed)

func toggle_pause() -> void:
	if locked:
		return
	set_paused(not paused)

func _night_can_end() -> bool:
	return elapsed >= _night_min_length and (elapsed >= _night_max_length or night_end_check.is_null() or bool(night_end_check.call()))
