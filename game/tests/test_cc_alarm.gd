extends TestCase

var data: GameData
var state: GameState
var alarm: CCAlarm

func before_each() -> void:
	data = GameData.load_default()
	state = GameState.new(data, 1337)
	state.waves.enabled = false
	alarm = CCAlarm.new()
	alarm.bind(state)

func after_each() -> void:
	alarm.free()
	data = null
	state = null

func _cc() -> Building:
	return state.buildings.all_of_type("command_center")[0]

func _place_farm() -> Building:
	var origin := state.map.command_center_origin()
	var pos := origin + Vector2i(-5, 0)
	for y: int in range(pos.y - 1, pos.y + 3):
		for x: int in range(pos.x - 1, pos.x + 3):
			var tile := Vector2i(x, y)
			if state.map.occupant_at(tile) != WorldMap.Occupant.BUILDING:
				state.map.vacate(tile, Vector2i.ONE)
	state.resources.add("wood", 100)
	assert_eq(state.try_place("farm", pos), Placement.Result.OK, "Farm places on cleared ground")
	return state.buildings.get_at(pos)

func test_cc_damage_raises_alarm() -> void:
	assert_almost_eq(alarm.intensity(), 0.0)
	assert_false(alarm.visible)
	state.damage_building(_cc(), 10)
	assert_almost_eq(alarm.intensity(), 1.0)
	alarm.tick(0.1)
	assert_true(alarm.visible, "Flash is visible while fading")

func test_farm_hit_does_not_raise_alarm() -> void:
	var farm := _place_farm()
	state.damage_building(farm, 10)
	assert_almost_eq(alarm.intensity(), 0.0)
	assert_false(alarm.visible)

func test_repeated_hits_throttle() -> void:
	state.damage_building(_cc(), 10)
	alarm.tick(0.5)
	assert_almost_eq(alarm.intensity(), 1.0 - 0.5 / CCAlarm.FADE_SECONDS)
	# 0.5 s since the hit: a new hit re-triggers to full.
	state.damage_building(_cc(), 10)
	assert_almost_eq(alarm.intensity(), 1.0)
	alarm.tick(0.1)
	# Only 0.1 s since the re-trigger: this hit is throttled away.
	state.damage_building(_cc(), 10)
	alarm.tick(0.2)
	assert_almost_eq(alarm.intensity(), 1.0 - 0.3 / CCAlarm.FADE_SECONDS)

func test_alarm_fades_out_over_fade_seconds() -> void:
	state.damage_building(_cc(), 10)
	alarm.tick(CCAlarm.FADE_SECONDS)
	assert_almost_eq(alarm.intensity(), 0.0)
	assert_false(alarm.visible)

func test_hidden_when_game_over() -> void:
	state.damage_building(_cc(), 10)
	alarm.tick(0.05)
	assert_true(alarm.visible)
	state.game_over = true
	alarm.tick(0.05)
	assert_false(alarm.visible, "Alarm hides once the game is over")
