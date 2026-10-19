class_name PhaseBanner extends Control

const BANNER_SECONDS: float = 4.0
const FADE_SECONDS: float = 1.0

var _state: GameState

static func banner_for(phase: int, elapsed: float, day: int, final_night: int) -> Dictionary:
	var text: String = ""
	var is_final: bool = false
	if elapsed < BANNER_SECONDS:
		if phase == GameClock.Phase.NIGHT:
			is_final = day == final_night
			text = "FINAL HORDE" if is_final else "NIGHT %d" % day
		elif day > 1:
			text = "DAY %d" % day
	var alpha: float = clampf((BANNER_SECONDS - elapsed) / FADE_SECONDS, 0.0, 1.0) if text != "" else 0.0
	return {"text": text, "alpha": alpha, "final": is_final}

func bind(state: GameState) -> void:
	_state = state
	_process(0.0)

func _process(_delta: float) -> void:
	if not _state:
		visible = false
		return
	var clock: GameClock = _state.clock
	var banner: Dictionary = banner_for(clock.phase, clock.elapsed, clock.day, _state.data.final_night())
	var label: Label = get_node("Label") as Label
	label.text = banner["text"]
	label.add_theme_font_size_override("font_size", UiFont.BANNER if clock.phase == GameClock.Phase.NIGHT else UiFont.TITLE)
	label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3) if banner["final"] else Color.WHITE)
	modulate.a = banner["alpha"]
	visible = label.text != ""
