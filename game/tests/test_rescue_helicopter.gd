class_name TestRescueHelicopter extends TestCase

var data: GameData
var state: GameState

func before_each() -> void:
	data = GameData.load_default()
	state = GameState.new(data, 1337)
	state.waves.enabled = false

func after_each() -> void:
	data = null
	state = null

func test_position_at_math() -> void:
	var start := Vector2(0, 0)
	var target := Vector2(100, 100)
	
	var p0 := RescueHelicopter.position_at(start, target, 0.0)
	assert_eq(p0, start, "t=0 is start")
	
	var p1 := RescueHelicopter.position_at(start, target, 1.0)
	assert_eq(p1, target, "t=1 is target")
	
	var p05 := RescueHelicopter.position_at(start, target, 0.5)
	# sin(0.5 * PI / 2) = sin(PI/4) = 0.707
	assert_true(p05.distance_to(target) < p05.distance_to(start), "t=0.5 is closer to target")
	
	var p_neg := RescueHelicopter.position_at(start, target, -1.0)
	assert_eq(p_neg, start, "t<0 is clamped to start")
	
	var p_over := RescueHelicopter.position_at(start, target, 2.0)
	assert_eq(p_over, target, "t>1 is clamped to target")

func test_skip_emits_finished_and_positions_at_target() -> void:
	var heli := RescueHelicopter.new()
	var emitted := [0]
	heli.rescue_finished.connect(func(): emitted[0] += 1)
	
	# The Command Center is already placed by GameState initialization
	var cc := state.buildings.all_of_type("command_center")[0]
	
	heli.bind(state, null)
	heli.skip()
	
	assert_eq(emitted[0], 1, "rescue_finished emitted once")
	assert_eq(heli.position, cc.center_world(), "Helicopter is at target")
	assert_true(heli.visible, "Helicopter is visible")
	heli.free()

func test_victory_screen_with_helicopter() -> void:
	var v := load("res://scenes/ui/victory.tscn").instantiate() as CanvasLayer
	var heli := RescueHelicopter.new()
	
	v.call("bind", state, heli)
	
	assert_false(v.visible, "Initially hidden")
	
	state.won = true
	state.game_over = true
	state.game_won.emit()
	
	assert_false(v.visible, "Panel is not visible immediately after game_won")
	assert_true(state.clock.paused, "Clock is paused immediately")
	assert_true(state.clock.locked, "Clock is locked immediately")
	
	heli.rescue_finished.emit()
	assert_true(v.visible, "Panel is visible after rescue_finished")
	
	v.free()
	heli.free()
