class_name CombatFx extends Node2D

const POOL_SIZE: int = 32
const BLOOD_POOL_SIZE: int = 32
const CORPSE_POOL_SIZE: int = 64
const STAIN_POOL_SIZE: int = 96
const ACID_POOL_SIZE: int = 32
const ACID_SPLASH_POOL_SIZE: int = 32
const LIFETIME: float = 0.08
const BLOOD_LIFETIME: float = 0.3
const ACID_SPLASH_LIFETIME: float = 0.36
const FLIES_FPS: float = 4.0
const BARREL_OFFSET: float = 20.0
const TRACER_LENGTH: float = 48.0
const PISTOL_TEXTURE: Texture2D = preload("res://assets/pixel/fx/pistol_muzzle_flash.png")
const SHOTGUN_TEXTURE: Texture2D = preload("res://assets/pixel/fx/shotgun_muzzle_flash.png")
const BLOOD_TEXTURE: Texture2D = preload("res://assets/pixel/fx/blood.png")
const ACID_GLOB_TEXTURE: Texture2D = preload("res://assets/pixel/fx/acid_glob.png")
const ACID_SPLASH_TEXTURE: Texture2D = preload("res://assets/pixel/fx/acid_splash.png")
const CORPSE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/pixel/fx/corpse_prone.png"),
	preload("res://assets/pixel/fx/corpse_seated.png")]
const STAIN_TEXTURES: Array[Texture2D] = [
	preload("res://assets/pixel/fx/blood_stain_1.png"),
	preload("res://assets/pixel/fx/blood_stain_2.png"),
	preload("res://assets/pixel/fx/blood_stain_3.png"),
	preload("res://assets/pixel/fx/blood_stain_4.png"),
	preload("res://assets/pixel/fx/blood_stain_5.png")]

var _state: GameState
var _tracers: Array[Line2D] = []
var _flashes: Array[Sprite2D] = []
var _blood: Array[Sprite2D] = []
var _corpses: Array[Sprite2D] = []
var _stains: Array[Sprite2D] = []
var _acid_globs: Array[Sprite2D] = []
var _acid_splashes: Array[Sprite2D] = []
var _pistol_frames: Array[AtlasTexture] = []
var _shotgun_frames: Array[AtlasTexture] = []
var _blood_frames: Array[AtlasTexture] = []
var _acid_glob_frames: Array[AtlasTexture] = []
var _acid_splash_frames: Array[AtlasTexture] = []
var _corpse_frames: Array = [] # Two cached Array[AtlasTexture], one per body.
var _remaining: PackedFloat64Array = PackedFloat64Array()
var _blood_remaining: PackedFloat64Array = PackedFloat64Array()
var _corpse_age: PackedFloat64Array = PackedFloat64Array()
var _stain_age: PackedFloat64Array = PackedFloat64Array()
var _acid_splash_age: PackedFloat64Array = PackedFloat64Array()
var _acid_glob_age: PackedFloat64Array = PackedFloat64Array()
var _acid_glob_starts: Dictionary = {} # AcidGlob instance id -> launch position
var _flash_turret: PackedByteArray = PackedByteArray()
var _corpse_variant: PackedByteArray = PackedByteArray()
var _next: int = 0
var _next_blood: int = 0
var _next_corpse: int = 0
var _next_stain: int = 0
var _next_acid_splash: int = 0
var _active: int = 0
var _active_blood: int = 0
var _has_decals: bool = false
var _dawn_clearing: bool = false

func bind(state: GameState) -> void:
	if _state != null:
		_state.shot_fired.disconnect(_on_shot_fired)
		_state.zombie_hit.disconnect(_on_zombie_hit)
		_state.zombie_killed.disconnect(_on_zombie_killed)
		_state.acid_hit.disconnect(_on_acid_hit)
		_state.clock.phase_changed.disconnect(_on_phase_changed)
	_state = state
	if _tracers.is_empty():
		_create_pools()
	clear()
	_state.shot_fired.connect(_on_shot_fired)
	_state.zombie_hit.connect(_on_zombie_hit)
	_state.zombie_killed.connect(_on_zombie_killed)
	_state.acid_hit.connect(_on_acid_hit)
	_state.clock.phase_changed.connect(_on_phase_changed)
	_on_phase_changed(_state.clock.phase, _state.clock.day)

func _create_pools() -> void:
	_pistol_frames = FxStrip.frames(PISTOL_TEXTURE)
	_shotgun_frames = FxStrip.frames(SHOTGUN_TEXTURE)
	_blood_frames = FxStrip.frames(BLOOD_TEXTURE)
	_acid_glob_frames = FxStrip.frames(ACID_GLOB_TEXTURE)
	_acid_splash_frames = FxStrip.frames(ACID_SPLASH_TEXTURE)
	for strip: Texture2D in CORPSE_TEXTURES:
		_corpse_frames.append(FxStrip.frames(strip))
	_remaining.resize(POOL_SIZE)
	_flash_turret.resize(POOL_SIZE)
	_blood_remaining.resize(BLOOD_POOL_SIZE)
	_corpse_age.resize(CORPSE_POOL_SIZE)
	_corpse_variant.resize(CORPSE_POOL_SIZE)
	_stain_age.resize(STAIN_POOL_SIZE)
	_acid_glob_age.resize(ACID_POOL_SIZE)
	_acid_splash_age.resize(ACID_SPLASH_POOL_SIZE)
	for i: int in range(POOL_SIZE):
		var tracer: Line2D = Line2D.new()
		tracer.width = Grid.PIXEL_SCALE
		tracer.default_color = Color("d4ccab") # Pack's pale yellow.
		tracer.antialiased = false
		tracer.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
		tracer.visible = false
		add_child(tracer)
		_tracers.append(tracer)
		# Move the bottom-padded flash to the barrel's centre before rotating.
		_flashes.append(_make_sprite(_pistol_frames[0], Vector2(0, -5), false))
	for i: int in range(BLOOD_POOL_SIZE):
		_blood.append(_make_sprite(_blood_frames[0], Vector2(0, -8), false))
	# Absolute z=0 and traversal before YSort put decals above ground, below units.
	for i: int in range(STAIN_POOL_SIZE):
		_stains.append(_make_sprite(STAIN_TEXTURES[0], Vector2(0, -8), true))
	for i: int in range(ACID_POOL_SIZE):
		var glob: Sprite2D = _make_sprite(_acid_glob_frames[0], Vector2(0, -8), false)
		glob.z_as_relative = false
		glob.z_index = 4
		_acid_globs.append(glob)
	for i: int in range(ACID_SPLASH_POOL_SIZE):
		var splash: Sprite2D = _make_sprite(_acid_splash_frames[0], Vector2(0, -8), false)
		splash.z_as_relative = false
		splash.z_index = 4
		_acid_splashes.append(splash)
	for i: int in range(CORPSE_POOL_SIZE):
		_corpses.append(_make_sprite(_corpse_frames[0][0], Vector2(0, -8), true))
	if get_parent() != null and get_parent().has_node("YSort"):
		get_parent().move_child(self, get_parent().get_node("YSort").get_index())

func _make_sprite(texture: Texture2D, offset: Vector2, ground: bool) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2.ONE * Grid.PIXEL_SCALE
	sprite.offset = offset
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.visible = false
	if ground:
		sprite.z_as_relative = false
		sprite.z_index = 0
	add_child(sprite)
	return sprite

func clear() -> void:
	for i: int in range(_tracers.size()):
		_remaining[i] = 0.0
		_tracers[i].visible = false
		_flashes[i].visible = false
	for i: int in range(_blood.size()):
		_blood_remaining[i] = 0.0
		_blood[i].visible = false
	_clear_decals()
	_clear_acid_views()
	_next = 0
	_next_blood = 0
	_next_corpse = 0
	_next_stain = 0
	_next_acid_splash = 0
	_active = 0
	_active_blood = 0
	_dawn_clearing = false

func _clear_decals() -> void:
	for i: int in range(_corpses.size()):
		_corpse_age[i] = -1.0
		_corpses[i].visible = false
	for i: int in range(_stains.size()):
		_stain_age[i] = -1.0
		_stains[i].visible = false
	_has_decals = false

func _clear_acid_views() -> void:
	for i: int in range(_acid_globs.size()):
		_acid_globs[i].visible = false
		_acid_glob_age[i] = 0.0
	for i: int in range(_acid_splashes.size()):
		_acid_splashes[i].visible = false
		_acid_splash_age[i] = 0.0
	_acid_glob_starts.clear()

func _on_acid_hit(pos: Vector2) -> void:
	var sprite: Sprite2D = _acid_splashes[_next_acid_splash]
	sprite.position = pos.round()
	sprite.texture = _acid_splash_frames[0]
	sprite.visible = true
	_acid_splash_age[_next_acid_splash] = 0.000001
	_next_acid_splash = (_next_acid_splash + 1) % ACID_SPLASH_POOL_SIZE

func _sync_acid_globs(delta: float) -> void:
	var seen: Dictionary = {}
	var count: int = mini(_state.projectiles.globs.size(), ACID_POOL_SIZE)
	for i: int in range(ACID_POOL_SIZE):
		if i >= count:
			_acid_globs[i].visible = false
			_acid_glob_age[i] = 0.0
			continue
		var glob: AcidGlob = _state.projectiles.globs[i]
		var glob_id: int = glob.get_instance_id()
		seen[glob_id] = true
		if not _acid_glob_starts.has(glob_id):
			_acid_glob_starts[glob_id] = glob.pos
			_acid_glob_age[i] = 0.0
		var start: Vector2 = _acid_glob_starts[glob_id]
		var destination: Vector2 = Grid.tile_to_world(glob.target_tile)
		var total: float = maxf(start.distance_to(destination), 1.0)
		var progress: float = clampf(1.0 - glob.pos.distance_to(destination) / total, 0.0, 1.0)
		_acid_globs[i].position = glob.pos + Vector2(0.0, -sin(progress * PI) * 20.0)
		_acid_globs[i].texture = _acid_glob_frames[int(_acid_glob_age[i] * 12.0) % _acid_glob_frames.size()]
		_acid_globs[i].visible = true
		_acid_glob_age[i] += delta
	for glob_id: int in _acid_glob_starts.keys():
		if not seen.has(glob_id):
			_acid_glob_starts.erase(glob_id)

func _on_shot_fired(from: Vector2, to: Vector2, is_turret: bool) -> void:
	var direction: Vector2 = (to - from).normalized()
	var start: Vector2 = from + direction * minf(BARREL_OFFSET, from.distance_to(to))
	var tracer: Line2D = _tracers[_next]
	tracer.set_point_position(0, start)
	tracer.set_point_position(1, start + direction * minf(TRACER_LENGTH, start.distance_to(to)))
	tracer.modulate.a = 1.0
	tracer.visible = true
	var flash: Sprite2D = _flashes[_next]
	flash.position = start
	flash.rotation = direction.angle()
	flash.texture = _shotgun_frames[0] if is_turret else _pistol_frames[0]
	flash.visible = true
	_flash_turret[_next] = int(is_turret)
	if _remaining[_next] <= 0.0:
		_active += 1
	_remaining[_next] = LIFETIME
	_next = (_next + 1) % POOL_SIZE

func _on_zombie_hit(z: Zombie) -> void:
	var sprite: Sprite2D = _blood[_next_blood]
	sprite.position = z.pos.round()
	sprite.texture = _blood_frames[0]
	sprite.visible = true
	if _blood_remaining[_next_blood] <= 0.0:
		_active_blood += 1
	_blood_remaining[_next_blood] = BLOOD_LIFETIME
	_next_blood = (_next_blood + 1) % BLOOD_POOL_SIZE

func _on_zombie_killed(z: Zombie) -> void:
	# Lethal damage emits killed instead of hit; it needs the same impact burst.
	_on_zombie_hit(z)
	var variant: int = posmod(z.uid, CORPSE_TEXTURES.size())
	var corpse: Sprite2D = _corpses[_next_corpse]
	corpse.position = z.pos.round()
	corpse.texture = _corpse_frames[variant][0]
	corpse.modulate.a = 1.0
	corpse.visible = false
	_corpse_variant[_next_corpse] = variant
	_corpse_age[_next_corpse] = 0.0
	_next_corpse = (_next_corpse + 1) % CORPSE_POOL_SIZE
	var stain: Sprite2D = _stains[_next_stain]
	# Let the puddle extend two source pixels past the body at its feet.
	stain.position = z.pos.round() + Vector2(0, 8)
	stain.texture = STAIN_TEXTURES[posmod(z.uid * 37 + 11, STAIN_TEXTURES.size())]
	stain.modulate.a = 1.0
	stain.visible = false
	_stain_age[_next_stain] = 0.0
	_next_stain = (_next_stain + 1) % STAIN_POOL_SIZE
	_has_decals = true

func _on_phase_changed(phase: int, day: int) -> void:
	var acid_tint: Color = Color(0.75, 1.0, 0.6)
	if phase == GameClock.Phase.NIGHT:
		var night_tint: Color = DayNightTint.FINAL_COLOR if day == _state.data.final_night() else DayNightTint.NIGHT_COLOR
		var inverse_tint: Color = Color(1.0 / night_tint.r, 1.0 / night_tint.g, 1.0 / night_tint.b, 1.0)
		# Partly lift the night overlay, then bias toward acid green so these pixels
		# stay distinct from the warm muzzle flashes under CanvasModulate.
		acid_tint = Color.WHITE.lerp(inverse_tint, 0.15) * Color(0.4, 1.1, 0.4)
	for sprite: Sprite2D in _acid_globs + _acid_splashes:
		sprite.modulate = acid_tint
	if phase == GameClock.Phase.DAY and day > 1:
		_dawn_clearing = true
		_clear_acid_views()
	elif phase == GameClock.Phase.NIGHT:
		if _dawn_clearing:
			_clear_decals()
		_dawn_clearing = false

func _process(delta: float) -> void:
	if _state == null:
		return
	_sync_acid_globs(delta)
	# Use the clock's actual ramp: large ticks and paused reports match lighting.
	# Discard pending bodies too, so none can reappear after the ramp ends.
	var alpha: float = 1.0
	if _dawn_clearing:
		alpha = 1.0 - clampf(_state.clock.elapsed / DayNightTint.DAWN_SECONDS, 0.0, 1.0)
		if alpha <= 0.0:
			_clear_decals()
			_dawn_clearing = false
	var dt: float = _state.clock.scale(delta)
	if dt <= 0.0:
		return
	if _active > 0:
		_process_shots(dt)
	if _active_blood > 0:
		for i: int in range(BLOOD_POOL_SIZE):
			if _blood_remaining[i] <= 0.0:
				continue
			_blood_remaining[i] = maxf(0.0, _blood_remaining[i] - dt)
			_blood[i].texture = _blood_frames[_frame(_blood_remaining[i], BLOOD_LIFETIME, _blood_frames.size())]
			if _blood_remaining[i] <= 0.0:
				_blood[i].visible = false
				_active_blood -= 1
	for i: int in range(ACID_SPLASH_POOL_SIZE):
		if _acid_splash_age[i] <= 0.0:
			continue
		_acid_splash_age[i] += dt
		if _acid_splash_age[i] >= ACID_SPLASH_LIFETIME:
			_acid_splash_age[i] = 0.0
			_acid_splashes[i].visible = false
		else:
			var remaining: float = ACID_SPLASH_LIFETIME - _acid_splash_age[i]
			var frame: int = _frame(remaining, ACID_SPLASH_LIFETIME, _acid_splash_frames.size())
			_acid_splashes[i].texture = _acid_splash_frames[frame]
	if _has_decals:
		_process_decals(dt, alpha)

func _process_shots(dt: float) -> void:
	for i: int in range(POOL_SIZE):
		if _remaining[i] <= 0.0:
			continue
		_remaining[i] = maxf(0.0, _remaining[i] - dt)
		_tracers[i].modulate.a = _remaining[i] / LIFETIME
		var frames: Array[AtlasTexture] = _shotgun_frames if _flash_turret[i] else _pistol_frames
		_flashes[i].texture = frames[_frame(_remaining[i], LIFETIME, frames.size())]
		if _remaining[i] <= 0.0:
			_tracers[i].visible = false
			_flashes[i].visible = false
			_active -= 1

func _process_decals(dt: float, alpha: float) -> void:
	for i: int in range(CORPSE_POOL_SIZE):
		if _corpse_age[i] < 0.0:
			continue
		_corpse_age[i] += dt
		if _corpse_age[i] >= ZombieLayer.DEATH_SECONDS:
			var frames: Array[AtlasTexture] = _corpse_frames[_corpse_variant[i]]
			var frame: int = int((_corpse_age[i] - ZombieLayer.DEATH_SECONDS) * FLIES_FPS) % frames.size()
			_corpses[i].texture = frames[frame]
			_corpses[i].visible = true
			_corpses[i].modulate.a = alpha
	for i: int in range(STAIN_POOL_SIZE):
		if _stain_age[i] < 0.0:
			continue
		_stain_age[i] += dt
		if _stain_age[i] >= ZombieLayer.DEATH_SECONDS:
			_stains[i].visible = true
			_stains[i].modulate.a = alpha

static func _frame(remaining: float, lifetime: float, count: int) -> int:
	return clampi(int((1.0 - remaining / lifetime) * count + 0.000001), 0, count - 1)
