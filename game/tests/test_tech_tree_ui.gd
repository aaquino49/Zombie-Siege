extends TestCase
## Detached scene pattern from test_morale_ui.gd; no frame-dependent input.

var _state: GameState
var _screen: TechTreeScreen
var _root: Node

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	_state.waves.enabled = false
	_root = Node.new()
	for path: String in TechTreeScreen.MODALS:
		var modal := CanvasLayer.new()
		modal.name = path
		modal.visible = false
		_root.add_child(modal)
	_screen = load("res://scenes/ui/tech_tree.tscn").instantiate() as TechTreeScreen
	_root.add_child(_screen)
	_screen.bind(_state, _root)

func after_each() -> void:
	_root.free()
	_state = null

func _event(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event

func test_four_card_states_saved_progress_and_live_bank_bar() -> void:
	_state.tech.restore({"done": ["spotters"], "active": "oiled_turrets", "progress": {"oiled_turrets": 12.75, "better_tools": 7.5}, "banked": 4.75})
	assert_true(_screen.open())
	assert_eq(_screen.cards.size(), 9)
	assert_true(_screen.cards.spotters.disabled)
	assert_true(_screen.cards.reinforced_frames.disabled)
	assert_false(_screen.cards.better_tools.disabled)
	assert_true(_screen.cards.oiled_turrets.button_pressed)
	assert_true(_screen.cards.better_tools._state_label.text.contains("Saved 7 / 20"))
	assert_true(_screen._header.text.begins_with("Banked 4 RP"))
	assert_almost_eq(_screen._bar.value, 12.75)
	assert_almost_eq(_state.tech.banked, 4.75, 0.0001, "display never truncates simulation RP")
	_state.tech.add_points(0.25)
	_screen._process(0.0)
	assert_almost_eq(_screen._bar.value, 17.75)

func test_choose_switch_pause_bank_completion_and_disabled_mouse_clicks() -> void:
	_screen.open()
	_screen.cards.spotters.pressed.emit()
	assert_eq(_state.tech.active, "spotters")
	_state.tech.add_points(4.5)
	_screen.cards.better_tools.pressed.emit()
	assert_almost_eq(float(_state.tech.progress.spotters), 4.5)
	_screen._pause.pressed.emit()
	assert_eq(_state.tech.active, "")
	_state.tech.add_points(30.25)
	_screen.cards.spotters.pressed.emit()
	assert_true(_state.tech.is_done("spotters"))
	assert_almost_eq(_state.tech.banked, 14.75)
	assert_false(_screen.choose("spotters"))
	assert_false(_screen.choose("reinforced_frames"))
	assert_eq(_state.tech.active, "")
	assert_almost_eq(_state.tech.banked, 14.75)

func test_t_escape_close_and_space_preserve_pause_ownership_day_and_night() -> void:
	for phase: int in [GameClock.Phase.DAY, GameClock.Phase.NIGHT]:
		_state.clock.phase = phase
		_state.clock.set_paused(false)
		assert_true(_screen.handle_input(_event("tech_tree")))
		assert_true(_screen.visible)
		assert_false(_state.clock.paused)
		assert_true(_screen.choose("spotters"))
		assert_false(_screen.handle_input(_event("pause")), "Space remains normal HUD pause input")
		assert_true(_screen.handle_input(_event("cancel")), "Esc is consumed before PauseMenu")
		assert_false(_screen.visible)
		assert_false(_state.clock.paused)
		_screen.open()
		_screen.close()
		assert_false(_state.clock.paused)
		_screen.open()
		_screen.handle_input(_event("tech_tree"))
		assert_false(_screen.visible)
	_state.clock.set_paused(true)
	_screen.open()
	_screen.close()
	assert_true(_state.clock.paused)

func test_every_modal_blocks_open_choose_and_closes_research() -> void:
	for path: String in TechTreeScreen.MODALS:
		assert_true(_screen.open())
		var modal: CanvasLayer = _root.get_node(path)
		modal.visible = true
		assert_false(_screen.visible, path + " closes immediately")
		assert_false(_screen.open(), path + " blocks opening")
		assert_false(_screen.choose("spotters"), path + " blocks commands")
		assert_true(_screen.handle_input(_event("tech_tree")))
		assert_false(_screen.visible)
		modal.visible = false
	_state.game_over = true
	assert_false(_screen.open())

func test_done_screen_all_cards_keep_cost_effects_and_disable_choices() -> void:
	var ids: Array[String] = []
	for id: String in _state.tech.data.upgrades:
		ids.append(id)
	_state.tech.restore({"done": ids})
	_screen.open()
	for id: String in ids:
		var card: TechUpgradeCard = _screen.cards[id]
		assert_true(card.disabled, id)
		assert_false(card.button_pressed, id)
		assert_true(card._state_label.text.contains("%d RP" % int(_state.tech.data.upgrades[id].cost)))
		assert_true(card._state_label.text.ends_with("Done"))
		assert_true(card._effect_label.text != "")
		assert_false(_screen.choose(id))

func test_card_text_cost_tooltips_and_effect_values_follow_config() -> void:
	_state.tech.data.upgrades.ammo_press.cost = 71
	_state.tech.data.upgrades.ammo_press.effect.value = 5
	_screen.refresh()
	var card: TechUpgradeCard = _screen.cards.ammo_press
	assert_true(card._state_label.text.begins_with("71 RP"))
	assert_true(card._effect_label.text.contains("5 more ammo"))
	assert_eq(card._effect_label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_eq(card._effect_label.get_theme_font_size("font_size"), UiFont.BODY)
	var tooltip: PanelContainer = card._make_custom_tooltip(card.tooltip_text) as PanelContainer
	assert_eq((tooltip.get_child(0) as Label).custom_minimum_size.x, 420.0)
	assert_eq((tooltip.get_child(0) as Label).get_theme_font_size("font_size"), UiFont.BODY)
	tooltip.free()

func test_physical_t_action_exists_and_research_does_not_stop_simulation() -> void:
	assert_true(InputMap.has_action("tech_tree"))
	assert_eq((InputMap.action_get_events("tech_tree")[0] as InputEventKey).physical_keycode, KEY_T)
	_state.clock.set_paused(false)
	_screen.open()
	var elapsed: float = _state.clock.elapsed
	_state.tick(0.5)
	assert_gt(_state.clock.elapsed, elapsed)
	assert_true(_screen.visible)
