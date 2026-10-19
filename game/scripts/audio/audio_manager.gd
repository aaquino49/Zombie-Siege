class_name AudioManager extends Node

const SOUNDS: Dictionary = {
	"gunshot": "res://assets/sfx/gunshot.wav",
	"turret_shot": "res://assets/sfx/turret_shot.wav",
	"zombie_hit": "res://assets/sfx/zombie_hit.ogg",
	"zombie_die": "res://assets/sfx/zombie_die.ogg",
	"zombie_groan_1": "res://assets/sfx/zombie_groan_1.wav",
	"zombie_groan_2": "res://assets/sfx/zombie_groan_2.wav",
	"zombie_groan_3": "res://assets/sfx/zombie_groan_3.wav",
	"building_hit": "res://assets/sfx/building_hit.ogg",
	"building_destroyed": "res://assets/sfx/building_destroyed.ogg",
	"building_placed": "res://assets/sfx/building_placed.ogg",
	"build_complete": "res://assets/sfx/build_complete.ogg",
	"survivor_hurt": "res://assets/sfx/survivor_hurt.ogg",
	"ui_click": "res://assets/sfx/ui_click.ogg",
	"ui_error": "res://assets/sfx/ui_error.ogg",
	"night_horn": "res://assets/sfx/night_horn.wav",
	"dawn_chime": "res://assets/sfx/dawn_chime.wav",
	"cc_alarm": "res://assets/sfx/cc_alarm.wav",
	"victory": "res://assets/sfx/victory.wav",
	"game_over": "res://assets/sfx/game_over.wav",
	"day_loop": "res://assets/music/day_loop.ogg",
	"night_loop": "res://assets/music/night_loop.ogg",
}

const VOICE_CAPS: Dictionary = {
	"gunshot": 4,
	"turret_shot": 4,
	"zombie_hit": 3,
	"zombie_die": 3,
	"building_hit": 2,
	"building_destroyed": 2,
	"building_placed": 2,
	"build_complete": 2,
	"survivor_hurt": 2,
	"ui_click": 2,
	"ui_error": 2,
	"zombie_groan_1": 1,
	"zombie_groan_2": 1,
	"zombie_groan_3": 1,
	"night_horn": 1,
	"dawn_chime": 1,
	"cc_alarm": 1,
	"victory": 1,
	"game_over": 1,
	"day_loop": 1,
	"night_loop": 1,
}

const DEFAULT_VOICE_CAP: int = 1

var played: Dictionary = {}
var manager_time: float = 0.0

var active_music_stream: AudioStream = null
var active_music_name: String = ""

var _state: GameState = null
var _build_mode: Object = null

var _streams: Dictionary = {}
var _sfx_pools: Dictionary = {}
var _players_built: bool = false

var _music_player_a: AudioStreamPlayer = null
var _music_player_b: AudioStreamPlayer = null
var _active_music_player: AudioStreamPlayer = null
var _inactive_music_player: AudioStreamPlayer = null
var _music_tween: Tween = null
var _playbacks: Array[WeakRef] = []
var _shutting_down: bool = false

var _audio_rng: RandomNumberGenerator = null
var _groan_timer: float = 0.0
var _last_cc_alarm_time: float = -999.0
var _game_ended: bool = false

func _init() -> void:
	_audio_rng = RandomNumberGenerator.new()
	_audio_rng.randomize()
	_groan_timer = _audio_rng.randf_range(4.0, 9.0)

func _ready() -> void:
	add_to_group(&"audio_managers")
	if is_inside_tree():
		_setup_ui_clicks()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_release_audio()

func _exit_tree() -> void:
	if get_tree() != null and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	_release_audio()

func get_voice_cap(sound_name: String) -> int:
	return VOICE_CAPS.get(sound_name, DEFAULT_VOICE_CAP)

func can_start(sound_name: String, busy_count: int) -> bool:
	return busy_count < get_voice_cap(sound_name)

func _can_start(sound_name: String, busy_count: int) -> bool:
	return can_start(sound_name, busy_count)

func get_stream(sound_name: String) -> AudioStream:
	return _get_stream(sound_name)

func _get_stream(sound_name: String) -> AudioStream:
	if not _streams.has(sound_name):
		if SOUNDS.has(sound_name):
			_streams[sound_name] = load(SOUNDS[sound_name])
	return _streams.get(sound_name, null)

func play(sound_name: String) -> bool:
	return _play(sound_name)

func _play(sound_name: String) -> bool:
	if _shutting_down or not SOUNDS.has(sound_name):
		return false

	if not is_inside_tree():
		if not _can_start(sound_name, 0):
			return false
		played[sound_name] = played.get(sound_name, 0) + 1
		return true

	var pool: Array = _sfx_pools.get(sound_name, [])
	var busy: int = 0
	var free_player: AudioStreamPlayer = null
	for p: AudioStreamPlayer in pool:
		if p.playing:
			busy += 1
		elif free_player == null:
			free_player = p

	if not _can_start(sound_name, busy) or (pool.size() > 0 and free_player == null):
		return false

	played[sound_name] = played.get(sound_name, 0) + 1
	if free_player != null:
		if free_player.stream == null:
			free_player.stream = _get_stream(sound_name)
		_start_player(free_player)
	return true

func _start_player(player: AudioStreamPlayer) -> void:
	# Keep only weak handles: stop() schedules deletion on the mix thread.
	for i: int in range(_playbacks.size() - 1, -1, -1):
		if _playbacks[i].get_ref() == null:
			_playbacks.remove_at(i)
	player.play()
	if player.has_stream_playback():
		_playbacks.append(weakref(player.get_stream_playback()))

func release_for_quit() -> Array[WeakRef]:
	_shutting_down = true
	unbind()
	set_process(false)
	return _playbacks.duplicate()

func bind(state: GameState, build_mode: Object = null) -> void:
	unbind()
	_state = state
	_build_mode = build_mode
	_game_ended = false

	_build_players()

	if _state != null:
		_state.shot_fired.connect(_on_shot_fired)
		_state.zombie_hit.connect(_on_zombie_hit)
		_state.zombie_killed.connect(_on_zombie_killed)
		_state.building_damaged.connect(_on_building_damaged)
		_state.building_destroyed.connect(_on_building_destroyed)
		_state.survivor_damaged.connect(_on_survivor_damaged)
		if _state.buildings != null:
			_state.buildings.building_completed.connect(_on_building_completed)
		if _state.clock != null:
			_state.clock.phase_changed.connect(_on_phase_changed)
			var is_night: bool = (_state.clock.phase == GameClock.Phase.NIGHT)
			_switch_music("night_loop" if is_night else "day_loop")
		_state.game_won.connect(_on_game_won)
		_state.game_lost.connect(_on_game_lost)

	if _build_mode != null and _build_mode.has_signal("placement_attempted"):
		_build_mode.connect("placement_attempted", _on_placement_attempted)

	if is_inside_tree():
		_setup_ui_clicks()

func unbind() -> void:
	_release_audio()
	if _state != null:
		if _state.shot_fired.is_connected(_on_shot_fired):
			_state.shot_fired.disconnect(_on_shot_fired)
		if _state.zombie_hit.is_connected(_on_zombie_hit):
			_state.zombie_hit.disconnect(_on_zombie_hit)
		if _state.zombie_killed.is_connected(_on_zombie_killed):
			_state.zombie_killed.disconnect(_on_zombie_killed)
		if _state.building_damaged.is_connected(_on_building_damaged):
			_state.building_damaged.disconnect(_on_building_damaged)
		if _state.building_destroyed.is_connected(_on_building_destroyed):
			_state.building_destroyed.disconnect(_on_building_destroyed)
		if _state.survivor_damaged.is_connected(_on_survivor_damaged):
			_state.survivor_damaged.disconnect(_on_survivor_damaged)
		if _state.buildings != null and _state.buildings.building_completed.is_connected(_on_building_completed):
			_state.buildings.building_completed.disconnect(_on_building_completed)
		if _state.clock != null and _state.clock.phase_changed.is_connected(_on_phase_changed):
			_state.clock.phase_changed.disconnect(_on_phase_changed)
		if _state.game_won.is_connected(_on_game_won):
			_state.game_won.disconnect(_on_game_won)
		if _state.game_lost.is_connected(_on_game_lost):
			_state.game_lost.disconnect(_on_game_lost)
		_state = null

	if _build_mode != null:
		if _build_mode.has_signal("placement_attempted") and _build_mode.is_connected("placement_attempted", _on_placement_attempted):
			_build_mode.disconnect("placement_attempted", _on_placement_attempted)
		_build_mode = null

func _build_players() -> void:
	if _players_built:
		_restream_sfx()
		return
	_players_built = true

	for sound_name: String in SOUNDS:
		if sound_name == "day_loop" or sound_name == "night_loop":
			continue
		var cap: int = get_voice_cap(sound_name)
		var pool: Array[AudioStreamPlayer] = []
		var stream: AudioStream = _get_stream(sound_name)
		for i in range(cap):
			var player := AudioStreamPlayer.new()
			player.name = "%s_%d" % [sound_name, i]
			player.bus = &"SFX"
			player.stream = stream
			add_child(player)
			pool.append(player)
		_sfx_pools[sound_name] = pool

	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.name = "MusicA"
	_music_player_a.bus = &"Music"
	add_child(_music_player_a)

	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.name = "MusicB"
	_music_player_b.bus = &"Music"
	add_child(_music_player_b)

	_active_music_player = _music_player_a
	_inactive_music_player = _music_player_b

func _restream_sfx() -> void:
	for sound_name: String in _sfx_pools:
		var stream: AudioStream = _get_stream(sound_name)
		var pool: Variant = _sfx_pools.get(sound_name, [])
		if pool is Array:
			for p: Variant in pool:
				if p is AudioStreamPlayer:
					p.stream = stream

func _setup_ui_clicks() -> void:
	if get_tree() == null:
		return
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	var root: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	if root != null:
		_connect_buttons(root)

func _connect_buttons(node: Node) -> void:
	if node is BaseButton:
		_connect_button(node as BaseButton)
	for child: Node in node.get_children():
		_connect_buttons(child)

func _connect_button(btn: BaseButton) -> void:
	if not btn.pressed.is_connected(_on_button_pressed):
		btn.pressed.connect(_on_button_pressed)

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_connect_button(node as BaseButton)

func _on_button_pressed() -> void:
	_play("ui_click")

func _process(delta: float) -> void:
	manager_time += delta

	if _state != null and _state.clock != null and _state.clock.phase == GameClock.Phase.NIGHT and _state.zombies != null and _state.zombies.count() > 0:
		_groan_timer -= delta
		if _groan_timer <= 0.0:
			var idx: int = _audio_rng.randi_range(1, 3)
			_play("zombie_groan_%d" % idx)
			_groan_timer = _audio_rng.randf_range(4.0, 9.0)

func _on_shot_fired(_from: Vector2, _to: Vector2, is_turret: bool) -> void:
	if is_turret:
		_play("turret_shot")
	else:
		_play("gunshot")

func _on_zombie_hit(_z: Zombie) -> void:
	_play("zombie_hit")

func _on_zombie_killed(_z: Zombie) -> void:
	_play("zombie_die")

func _on_building_damaged(b: Building, _amount: int) -> void:
	_play("building_hit")
	if b != null and b.type_id == "command_center":
		if manager_time - _last_cc_alarm_time >= 5.0:
			_last_cc_alarm_time = manager_time
			_play("cc_alarm")

func _on_building_destroyed(_b: Building) -> void:
	_play("building_destroyed")

func _on_survivor_damaged(_s: Survivor, _amount: int) -> void:
	_play("survivor_hurt")

func _on_building_completed(b: Building) -> void:
	if b != null and b.type_id == "command_center" and b.uid == 1 and (_state != null and _state.time_played == 0.0):
		return
	_play("build_complete")

func _on_placement_attempted(ok: bool) -> void:
	if ok:
		_play("building_placed")
	else:
		_play("ui_error")

func _on_phase_changed(phase: int, _day: int) -> void:
	if _game_ended:
		return
	if phase == GameClock.Phase.NIGHT:
		_play("night_horn")
		_switch_music("night_loop")
		_groan_timer = _audio_rng.randf_range(4.0, 9.0)
	elif phase == GameClock.Phase.DAY:
		_play("dawn_chime")
		_switch_music("day_loop")

func _switch_music(stream_name: String) -> void:
	active_music_name = stream_name
	active_music_stream = _get_stream(stream_name)
	played[stream_name] = played.get(stream_name, 0) + 1

	if active_music_stream == null:
		return

	var old_player: AudioStreamPlayer = _active_music_player
	var new_player: AudioStreamPlayer = _inactive_music_player

	if old_player == null or new_player == null:
		return

	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()

	if not old_player.playing or old_player.stream == null:
		old_player.stream = active_music_stream
		old_player.volume_db = 0.0
		if is_inside_tree():
			_start_player(old_player)
		return

	if not is_inside_tree():
		old_player.stream = active_music_stream
		return

	if old_player.stream == active_music_stream and old_player.playing:
		return

	new_player.stream = active_music_stream
	new_player.volume_db = -40.0
	_start_player(new_player)

	_active_music_player = new_player
	_inactive_music_player = old_player

	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(new_player, "volume_db", 0.0, 2.0)
	_music_tween.tween_property(old_player, "volume_db", -40.0, 2.0)
	_music_tween.chain().tween_callback(Callable(old_player, "stop"))

func _on_game_won() -> void:
	if _game_ended:
		return
	_game_ended = true
	_stop_music()
	_play("victory")

func _on_game_lost(_reason: String) -> void:
	if _game_ended:
		return
	_game_ended = true
	_stop_music()
	_play("game_over")

func resume_after_endless_continue() -> void:
	if _shutting_down or not _game_ended or _state == null or _state.clock == null:
		return
	_game_ended = false
	var is_night: bool = (_state.clock.phase == GameClock.Phase.NIGHT)
	_switch_music("night_loop" if is_night else "day_loop")

func _stop_music() -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null
	if _music_player_a != null:
		_music_player_a.stop()
		_music_player_a.stream = null
	if _music_player_b != null:
		_music_player_b.stop()
		_music_player_b.stream = null
	active_music_stream = null
	active_music_name = ""

func _release_audio() -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null

	if _music_player_a != null:
		_music_player_a.stop()
		_music_player_a.stream = null
	if _music_player_b != null:
		_music_player_b.stop()
		_music_player_b.stream = null

	for pool: Variant in _sfx_pools.values():
		if pool is Array:
			for p: Variant in pool:
				if p is AudioStreamPlayer:
					p.stop()
					p.stream = null

	active_music_stream = null
	active_music_name = ""
	_streams.clear()

	# A driver lock is not a drain: AudioServer retains stopped playbacks until
	# a mix step and a main-thread update. Game.request_quit waits for those.

	_active_music_player = _music_player_a
	_inactive_music_player = _music_player_b
