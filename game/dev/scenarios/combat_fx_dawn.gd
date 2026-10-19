extends RefCounted

const Combat: GDScript = preload("res://dev/scenarios/combat_fx.gd")

static func setup(main: Node) -> void:
	Combat.setup(main)
	var state: GameState = Game.state
	var fx: CombatFx = main.get_node("World/CombatFx") as CombatFx
	# Reach a real dawn, dismiss its report, and finish the shared lighting ramp.
	state.clock.set_paused(false)
	state.clock.elapsed = float(state.data.balance("night_max_length")) - 0.01
	state.tick(0.02)
	# The report opens deferred; enqueue Continue after it so the world is visible.
	main.get_node("DawnReport")._on_continue.call_deferred()
	state.clock.set_paused(false)
	state.tick(DayNightTint.DAWN_SECONDS + 0.01)
	fx._process(DayNightTint.DAWN_SECONDS + 0.01)
	state.clock.set_paused(true)
	main.get_node("World/YSort/Units").sync()
	main.get_node("World/YSort/Zombies").sync()
	main.get_node("World")._process(0.0)
	assert(not fx._has_decals)
	for sprite: Sprite2D in fx._corpses + fx._stains:
		assert(not sprite.visible, "No corpse or stain survives dawn")
