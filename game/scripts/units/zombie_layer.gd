class_name ZombieLayer extends Node2D

const TYPES: Array[String] = ["walker", "runner", "brute", "spitter"]
const FRAME_PATH := "res://assets/pixel/frames/zombie_%s.tres"
const FOOT_OFFSET := Vector2(0.0, -5.0)
const DEATH_SECONDS := 0.5
const OUTLINE_SHADER: Shader = preload("res://assets/shaders/pixel_outline.gdshader")
const NIGHT_RIM := Color("b8e07a")

var _state: GameState
var _active_sprites: Dictionary = {} # uid -> AnimatedSprite2D
var _free_sprites: Array[AnimatedSprite2D] = []
var _frames: Dictionary = {}
var _last_positions: Dictionary = {}
var _directions: Dictionary = {}
var _hurt: Dictionary = {}
var _resume_animations: Dictionary = {}
var _spitting: Dictionary = {}
var _death_sprites: Array[AnimatedSprite2D] = []
var _death_tweens: Dictionary = {} # AnimatedSprite2D -> Tween
var _outline_material: ShaderMaterial = ShaderMaterial.new()
var _night: bool = false
var _last_phase: int = -1
var _last_final: bool = false

func _init() -> void:
	_outline_material.shader = OUTLINE_SHADER

func bind(state: GameState) -> void:
	if _state != null:
		unbind()
	_state = state
	_last_phase = -1
	_sync_night_appearance()
	for type_id: String in TYPES:
		_frames[type_id] = load(FRAME_PATH % type_id) as SpriteFrames
	_state.zombies.zombie_added.connect(_on_zombie_added)
	_state.zombies.zombie_removed.connect(_on_zombie_removed)
	_state.zombie_hit.connect(_on_zombie_hit)
	_state.zombie_killed.connect(_on_zombie_killed)
	_state.spit_fired.connect(_on_spit_fired)
	_state.clock.phase_changed.connect(_on_phase_changed)
	for z: Zombie in _state.zombies.all():
		_add_sprite(z)

func unbind() -> void:
	if _state != null:
		_state.zombies.zombie_added.disconnect(_on_zombie_added)
		_state.zombies.zombie_removed.disconnect(_on_zombie_removed)
		_state.zombie_hit.disconnect(_on_zombie_hit)
		_state.zombie_killed.disconnect(_on_zombie_killed)
		_state.spit_fired.disconnect(_on_spit_fired)
		_state.clock.phase_changed.disconnect(_on_phase_changed)
	_state = null
	clear()
	_frames.clear()

func clear() -> void:
	for tween: Tween in _death_tweens.values():
		if tween.is_valid():
			tween.kill()
	_death_tweens.clear()
	for sprite: AnimatedSprite2D in _death_sprites:
		_free_sprite(sprite)
	_death_sprites.clear()
	for sprite: AnimatedSprite2D in _active_sprites.values():
		_free_sprite(sprite)
	for sprite: AnimatedSprite2D in _free_sprites:
		_free_sprite(sprite)
	_active_sprites.clear()
	_free_sprites.clear()
	_last_positions.clear()
	_directions.clear()
	_hurt.clear()
	_resume_animations.clear()
	_spitting.clear()

func _free_sprite(sprite: AnimatedSprite2D) -> void:
	if is_instance_valid(sprite):
		if sprite.get_parent() == self:
			remove_child(sprite)
		sprite.free()

func _configure_sprite(sprite: AnimatedSprite2D, type_id: String) -> void:
	sprite.sprite_frames = _frames[type_id]
	sprite.scale = Vector2(4.0, 4.0)
	sprite.centered = true
	sprite.offset = FOOT_OFFSET
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.modulate = Color.WHITE
	sprite.self_modulate = Color.WHITE
	sprite.material = _outline_material

func _on_phase_changed(_phase: int, _day: int) -> void:
	_sync_night_appearance()

func _sync_night_appearance() -> void:
	var phase: int = _state.clock.phase
	var final_night: bool = _state.clock.day == _state.data.final_night()
	if phase == _last_phase and final_night == _last_final:
		return
	_last_phase = phase
	_last_final = final_night
	_night = phase == GameClock.Phase.NIGHT
	var rim := Color.TRANSPARENT
	if _night:
		var tint: Color = DayNightTint.FINAL_COLOR if final_night else DayNightTint.NIGHT_COLOR
		# CanvasModulate is applied after fragment(); retain the pale rim in both
		# palettes without unshading the body or losing the warm building lights.
		rim = Color(NIGHT_RIM.r / tint.r, NIGHT_RIM.g / tint.g, NIGHT_RIM.b / tint.b, 1.0)
	_outline_material.set_shader_parameter("outline_color", rim)
	for sprite: AnimatedSprite2D in _active_sprites.values():
		var bar: HpBar = sprite.get_child(0) as HpBar
		bar.always_show = _night
		bar.visible = bar.should_draw()

func _add_sprite(z: Zombie) -> void:
	var sprite: AnimatedSprite2D
	if not _free_sprites.is_empty():
		sprite = _free_sprites.pop_back()
	else:
		sprite = AnimatedSprite2D.new()
		sprite.animation_finished.connect(_on_animation_finished.bind(sprite))
		add_child(sprite)
		var bar := HpBar.new()
		bar.top_level = true
		# The 16px cell top is 52 screen pixels above the sim position.
		bar.y_offset = -56.0
		sprite.add_child(bar)
	sprite.stop()
	_configure_sprite(sprite, z.type_id)
	sprite.set_meta("zombie_uid", z.uid)
	sprite.visible = true
	sprite.position = z.pos
	var direction: String = SurvivorLayer.dir_name(z.facing)
	if direction == "":
		direction = "down"
	_active_sprites[z.uid] = sprite
	_last_positions[z.uid] = z.pos
	_directions[z.uid] = direction
	_hurt[z.uid] = false
	_resume_animations[z.uid] = "walk_%s" % direction
	_spitting[z.uid] = false
	sprite.play(_resume_animations[z.uid])
	sprite.set_frame_and_progress(0, 0.0)
	var bar: HpBar = sprite.get_child(0) as HpBar
	bar.global_position = z.pos
	bar.set_ratio(1.0)
	bar.always_show = _night
	bar.visible = bar.should_draw()

func _on_zombie_added(z: Zombie) -> void:
	_add_sprite(z)

func _on_zombie_removed(z: Zombie) -> void:
	if not _active_sprites.has(z.uid):
		return
	var sprite: AnimatedSprite2D = _active_sprites[z.uid]
	sprite.stop()
	sprite.visible = false
	var bar: HpBar = sprite.get_child(0) as HpBar
	bar.set_ratio(1.0)
	bar.visible = false
	_free_sprites.append(sprite)
	_active_sprites.erase(z.uid)
	_last_positions.erase(z.uid)
	_directions.erase(z.uid)
	_hurt.erase(z.uid)
	_resume_animations.erase(z.uid)
	_spitting.erase(z.uid)

func _play(sprite: AnimatedSprite2D, animation_name: String) -> void:
	if sprite.animation != animation_name:
		sprite.play(animation_name)

func sync() -> void:
	if _state == null:
		return
	# Also catches the direct clock assignments used by screenshot fixtures.
	# This returns immediately in steady phases: no per-sprite uniform writes.
	_sync_night_appearance()
	for z: Zombie in _state.zombies.all():
		if not _active_sprites.has(z.uid):
			continue
		var sprite: AnimatedSprite2D = _active_sprites[z.uid]
		var previous: Vector2 = _last_positions[z.uid]
		var movement: Vector2 = z.pos - previous
		var moved: bool = not movement.is_zero_approx()
		var direction: String = SurvivorLayer.dir_name(movement if moved else z.facing)
		if direction == "":
			direction = _directions[z.uid]
		_directions[z.uid] = direction
		_last_positions[z.uid] = z.pos
		var kind: String = "walk" if moved else ("attack" if z.is_attacking() else "idle")
		_resume_animations[z.uid] = "%s_%s" % [kind, direction]
		sprite.position = z.pos
		var bar: HpBar = sprite.get_child(0) as HpBar
		bar.global_position = z.pos
		var ratio: float = float(z.hp) / float(z.max_hp)
		bar.set_ratio(ratio)
		bar.visible = bar.should_draw()
		if not _hurt[z.uid] and not _spitting[z.uid]:
			_play(sprite, _resume_animations[z.uid])

func _on_spit_fired(from: Vector2, to: Vector2) -> void:
	var closest_uid: int = -1
	var closest_distance: float = INF
	for z: Zombie in _state.zombies.all():
		if z.type_id != "spitter" or not _active_sprites.has(z.uid):
			continue
		var distance: float = z.pos.distance_squared_to(from)
		if distance < closest_distance:
			closest_distance = distance
			closest_uid = z.uid
	if closest_uid < 0:
		return
	var direction: String = SurvivorLayer.dir_name(to - from)
	if direction == "":
		direction = _directions[closest_uid]
	_directions[closest_uid] = direction
	_resume_animations[closest_uid] = "idle_%s" % direction
	_spitting[closest_uid] = true
	if not _hurt[closest_uid]:
		_play(_active_sprites[closest_uid], "spit_%s" % direction)

func _on_zombie_hit(z: Zombie) -> void:
	if not _active_sprites.has(z.uid) or _hurt[z.uid]:
		return
	var direction: String = SurvivorLayer.dir_name(z.facing)
	if direction == "":
		direction = _directions[z.uid]
	_hurt[z.uid] = true
	_spitting[z.uid] = false
	_play(_active_sprites[z.uid], "hurt_%s" % direction)

func _on_animation_finished(sprite: AnimatedSprite2D) -> void:
	var uid: int = int(sprite.get_meta("zombie_uid"))
	if not _active_sprites.has(uid):
		return
	if _hurt[uid]:
		_hurt[uid] = false
		_spitting[uid] = false
	elif _spitting[uid]:
		_spitting[uid] = false
	else:
		return
	_play(sprite, _resume_animations[uid])

func _on_zombie_killed(z: Zombie) -> void:
	var sprite := AnimatedSprite2D.new()
	_configure_sprite(sprite, z.type_id)
	sprite.position = z.pos
	add_child(sprite)
	_death_sprites.append(sprite)
	sprite.play("death")
	var tween: Tween = create_tween()
	_death_tweens[sprite] = tween
	tween.tween_property(sprite, "modulate:a", 0.0, DEATH_SECONDS)
	tween.tween_callback(_finish_death.bind(sprite))

func _finish_death(sprite: AnimatedSprite2D) -> void:
	_death_tweens.erase(sprite)
	_death_sprites.erase(sprite)
	_free_sprite(sprite)

func _process(_delta: float) -> void:
	sync()
