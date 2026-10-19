class_name ScreenShake extends RefCounted
## Trauma-based screen shake. Pure logic with no Node dependencies.
##
## CameraController owns one and applies offset() to Camera2D.offset (never
## position, so clamping and panning are unaffected). Offset magnitude peaks at
## MAX_OFFSET screen pixels and decays to zero as trauma fades.

const MAX_OFFSET := 6.0
const DECAY_RATE := 1.6

var trauma: float = 0.0
var enabled: bool = true
var _rng: RandomNumberGenerator

func _init(seed_value: int = 0) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value

func reseed(seed_value: int) -> void:
	_rng.seed = seed_value

func add(amount: float) -> void:
	if not enabled:
		return
	trauma = clampf(trauma + amount, 0.0, 1.0)

func tick(delta: float) -> void:
	if trauma <= 0.0:
		return
	trauma = maxf(0.0, trauma - DECAY_RATE * delta)

func offset() -> Vector2:
	if trauma <= 0.0:
		return Vector2.ZERO
	var mag: float = MAX_OFFSET * trauma * trauma
	var ang: float = _rng.randf_range(0.0, TAU)
	return Vector2(cos(ang), sin(ang)) * mag
