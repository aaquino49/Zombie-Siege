extends SceneTree
## Live regression: run windowed with --script res://dev/scenarios/qa_audio_teardown.gd
## -- --quit-frames=10000000 --audio-report=<path> --quit-mode=menu|window.

var checks: Array[Dictionary] = []
var failures: int = 0
var report_path: String = ""
var quit_mode: String = "menu"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--audio-report="):
			report_path = arg.trim_prefix("--audio-report=")
		elif arg.begins_with("--quit-mode="):
			quit_mode = arg.trim_prefix("--quit-mode=")
	_run.call_deferred()

func _check(ok: bool, description: String) -> void:
	checks.append({"passed": ok, "description": description})
	if not ok:
		failures += 1
	print("%s: %s" % ["PASS" if ok else "FAIL", description])

func _wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func _released(audio: AudioManager) -> void:
	for player: Node in audio.get_children():
		if player is AudioStreamPlayer:
			_check(player.stream == null and not player.playing, "Released " + player.name)
	_check(audio.active_music_stream == null and audio._streams.is_empty(), "Released music reference and cache")
	_check(audio._music_tween == null, "Released crossfade tween")

func _phase(audio: AudioManager, state: GameState, phase: int) -> void:
	var outgoing: AudioStreamPlayer = audio._active_music_player
	state.clock.phase = phase
	state.clock.phase_changed.emit(phase, state.clock.day)
	var incoming: AudioStreamPlayer = audio._active_music_player
	_check(incoming != outgoing and incoming.playing and outgoing.playing, "Both music players play during crossfade")
	_check(audio._music_tween != null and audio._music_tween.is_running(), "Crossfade tween is running")
	await _wait(1.0)
	_check(incoming.volume_db > -35.0 and incoming.volume_db < -5.0, "Incoming volume rises during crossfade")
	_check(outgoing.volume_db < -5.0 and outgoing.volume_db > -35.0, "Outgoing volume falls during crossfade")
	# Timer wall time can exceed tween time during the first shader compilation;
	# wait for the real completion signal rather than assuming a frame rate.
	await audio._music_tween.finished
	await _wait(0.05)
	_check(incoming.playing and not outgoing.playing, "Crossfade finishes with only incoming music playing")
	_check(is_equal_approx(incoming.volume_db, 0.0), "Incoming music reaches full player volume")
	_check(incoming.get_playback_position() > 0.1, "Music playback position advances")
	var peak: float = AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index("Music"), 0)
	_check(peak > -70.0, "Music mixer output is non-silent (%.2f dB)" % peak)

func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	var game: Node = root.get_node("Game")
	var audio: AudioManager = main.get_node("Audio")
	var state: GameState = game.state
	state.waves.enabled = false
	var original_volumes: Dictionary = AudioSettings.load_volumes()
	AudioSettings.apply({"Master": 0.8, "SFX": 0.8, "Music": 0.8})
	await _wait(0.2)
	_check(audio._active_music_player.playing and audio.active_music_name == "day_loop", "Day music plays at launch")
	await _phase(audio, state, GameClock.Phase.NIGHT)
	await _phase(audio, state, GameClock.Phase.DAY)
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, 1)
	var interrupted: Tween = audio._music_tween
	_check(audio.play("gunshot"), "SFX plays alongside the interrupted music fade")
	_check(audio._sfx_pools["gunshot"][0].playing, "SFX player is actually playing")
	audio.unbind()
	_released(audio)
	_check(not interrupted.is_valid(), "Unbind kills an in-progress live crossfade")
	await _wait(0.1)
	_check(not game._has_pending_audio(audio._playbacks), "Mixer releases stopped playback objects after unbind")
	audio.bind(state, main.get_node("World/BuildMode"))
	_check(audio._active_music_player.playing and audio.active_music_name == "night_loop", "Rebind restores current-phase music")
	_check(audio.play("gunshot"), "Rebind restores SFX playback")
	await _phase(audio, state, GameClock.Phase.DAY)
	# Quit while both Vorbis players and the crossfade are live, including a
	# replaced tween from a rapid day/night/day switch.
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, 1)
	state.clock.phase_changed.emit(GameClock.Phase.DAY, 2)
	AudioSettings.apply(original_volumes)
	if failures > 0:
		game.request_quit(1)
	elif quit_mode == "window":
		game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	else:
		main.get_node("MainMenu/Dim/Center/Panel/Margin/Content/Buttons/Quit").pressed.emit()
	_released(audio)
	_check(not audio.play("ui_click"), "Late UI sound is rejected during shutdown")
	if not report_path.is_empty():
		var report: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
		report.store_string(JSON.stringify({"passed": failures == 0, "quit_mode": quit_mode, "checks": checks}, "\t"))
		report.close()
	print("QA AUDIO: %d checks, %d failures" % [checks.size(), failures])
