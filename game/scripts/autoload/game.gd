extends Node

const DEFAULT_SEED := 1337
const QUIT_AUDIO_DEADLINE_MS := 2000
const SAVE_PATH := "user://savegame.json"
const SAVE_TEMP_SUFFIX := ".tmp"
const SAVE_BACKUP_SUFFIX := ".bak"

var state: GameState
var show_menu: bool = true
var next_seed: int = DEFAULT_SEED
var preview_seed: int = DEFAULT_SEED
var screen_fade: ScreenFade
var transitioning: bool = false
var _quitting: bool = false
var save_path: String = SAVE_PATH
var _pending_continue: Dictionary = {}
var _pending_new_difficulty: String = ""
var _pending_restart_difficulty: String = ""
var continued_extra: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	screen_fade = ScreenFade.new()
	add_child(screen_fade)
	AudioSettings.apply(AudioSettings.load_volumes())
	GameSettings.apply_window_mode()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_quit()

func _exit_tree() -> void:
	if _is_automated_run():
		# Only remove this process's disposable slot, even with an injected path.
		delete_save(_automated_save_path())

func request_quit(exit_code: int = 0) -> void:
	if _quitting:
		return
	_quitting = true
	var started_ms: int = Time.get_ticks_msec()
	var pending: Array[WeakRef] = []
	for audio: Node in get_tree().get_nodes_in_group(&"audio_managers"):
		pending.append_array(audio.release_for_quit())
	get_tree().paused = true
	# Keep the tree alive until the mixer removes stopped playbacks and the
	# main-thread AudioServer update releases its references. Frames alone are
	# insufficient in an uncapped run, so poll actual lifetime using weak refs.
	var alive: int = _pending_audio_count(pending)
	while should_keep_waiting(alive, started_ms, Time.get_ticks_msec(), QUIT_AUDIO_DEADLINE_MS):
		await get_tree().create_timer(0.01, true, false, true).timeout
		alive = _pending_audio_count(pending)
	if alive > 0:
		push_warning("Audio shutdown timed out after %d ms; %d playback(s) still alive. Quitting anyway." % [QUIT_AUDIO_DEADLINE_MS, alive])
	get_tree().quit(exit_code)

static func should_keep_waiting(alive: int, started_ms: int, now_ms: int, deadline_ms: int) -> bool:
	return alive > 0 and now_ms - started_ms < deadline_ms

func _has_pending_audio(pending: Array[WeakRef]) -> bool:
	return _pending_audio_count(pending) > 0

func _pending_audio_count(pending: Array[WeakRef]) -> int:
	var alive: int = 0
	for playback: WeakRef in pending:
		if playback.get_ref() != null:
			alive += 1
	return alive

func start_new_game(difficulty: String = "", selected_seed: int = -1) -> void:
	_pending_restart_difficulty = ""
	if not difficulty.is_empty():
		GameSettings.save_difficulty(difficulty)
		_pending_new_difficulty = difficulty
	if selected_seed > 0:
		next_seed = selected_seed
	_transition(false, selected_seed <= 0)

func prepare_new_game_preview() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	next_seed = rng.randi_range(1, 100000000)
	preview_seed = next_seed

func reroll_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var rolled_seed: int = rng.randi_range(1, 100000000)
	while rolled_seed == preview_seed:
		rolled_seed = rng.randi_range(1, 100000000)
	preview_seed = rolled_seed
	return preview_seed

func restart() -> void:
	_remember_restart_difficulty()
	if state:
		next_seed = state.map_seed
	_transition(false)

func _remember_restart_difficulty() -> void:
	_pending_restart_difficulty = state.difficulty if state else ""

func quit_to_menu() -> void:
	_transition(true)

func continue_game(path: String = "") -> void:
	_pending_restart_difficulty = ""
	var target_path: String = _path_or_default(path)
	var saved: Dictionary = _read_save(target_path)
	if saved.is_empty():
		push_warning("Game: Continue save is no longer valid; starting a fresh game")
		delete_save(target_path)
	_pending_continue = saved
	save_path = target_path
	_transition(false)

func reload_day(path: String = "") -> void:
	continue_game(path)

func save_now(extra: Dictionary = {}, path: String = "") -> bool:
	if not state:
		return false
	var target_path: String = _path_or_default(path)
	var captured: Dictionary = SaveGame.capture(state, extra)
	if captured.is_empty():
		return false
	var temporary_path: String = target_path + SAVE_TEMP_SUFFIX
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_warning("Game.save_now: cannot open temporary save: " + temporary_path)
		return false
	file.store_string(SaveGame.to_json(captured))
	file.flush()
	file.close()
	var absolute_temp: String = ProjectSettings.globalize_path(temporary_path)
	var absolute_target: String = ProjectSettings.globalize_path(target_path)
	var backup_path: String = target_path + SAVE_BACKUP_SUFFIX
	var absolute_backup: String = ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(target_path):
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(absolute_backup)
		var backup_error: Error = DirAccess.rename_absolute(absolute_target, absolute_backup)
		if backup_error != OK:
			push_warning("Game.save_now: cannot stage current save: %s" % error_string(backup_error))
			DirAccess.remove_absolute(absolute_temp)
			return false
	var error: Error = DirAccess.rename_absolute(absolute_temp, absolute_target)
	if error != OK:
		push_warning("Game.save_now: cannot replace save %s -> %s (temp exists=%s): %s" % [absolute_temp, absolute_target, str(FileAccess.file_exists(temporary_path)), error_string(error)])
		DirAccess.remove_absolute(absolute_temp)
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup, absolute_target)
		return false
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup)
	return true

func has_save(path: String = "") -> bool:
	return not _read_save(_path_or_default(path)).is_empty()

func has_save_for(run_state: GameState, path: String = "") -> bool:
	if run_state == null:
		return false
	var saved: Dictionary = _read_save(_path_or_default(path))
	return not saved.is_empty() \
		and int(saved["map_seed"]) == run_state.map_seed \
		and str(saved.get("difficulty", "normal")) == run_state.difficulty \
		and int(saved["day"]) == run_state.clock.day

func save_day(path: String = "") -> int:
	var saved: Dictionary = _read_save(_path_or_default(path))
	return int(saved.get("day", 0))

func delete_save(path: String = "") -> void:
	var target_path: String = _path_or_default(path)
	var absolute_target: String = ProjectSettings.globalize_path(target_path)
	var absolute_temp: String = ProjectSettings.globalize_path(target_path + SAVE_TEMP_SUFFIX)
	var absolute_backup: String = ProjectSettings.globalize_path(target_path + SAVE_BACKUP_SUFFIX)
	if FileAccess.file_exists(target_path):
		DirAccess.remove_absolute(absolute_target)
	if FileAccess.file_exists(target_path + SAVE_TEMP_SUFFIX):
		DirAccess.remove_absolute(absolute_temp)
	if FileAccess.file_exists(target_path + SAVE_BACKUP_SUFFIX):
		DirAccess.remove_absolute(absolute_backup)

func _path_or_default(path: String) -> String:
	var target_path: String = path if not path.is_empty() else save_path
	# Automated runs must never inspect or mutate the player's one real slot.
	# Keep explicitly injected scenario/test paths usable, while resolving the
	# production path to a process-specific disposable slot in headless runs.
	if _is_automated_run() and target_path == SAVE_PATH:
		return _automated_save_path()
	return target_path

func _automated_save_path() -> String:
	return "user://automated_save_%d.json" % OS.get_process_id()

func _read_save(path: String) -> Dictionary:
	var backup_path: String = path + SAVE_BACKUP_SUFFIX
	if not FileAccess.file_exists(path) and FileAccess.file_exists(backup_path):
		var recovery_error: Error = DirAccess.rename_absolute(
			ProjectSettings.globalize_path(backup_path), ProjectSettings.globalize_path(path))
		if recovery_error != OK:
			push_warning("Game: cannot recover save backup: %s" % error_string(recovery_error))
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Game: unreadable save removed: %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		delete_save(path)
		return {}
	var parsed: Dictionary = SaveGame.from_json(file.get_as_text())
	file.close()
	var data: GameData = GameData.load_default()
	var restored: GameState = SaveGame.restore(data, parsed)
	if restored == null:
		push_warning("Game: corrupt or unsupported save removed")
		delete_save(path)
		return {}
	return parsed

func _is_automated_run() -> bool:
	var args: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for arg: String in args:
		if arg.begins_with("--scenario=") or arg.begins_with("--screenshot=") or arg.begins_with("--quit-frames="):
			return true
	return DisplayServer.get_name() == "headless"

func _transition(to_menu: bool, fresh_seed: bool = false) -> void:
	if transitioning or _quitting:
		return
	transitioning = true
	get_tree().paused = true
	if state:
		state.clock.set_paused(true)
		state.clock.locked = true
	var completed: Signal = screen_fade.fade_out()
	# Instant fades emit before returning; never await an already emitted signal.
	if not screen_fade.instant:
		await completed
	if _quitting:
		return
	show_menu = to_menu
	if fresh_seed:
		next_seed = posmod(randi(), 100000000) + 1
	state = null
	var reload_error: Error = get_tree().reload_current_scene()
	if reload_error == OK:
		await get_tree().scene_changed
	else:
		push_error("Cannot reload the game scene: %s" % error_string(reload_error))
	if _quitting:
		return
	screen_fade.fade_in()
	if not screen_fade.instant:
		await screen_fade.faded_in
	if _quitting:
		return
	get_tree().paused = false
	transitioning = false

func new_game(map_seed: int = DEFAULT_SEED, settings_path: String = GameSettings.PATH,
		difficulty: String = "") -> void:
	var data := GameData.load_default()
	var selected_difficulty: String = difficulty
	if selected_difficulty.is_empty():
		selected_difficulty = _pending_new_difficulty
	if selected_difficulty.is_empty():
		selected_difficulty = _pending_restart_difficulty
	if selected_difficulty.is_empty():
		selected_difficulty = GameSettings.load_difficulty(settings_path)
	_pending_new_difficulty = ""
	_pending_restart_difficulty = ""
	continued_extra = {}
	if not _pending_continue.is_empty():
		state = SaveGame.restore(data, _pending_continue)
		if state == null:
			push_warning("Game: Continue save could not be restored; starting a fresh game")
			delete_save()
		else:
			continued_extra = (_pending_continue.get("extra", {}) as Dictionary).duplicate(true)
		_pending_continue = {}
	else:
		state = GameState.new(data, map_seed, selected_difficulty)
	if state == null:
		state = GameState.new(data, map_seed, selected_difficulty)
	state.clock.set_speed(GameSettings.load_default_speed(settings_path))
	state.waves.enabled = true
	# Resolve the signal hub dynamically so this autoload script also compiles
	# when loaded by standalone SceneTree QA scripts before project autoloads.
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var events: Node = tree.root.get_node_or_null("Events") if tree else null
	if events:
		events.emit_signal("game_started", state)

func _process(delta: float) -> void:
	if state and not transitioning and not get_tree().paused:
		state.tick(delta)
