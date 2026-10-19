extends TestCase

func test_acid_pools_recycle_clear_rebind_and_free_without_retaining_state() -> void:
	var state: GameState = GameState.new(GameData.load_default(), 1337)
	var state_ref: WeakRef = weakref(state)
	var fx: CombatFx = CombatFx.new()
	fx.bind(state)
	var turret: Building = state.buildings.add("turret", Vector2i(12, 12), true)
	var node_refs: Array[WeakRef] = []
	var node_ids: Array[int] = []
	for child: Node in fx.get_children():
		node_refs.append(weakref(child))
		node_ids.append(child.get_instance_id())
	for i: int in range(CombatFx.ACID_SPLASH_POOL_SIZE * 3):
		state.acid_hit.emit(Vector2(i, 200))
	for i: int in range(CombatFx.ACID_POOL_SIZE + 8):
		state.projectiles.launch(state, Vector2(400, 500), turret, turret.origin, state.data.get_zombie("spitter")["ranged"])
	fx._process(0.0)
	assert_eq(fx.get_child_count(), node_ids.size(), "Overflow reuses fixed pools")
	assert_eq(fx._acid_glob_starts.size(), CombatFx.ACID_POOL_SIZE)
	state.projectiles.clear()
	fx._process(0.0)
	assert_eq(fx._acid_glob_starts.size(), 0, "Finished projectiles release tracking entries")
	for glob: Sprite2D in fx._acid_globs:
		assert_false(glob.visible)
	fx.clear()
	for child: CanvasItem in fx.get_children():
		assert_false(child.visible, "Teardown hides every pooled view")
	var next_state: GameState = GameState.new(GameData.load_default(), 1338)
	fx.bind(next_state)
	state.acid_hit.emit(Vector2(500, 500))
	for splash: Sprite2D in fx._acid_splashes:
		assert_false(splash.visible, "Rebinding disconnects old acid-hit events")
	for i: int in range(node_ids.size()):
		assert_eq(fx.get_child(i).get_instance_id(), node_ids[i], "Rebinding retains pool nodes")
	state = null
	assert_eq(state_ref.get_ref(), null, "FX no longer retains the old state")
	next_state.acid_hit.emit(Vector2(100, 200))
	assert_true(fx._acid_splashes[0].visible, "New state remains connected")
	fx.free()
	for ref: WeakRef in node_refs:
		assert_eq(ref.get_ref(), null, "Freeing FX releases every pooled node")

