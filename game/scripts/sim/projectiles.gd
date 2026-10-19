class_name Projectiles extends RefCounted

var globs: Array[AcidGlob] = []

func launch(state: GameState, from: Vector2, target: Building, tile: Vector2i, ranged: Dictionary) -> void:
	globs.append(AcidGlob.new(from, tile, target.uid, float(ranged["projectile_speed"]), int(ranged["damage"])))
	state.spit_fired.emit(from, Grid.tile_to_world(tile))

func tick(state: GameState, dt: float) -> void:
	# Preserve launch order for simultaneous impacts.
	var flying: Array[AcidGlob] = []
	for glob: AcidGlob in globs:
		if not glob.tick(state, dt):
			flying.append(glob)
	globs = flying

func clear() -> void:
	globs.clear()
