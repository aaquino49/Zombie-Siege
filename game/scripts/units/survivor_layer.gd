class_name SurvivorLayer extends Node2D

const DIRECTIONS: Array[String] = ["down", "up", "left", "right"]
const FRAME_PATH := "res://assets/pixel/frames/survivor_%s.tres"

var _state: GameState
var _sprites: Dictionary = {} # uid -> AnimatedSprite2D
var _last_positions: Dictionary = {}
var _directions: Dictionary = {}
var _hurt: Dictionary = {}
var _attacking: Dictionary = {}
var _death_sprites: Array[AnimatedSprite2D] = []
var _death_tweens: Dictionary = {} # AnimatedSprite2D -> Tween

static func dir_name(v: Vector2) -> String:
	if v.is_zero_approx():
		return ""
	if absf(v.x) >= absf(v.y):
		return "right" if v.x >= 0.0 else "left"
	return "down" if v.y >= 0.0 else "up"

func bind(state: GameState) -> void:
	if _state != null:
		unbind()
	_state = state
	_state.survivors.survivor_added.connect(_on_survivor_added)
	_state.survivors.survivor_removed.connect(_on_survivor_removed)
	_state.survivor_damaged.connect(_on_survivor_damaged)
	_state.survivor_killed.connect(_on_survivor_killed)
	_state.shot_fired.connect(_on_shot_fired)
	for s: Survivor in _state.survivors.all():
		_add_sprite(s)

func unbind() -> void:
	if _state != null:
		if _state.survivors.survivor_added.is_connected(_on_survivor_added):
			_state.survivors.survivor_added.disconnect(_on_survivor_added)
		if _state.survivors.survivor_removed.is_connected(_on_survivor_removed):
			_state.survivors.survivor_removed.disconnect(_on_survivor_removed)
		if _state.survivor_damaged.is_connected(_on_survivor_damaged):
			_state.survivor_damaged.disconnect(_on_survivor_damaged)
		if _state.survivor_killed.is_connected(_on_survivor_killed):
			_state.survivor_killed.disconnect(_on_survivor_killed)
		if _state.shot_fired.is_connected(_on_shot_fired):
			_state.shot_fired.disconnect(_on_shot_fired)
	_state = null
	clear()

func clear() -> void:
	for tween: Tween in _death_tweens.values():
		if tween.is_valid():
			tween.kill()
	_death_tweens.clear()
	for sprite: AnimatedSprite2D in _death_sprites:
		if is_instance_valid(sprite):
			if sprite.get_parent() == self:
				remove_child(sprite)
			sprite.free()
	_death_sprites.clear()
	for uid: int in _sprites.keys():
		var sprite: AnimatedSprite2D = _sprites[uid]
		if is_instance_valid(sprite):
			if sprite.get_parent() == self:
				remove_child(sprite)
			sprite.free()
	_sprites.clear()
	_last_positions.clear()
	_directions.clear()
	_hurt.clear()
	_attacking.clear()

func _add_sprite(s: Survivor) -> void:
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Survivor_%d" % s.uid
	sprite.sprite_frames = load(FRAME_PATH % s.variant) as SpriteFrames
	sprite.scale = Vector2(4.0, 4.0)
	sprite.centered = true
	sprite.offset = Vector2(0.0, -5.0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.animation_finished.connect(_on_animation_finished.bind(s.uid))
	add_child(sprite)
	var hp_bar := HpBar.new()
	hp_bar.top_level = true
	sprite.add_child(hp_bar)
	_sprites[s.uid] = sprite
	_last_positions[s.uid] = s.pos
	_directions[s.uid] = "down"
	_hurt[s.uid] = false
	_attacking[s.uid] = false

func _on_survivor_added(s: Survivor) -> void:
	_add_sprite(s)

func _on_survivor_removed(s: Survivor) -> void:
	if not _sprites.has(s.uid):
		return
	var sprite: AnimatedSprite2D = _sprites[s.uid]
	if sprite.get_parent() == self:
		remove_child(sprite)
	sprite.queue_free()
	_sprites.erase(s.uid)
	_last_positions.erase(s.uid)
	_directions.erase(s.uid)
	_hurt.erase(s.uid)
	_attacking.erase(s.uid)

func _play(sprite: AnimatedSprite2D, animation_name: String) -> void:
	if sprite.animation != animation_name or not sprite.is_playing():
		sprite.play(animation_name)

func sync() -> void:
	if _state == null:
		return
	for s: Survivor in _state.survivors.all():
		if not _sprites.has(s.uid):
			continue
		var sprite: AnimatedSprite2D = _sprites[s.uid]
		var previous: Vector2 = _last_positions.get(s.uid, s.pos)
		var delta_pos: Vector2 = s.pos - previous
		var moved: bool = not delta_pos.is_zero_approx()
		var moving: bool = moved or not s.path.is_empty()
		var facing_name: String = dir_name(s.facing)
		var direction: String = str(_directions.get(s.uid, "down"))
		if not _hurt.get(s.uid, false) and not _attacking.get(s.uid, false):
			if moving and moved:
				direction = dir_name(delta_pos)
			elif facing_name != "":
				direction = facing_name
			_directions[s.uid] = direction
		_last_positions[s.uid] = s.pos
		sprite.position = s.pos
		sprite.rotation = 0.0
		sprite.z_index = 1 if s.on_tower else 0
		sprite.visible = not s.sheltered and not s.away
		var hp_bar: HpBar = sprite.get_child(0) as HpBar
		if hp_bar:
			hp_bar.global_position = s.pos
			hp_bar.visible = not s.sheltered and not s.away
			hp_bar.set_ratio(float(s.hp) / float(s.max_hp))
		if _hurt.get(s.uid, false):
			continue
		if _attacking.get(s.uid, false):
			continue
		if moving:
			_play(sprite, "walk_%s" % direction)
		else:
			_play(sprite, "idle_%s" % direction)

func _on_survivor_damaged(s: Survivor, _amount: int) -> void:
	if not _sprites.has(s.uid):
		return
	var sprite: AnimatedSprite2D = _sprites[s.uid]
	var direction: String = str(_directions.get(s.uid, dir_name(s.facing)))
	var facing_name: String = dir_name(s.facing)
	if facing_name != "":
		direction = facing_name
	_directions[s.uid] = direction
	_hurt[s.uid] = true
	_attacking[s.uid] = false
	_play(sprite, "hurt_%s" % direction)

func _on_animation_finished(uid: int) -> void:
	if not _sprites.has(uid):
		return
	if _hurt.get(uid, false):
		_hurt[uid] = false
	elif _attacking.get(uid, false):
		_attacking[uid] = false
	else:
		return
	var sprite: AnimatedSprite2D = _sprites[uid]
	var survivor: Survivor = _state.survivors.get_by_uid(uid) if _state != null else null
	var animation_name: String = "walk_%s" % _directions[uid] if survivor != null and not survivor.path.is_empty() else "idle_%s" % _directions[uid]
	_play(sprite, animation_name)

func _on_shot_fired(from: Vector2, to: Vector2, is_turret: bool) -> void:
	if is_turret or _state == null:
		return
	var shot_direction: String = dir_name(to - from)
	if shot_direction == "":
		return
	for s: Survivor in _state.survivors.all():
		if s.job != Survivor.Job.GUARD or from.distance_to(s.pos) > 48.0 or not _sprites.has(s.uid) or _hurt[s.uid]:
			continue
		_directions[s.uid] = shot_direction
		_attacking[s.uid] = true
		_play(_sprites[s.uid], "attack_%s" % shot_direction)

func _on_survivor_killed(s: Survivor) -> void:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = load(FRAME_PATH % s.variant) as SpriteFrames
	sprite.scale = Vector2(4.0, 4.0)
	sprite.centered = true
	sprite.offset = Vector2(0.0, -5.0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = s.pos
	sprite.modulate = Color.WHITE
	add_child(sprite)
	_death_sprites.append(sprite)
	sprite.play("death")
	var tween: Tween = create_tween()
	_death_tweens[sprite] = tween
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(_finish_death.bind(sprite))

func _finish_death(sprite: AnimatedSprite2D) -> void:
	_death_tweens.erase(sprite)
	_death_sprites.erase(sprite)
	if is_instance_valid(sprite):
		sprite.queue_free()

func _process(_delta: float) -> void:
	if _state != null:
		sync()
