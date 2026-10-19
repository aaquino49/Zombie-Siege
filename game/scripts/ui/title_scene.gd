class_name TitleScene extends SubViewportContainer
## A presentation-only diorama: no simulation, singleton, timers or tweens.
## Native-pixel viewport is enlarged exactly 4x by the container.

const SEED: int = 112
const LOOP_SECONDS: float = 14.4
const SHOT_SECONDS: float = 0.8
const GUARD_FEET := Vector2(282, 92)
const ZOMBIE_ENTRY_X: float = 328.0
const GRASS: Array[Texture2D] = [
	preload("res://assets/pixel/terrain/grass_1.png"),
	preload("res://assets/pixel/terrain/grass_2.png"),
	preload("res://assets/pixel/terrain/grass_3.png"),
	preload("res://assets/pixel/terrain/grass_4.png")]
const DIRT: Texture2D = preload("res://assets/pixel/terrain/dirt.png")
const COMMAND_CENTER: Texture2D = preload("res://assets/pixel/buildings/command_center.png")
const WATCHTOWER: Texture2D = preload("res://assets/pixel/buildings/watchtower.png")
const FENCE_H: Texture2D = preload("res://assets/pixel/buildings/fence_h.png")
const FENCE_V: Texture2D = preload("res://assets/pixel/buildings/fence_v.png")
const FENCE_CORNER: Texture2D = preload("res://assets/pixel/buildings/fence_corner_nw.png")
const TREE: Texture2D = preload("res://assets/pixel/props/tree_1.png")
const BUSH: Texture2D = preload("res://assets/pixel/props/bush_1.png")
const BUSH_CLEAN: Texture2D = preload("res://assets/pixel/props/bush_3.png")
const GUARD_FRAMES: SpriteFrames = preload("res://assets/pixel/frames/survivor_soldier.tres")
const IDLE_FRAMES: SpriteFrames = preload("res://assets/pixel/frames/survivor_blue.tres")
const WALKER_FRAMES: SpriteFrames = preload("res://assets/pixel/frames/zombie_walker.tres")
const RUNNER_FRAMES: SpriteFrames = preload("res://assets/pixel/frames/zombie_runner.tres")
const FLASH: Texture2D = preload("res://assets/pixel/fx/pistol_muzzle_flash.png")
const BLOOD: Texture2D = preload("res://assets/pixel/fx/blood.png")
const CORPSE: Texture2D = preload("res://assets/pixel/fx/corpse_prone.png")
const LIFE_SECONDS: float = 2.4
const SPAWN_TIMES: Array[float] = [12.4, 13.2, 14.0, 0.4, 1.2, 2.0, 2.8, 3.6, 4.4,
	5.2, 6.0, 6.8, 7.6, 8.4, 9.2, 10.0, 10.8, 11.6]
const DEATH_TIMES: Array[float] = [0.4, 1.2, 2.0, 2.8, 3.6, 4.4, 5.2, 6.0, 6.8,
	7.6, 8.4, 9.2, 10.0, 10.8, 11.6, 12.4, 13.2, 14.0]
const LANES: Array[int] = [48, 60, 72, 84, 96, 108, 120, 132, 144, 148, 56, 68, 80, 92, 104, 116, 128, 140]
const SPEEDS: Array[float] = [8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 8.0, 9.0, 10.0,
	11.0, 12.0, 13.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0]

var capture_clock: bool = false
var _time: float = 0.0
var _capture_frame: int = 0
var _capture_start: float = 0.0
var _guard: AnimatedSprite2D
var _zombies: Array[AnimatedSprite2D] = []
var _blood: Array[Sprite2D] = []
var _corpses: Array[Sprite2D] = []
var _flash: Sprite2D
var _tracer: Line2D
var _flash_frames: Array[AtlasTexture] = []
var _blood_frames: Array[AtlasTexture] = []

func _ready() -> void:
	build_scene()

func build_scene() -> void:
	# Public and idempotent so synchronous off-tree tests use the real builder.
	if _guard != null:
		return
	var ground: Node2D = get_node("Viewport/Stage/Ground")
	var actors: Node2D = get_node("Viewport/Stage/Actors")
	var effects: Node2D = get_node("Viewport/Stage/Effects")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for y: int in range(12):
		for x: int in range(20):
			var texture: Texture2D = GRASS[rng.randi_range(0, GRASS.size() - 1)]
			if x < 4 and y > 3 and y < 9:
				texture = DIRT
			_static_sprite(ground, texture, Vector2(x * 16, y * 16), false)
	_static_sprite(actors, COMMAND_CENTER, Vector2(28, 76)).name = "CommandCenter"
	_static_sprite(actors, WATCHTOWER, Vector2(32, 138)).name = "Watchtower"
	for x: int in range(3):
		_static_sprite(actors, FENCE_H, Vector2(8 + x * 16, 152))
	for y: int in range(5):
		_static_sprite(actors, FENCE_V, Vector2(56, 80 + y * 16))
	_static_sprite(actors, FENCE_CORNER, Vector2(56, 152))
	for x: int in range(5):
		_static_sprite(actors, TREE, Vector2(112 + x * 48, 32))
	_static_sprite(actors, BUSH, Vector2(12, 98))
	_static_sprite(actors, BUSH_CLEAN, Vector2(20, 170))
	_guard = _actor(actors, GUARD_FRAMES, GUARD_FEET, "Guard")
	_pose(_guard, &"idle_right", 0.0)
	for i: int in range(2):
		var survivor: AnimatedSprite2D = _actor(actors, IDLE_FRAMES,
			Vector2(14 + i * 23, 97), "IdleSurvivor%d" % i)
		_pose(survivor, &"idle_down", 0.0)
	_flash_frames = FxStrip.frames(FLASH)
	_blood_frames = FxStrip.frames(BLOOD)
	for i: int in range(SPAWN_TIMES.size()):
		_zombies.append(_actor(actors, RUNNER_FRAMES if i == 3 else WALKER_FRAMES,
			Vector2(ZOMBIE_ENTRY_X, LANES[i]), "Zombie%d" % i))
		_blood.append(_static_sprite(effects, _blood_frames[0], Vector2.ZERO))
		_corpses.append(_static_sprite(ground, FxStrip.frames(CORPSE)[0], Vector2.ZERO))
	_flash = _static_sprite(effects, _flash_frames[0], GUARD_FEET + Vector2(7, -5))
	_flash.offset = Vector2(0, -5)
	_tracer = Line2D.new()
	_tracer.width = 1.0
	_tracer.default_color = Color("d4ccab")
	_tracer.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	effects.add_child(_tracer)
	seek(0.0)

func _static_sprite(parent: Node2D, texture: Texture2D, at: Vector2,
		bottom_center: bool = true) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = at
	sprite.centered = bottom_center
	if bottom_center:
		sprite.offset.y = -texture.get_height() / 2.0
	parent.add_child(sprite)
	return sprite

func _actor(parent: Node2D, frames: SpriteFrames, at: Vector2,
		actor_name: String) -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.name = actor_name
	sprite.sprite_frames = frames
	sprite.position = at
	sprite.offset = Vector2(0, -8)
	# Frames are sought by the single scripted clock, never autoplayed.
	parent.add_child(sprite)
	return sprite

func set_active(active: bool) -> void:
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	get_node("Viewport").render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED

func start_capture(at_seconds: float = 4.05) -> void:
	# Only the screenshot scenario uses a frame clock; real menus use wall time.
	capture_clock = true
	_capture_start = at_seconds
	_capture_frame = 0
	seek(at_seconds)

func _process(delta: float) -> void:
	if capture_clock:
		_capture_frame += 1
		seek(_capture_start + _capture_frame / 60.0)
	else:
		seek(_time + delta)

func seek(seconds: float) -> void:
	if _guard == null:
		return
	_time = fposmod(seconds, LOOP_SECONDS)
	var shot_age: float = fposmod(_time - 0.4, SHOT_SECONDS)
	var shot_time: float = _time - shot_age
	var firing: bool = shot_age < 0.10 - 0.00001
	_pose(_guard, &"attack_right" if firing else &"idle_right", shot_age)
	_flash.visible = firing
	_flash.texture = _flash_frames[mini(int(shot_age * 50.0), _flash_frames.size() - 1)]
	_tracer.visible = firing
	_tracer.set_point_position(0, GUARD_FEET + Vector2(4, -5))
	for i: int in range(_zombies.size()):
		var age: float = fposmod(_time - SPAWN_TIMES[i], LOOP_SECONDS)
		var life_age: float = fposmod(DEATH_TIMES[i] - SPAWN_TIMES[i], LOOP_SECONDS)
		var death_age: float = age - life_age
		var zombie: AnimatedSprite2D = _zombies[i]
		zombie.position = Vector2(roundf(ZOMBIE_ENTRY_X - minf(age, life_age) * SPEEDS[i]), LANES[i])
		zombie.visible = age < life_age + 0.3
		if death_age >= 0.0:
			_pose(zombie, &"death", death_age)
		elif death_age >= -0.25:
			_pose(zombie, &"hurt_left", death_age + 0.25)
		else:
			_pose(zombie, &"walk_left", maxf(age, 0.0))
		var blood: Sprite2D = _blood[i]
		blood.position = zombie.position
		blood.visible = death_age >= 0.0 and death_age < 0.3
		if blood.visible:
			blood.texture = _blood_frames[mini(int(death_age / 0.3 * _blood_frames.size()), _blood_frames.size() - 1)]
		var corpse: Sprite2D = _corpses[i]
		corpse.position = zombie.position
		corpse.visible = death_age >= 0.3 and death_age < 2.8
		corpse.modulate.a = clampf((2.8 - death_age) / 0.5, 0.0, 1.0)
	if firing:
		var target_index: int = _next_shot_target(shot_time)
		_tracer.set_point_position(1, _zombies[target_index].position)

func _next_shot_target(shot_time: float) -> int:
	var target_index: int = 0
	var nearest_death: float = LOOP_SECONDS
	for i: int in range(_zombies.size()):
		var until_death: float = fposmod(DEATH_TIMES[i] - shot_time + 0.01, LOOP_SECONDS)
		if until_death < nearest_death:
			nearest_death = until_death
			target_index = i
	return target_index

func _pose(sprite: AnimatedSprite2D, animation_name: StringName, age: float) -> void:
	sprite.animation = animation_name
	var frames: SpriteFrames = sprite.sprite_frames
	var frame_index: int = int(age * frames.get_animation_speed(animation_name))
	var count: int = frames.get_frame_count(animation_name)
	if frames.get_animation_loop(animation_name):
		frame_index %= count
	else:
		frame_index = mini(frame_index, count - 1)
	sprite.set_frame_and_progress(frame_index, 0.0)
