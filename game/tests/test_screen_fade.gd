extends TestCase

var fade: ScreenFade
var was_paused: bool

func before_each() -> void:
	was_paused = tree.paused
	fade = ScreenFade.new()
	tree.root.add_child(fade)

func after_each() -> void:
	tree.paused = was_paused
	fade.free()

func test_instant_fades_complete_synchronously_and_release_input() -> void:
	fade.instant = true
	var emitted: Array[String] = []
	fade.faded_out.connect(func() -> void: emitted.append("out"))
	fade.faded_in.connect(func() -> void: emitted.append("in"))
	var completion: Signal = fade.fade_out()
	assert_eq(completion, fade.faded_out)
	assert_eq(emitted, ["out"] as Array[String])
	assert_almost_eq(fade.rect.color.a, 1.0)
	assert_eq(fade.rect.mouse_filter, Control.MOUSE_FILTER_STOP)
	fade.fade_in()
	assert_eq(emitted, ["out", "in"] as Array[String])
	assert_almost_eq(fade.rect.color.a, 0.0)
	assert_eq(fade.rect.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(fade.layer, 100)
	assert_eq(fade.process_mode, Node.PROCESS_MODE_ALWAYS)

func test_animated_fades_work_while_paused() -> void:
	fade.instant = false
	tree.paused = true
	var emitted: Array[String] = []
	fade.faded_out.connect(func() -> void: emitted.append("out"))
	fade.fade_out(0.3)
	assert_eq(fade.rect.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_true(emitted.is_empty())
	fade._tween.custom_step(0.15)
	assert_almost_eq(fade.rect.color.a, 0.5)
	fade._tween.custom_step(0.16)
	assert_eq(emitted, ["out"] as Array[String])
	assert_almost_eq(fade.rect.color.a, 1.0)
	fade.fade_in(0.3)
	fade._tween.custom_step(0.31)
	assert_almost_eq(fade.rect.color.a, 0.0)
	assert_eq(fade.rect.mouse_filter, Control.MOUSE_FILTER_IGNORE)

func test_replacing_fade_cancels_old_tween_and_never_leaves_input_blocked() -> void:
	fade.instant = false
	fade.fade_out()
	var old_tween: Tween = fade._tween
	fade._tween.custom_step(0.1)
	fade.fade_in()
	assert_false(old_tween.is_valid())
	fade._tween.custom_step(0.31)
	assert_eq(fade.rect.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	fade.fade_out(0.0)
	assert_almost_eq(fade.rect.color.a, 1.0)
	fade.fade_in(0.0)
	assert_almost_eq(fade.rect.color.a, 0.0)
	assert_eq(fade.rect.mouse_filter, Control.MOUSE_FILTER_IGNORE)

func test_headless_defaults_to_instant_and_panel_reveal_is_immediate() -> void:
	assert_true(fade.instant)
	var panel := PanelContainer.new()
	panel.modulate.a = 0.0
	tree.root.add_child(panel)
	assert_eq(ScreenFade.reveal_panel(panel), null)
	assert_almost_eq(panel.modulate.a, 1.0)
	panel.free()
