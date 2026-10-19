extends TestCase

func test_scavenging_dawn_snapshot_roundtrip_preserves_loot_survivors_and_hint_once() -> void:
	var state := GameState.new(GameData.load_default(), 1337)
	state.waves.enabled = false
	state.clock.day = 8
	var config: Dictionary = state.data._expeditions
	config["lost_base"] = 0.0
	config["lost_per_day"] = 0.0
	var person: Survivor = state.survivors.all()[0]
	assert_true(state.expeditions.send(person.uid))
	state.survivors.tick(1000.0, state.pathfinder, state.map)
	state.expeditions.tick(state, 0.0)
	assert_true(person.away)
	state.clock.elapsed = float(state.data.balance("day_length")) - 0.1
	state.clock.advance(0.2)
	state.clock.elapsed = float(state.data.balance("night_min_length")) - 0.1
	state.clock.advance(0.2)
	assert_eq(state.last_dawn_report["scavenging"].size(), 1)
	var hints := TutorialHints.new()
	hints.shown = {"welcome": true, "farm": true, "night_soon": true, "ammo": true, "radio": true, "hungry": true, "scavenge": true, "spitters": true}
	var snapshot: Dictionary = SaveGame.capture(state, {"hints": hints.shown})
	var restored: GameState = SaveGame.restore(GameData.load_default(), SaveGame.from_json(SaveGame.to_json(snapshot)))
	assert_not_null(restored)
	if restored == null:
		return
	assert_eq(SaveGame.capture(restored)["resources"], snapshot["resources"])
	assert_eq(SaveGame.capture(restored)["survivors"], snapshot["survivors"])
	assert_eq(restored.clock.day, 9)
	assert_true(restored.expeditions.active().is_empty())
	hints = TutorialHints.new()
	hints.shown = SaveGame.from_json(SaveGame.to_json(snapshot))["extra"]["hints"]
	assert_eq(hints.check(restored, 0.0), "", "Scavenge and spitter hints do not repeat after Continue")
