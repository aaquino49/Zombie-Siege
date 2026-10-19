class_name ScreenFade extends CanvasLayer
## Owned by Game, so a scene reload cannot interrupt the transition.

signal faded_out
signal faded_in

var rect: ColorRect
var instant: bool = DisplayServer.get_name() == "headless" or "--no-fade" in OS.get_cmdline_user_args()
var _tween: Tween

func _init() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	rect = ColorRect.new()
	rect.name = "Black"
	rect.color = Color(0, 0, 0, 0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _input(_event: InputEvent) -> void:
	if rect.mouse_filter == Control.MOUSE_FILTER_STOP:
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	_cancel_tween()

func fade_out(duration: float = 0.3) -> Signal:
	_cancel_tween()
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	if instant or duration <= 0.0:
		rect.color.a = 1.0
		faded_out.emit()
	else:
		_tween = (Engine.get_main_loop() as SceneTree).create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_tween.tween_property(rect, "color:a", 1.0, duration)
		_tween.tween_callback(func() -> void: faded_out.emit())
	return faded_out

func fade_in(duration: float = 0.3) -> void:
	_cancel_tween()
	if instant or duration <= 0.0:
		_finish_in()
	else:
		rect.mouse_filter = Control.MOUSE_FILTER_STOP
		_tween = (Engine.get_main_loop() as SceneTree).create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_tween.tween_property(rect, "color:a", 0.0, duration)
		_tween.tween_callback(_finish_in)

func _finish_in() -> void:
	rect.color.a = 0.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faded_in.emit()

func _cancel_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null

static func reveal_panel(panel: Control, duration: float = 0.3) -> Tween:
	panel.modulate.a = 1.0
	if DisplayServer.get_name() == "headless" or "--no-fade" in OS.get_cmdline_user_args() or not panel.is_inside_tree():
		return null
	panel.modulate.a = 0.0
	var tween: Tween = panel.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "modulate:a", 1.0, duration)
	return tween
