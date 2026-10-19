class_name DayNightTint extends CanvasModulate

const DAY_COLOR: Color = Color(1, 1, 1)
const NIGHT_COLOR: Color = Color(0.55, 0.60, 0.80)
const FINAL_COLOR: Color = Color(0.80, 0.42, 0.42)
const DUSK_SECONDS: float = 12.0
const DAWN_SECONDS: float = 6.0

var _state: GameState

static func tint_for(phase: int, elapsed: float, time_left: float, day: int, final_night: int) -> Color:
	var night_color: Color = FINAL_COLOR if day == final_night else NIGHT_COLOR
	if phase == GameClock.Phase.NIGHT:
		return night_color
	if day > 1 and elapsed < DAWN_SECONDS:
		var previous_color: Color = FINAL_COLOR if day - 1 == final_night else NIGHT_COLOR
		return previous_color.lerp(DAY_COLOR, clampf(elapsed / DAWN_SECONDS, 0.0, 1.0))
	if time_left < DUSK_SECONDS:
		return DAY_COLOR.lerp(night_color, clampf(1.0 - time_left / DUSK_SECONDS, 0.0, 1.0))
	return DAY_COLOR

func bind(state: GameState) -> void:
	_state = state
	_process(0.0)

func _process(_delta: float) -> void:
	if not _state:
		color = DAY_COLOR
		return
	var clock: GameClock = _state.clock
	color = tint_for(clock.phase, clock.elapsed, clock.time_left(), clock.day, _state.data.final_night())
