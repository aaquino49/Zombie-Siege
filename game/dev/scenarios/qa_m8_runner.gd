extends Node
## Bounded rendered M8 integration probes; scenario fixtures never change shipped data.

var checks: Array[String] = []
var failures: Array[String] = []
var out: String = ""
var main: Node

func frames(count: int = 6) -> void:
	for i: int in range(count):
		await get_tree().process_frame

func check(ok: bool, label: String) -> void:
	checks.append(label)
	print("M8 %s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures.append(label)

func capture(label: String) -> void:
	# Fixtures assign the day directly; update cached HUD text as well as the build bar.
	main.get_node("HUD")._refresh_day()
	main.get_node("HUD")._refresh_forecast()
	main.get_node("BuildBarLayer").refresh_if_stale()
	await frames(6)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(get_tree().root.get_texture().get_image().save_png(out.path_join(label + ".png")) == OK, "capture " + label)

func settle_transition() -> void:
	for i: int in range(360):
		if not Game.transitioning:
			return
		await get_tree().process_frame
	check(false, "scene transition completes within 360 frames")

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	get_tree().root.push_input(event)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	get_tree().root.push_input(event)
	await frames(2)

func run(scene: Node) -> void:
	main = scene
	var mode: String = "controls"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			out = arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--m8-mode="):
			mode = arg.trim_prefix("--m8-mode=")
	Game.state.clock.set_paused(true)
	main.get_node("Hints").set_enabled(false)
	main.get_node("World/Camera2D").set_process(false)
	if mode == "controls":
		await controls()
	elif mode == "scavenging":
		await scavenging()
	elif mode == "spitter":
		await spitter()
	var file := FileAccess.open(out.path_join(mode + "_flow.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty()}, "\t"))
	file.close()
	print("M8 FLOW %s: %d checks, %d failures" % [mode, checks.size(), failures.size()])
	Game.request_quit()

func controls() -> void:
	var state: GameState = Game.state
	state.clock.day = 20
	state.waves.enabled = false
	for kind: String in ["wood", "scrap"]:
		state.resources.add(kind, 10000)
	var bar: BuildBar = main.get_node("BuildBarLayer")
	bar.refresh_if_stale()
	await frames()
	for index: int in range(9):
		await key(KEY_F1 + index as Key)
		check((bar._hbox().get_child(index) as Button).button_pressed, "F%d selects button %d" % [index + 1, index + 1])
		await capture("hotkey_f%d" % (index + 1))
		await key(KEY_ESCAPE)
		check(bar._active_type == "", "Escape cancels F%d" % (index + 1))
	bar.show_info("radio_tower")
	check(bar._hotkey_for_type("radio_tower") == "" and bar._hbox().get_child(9).get_node_or_null("Hotkey") == null,
		"button 10 has no caption or info-card key")
	await capture("hotkey_radio_no_key")
	bar.hide_info()
	main.get_node("PauseMenu").open()
	for index: int in range(9):
		await key(KEY_F1 + index as Key)
		check(bar._active_type == "", "pause blocks F%d" % (index + 1))
	await capture("hotkeys_paused")
	main.get_node("PauseMenu/Dim/Center/Panel/Margin/Content/Buttons/Resume").pressed.emit()
	state.clock.set_paused(true)
	for index: int in range(3):
		await key(KEY_1 + index as Key)
		check(state.clock.speed == index + 1 and bar._active_type == "", "number %d sets speed" % (index + 1))
		await capture("speed_%d" % (index + 1))
	var hints: HintPanel = main.get_node("Hints")
	hints.set_enabled(true)
	hints.set_shown({"welcome": true, "farm": true, "night_soon": true, "ammo": true, "radio": true, "hungry": true, "scavenge": true})
	state.clock.day = 7
	state.clock.elapsed = 5.0
	state.clock.set_paused(false)
	hints._process(0.0)
	state.clock.set_paused(true)
	check(not hints.get_shown().has("spitters"), "night 7 has no spitter hint")
	await capture("morning7_no_spitters")
	state.clock.day = 8
	state.clock.set_paused(false)
	hints._process(0.0)
	state.clock.set_paused(true)
	check(hints.current_hint() == "spitters", "first spitter morning displays hint")
	await capture("morning8_spitter_hint")
	check("spitter" in main.get_node("HUD").night_forecast_label.text.to_lower(), "night 8 forecast includes a spitter")
	Game.save_path = "user://qa_m8_hint_%d.json" % OS.get_process_id()
	check(Game.save_now({"hints": hints.get_shown()}), "save one-shot hint")
	var saved_resources: Dictionary = SaveGame.capture(state)["resources"]
	main.get_node("PauseMenu").open()
	main.get_node("PauseMenu/Dim/Center/Panel/Margin/Content/Buttons/MainMenu").pressed.emit()
	await get_tree().scene_changed
	main = get_tree().current_scene
	await frames(35)
	await capture("continue_day8_menu")
	main.get_node("MainMenu/Dim/Center/Panel/Margin/Content/Buttons/Continue").pressed.emit()
	await get_tree().scene_changed
	main = get_tree().current_scene
	await settle_transition()
	Game.state.clock.set_paused(true)
	check(Game.state.clock.day == 8 and SaveGame.capture(Game.state)["resources"] == saved_resources, "Continue restores day and resources")
	hints = main.get_node("Hints")
	check(hints.get_shown().has("spitters") and hints.current_hint() != "spitters", "Continue keeps spitter hint seen without replay")
	await capture("continue_day8_no_hint")
	Game.delete_save()
	Game.save_path = Game.SAVE_PATH

func scavenging() -> void:
	var state: GameState = Game.state
	state.waves.enabled = false
	state.clock.day = 2
	state.clock.elapsed = 5.0
	var roster: RosterPanel = main.get_node("RosterPanel")
	roster.toggle()
	var selection: SelectionController = main.get_node("World/Selection")
	var person: Survivor = state.survivors.all()[0]
	state.set_job(person.uid, Survivor.Job.IDLE)
	selection.select_survivor(person.uid)
	var hints: HintPanel = main.get_node("Hints")
	hints.set_enabled(true)
	hints.set_shown({"welcome": true, "farm": true, "night_soon": true, "ammo": true})
	state.clock.phase = GameClock.Phase.NIGHT
	state.clock.elapsed = 5.0
	state.clock.phase_changed.emit(GameClock.Phase.NIGHT, 2)
	state.clock.set_paused(false)
	hints._process(0.0)
	state.clock.set_paused(true)
	check(not hints.get_shown().has("scavenge"), "scavenge hint suppressed at night without consuming it")
	await capture("scavenge_hint_night_suppressed")
	state.clock.phase = GameClock.Phase.DAY
	state.clock.elapsed = 40.0
	state.clock.phase_changed.emit(GameClock.Phase.DAY, 2)
	state.clock.set_paused(false)
	hints._process(0.0)
	state.clock.set_paused(true)
	check(not hints.get_shown().has("scavenge"), "scavenge hint suppressed after morning without consuming it")
	await capture("scavenge_hint_afternoon_suppressed")
	state.clock.elapsed = 5.0
	state.clock.set_paused(false)
	hints._process(0.0)
	state.clock.set_paused(true)
	check(hints.current_hint() == "scavenge", "day 2 sendable morning shows hint")
	await capture("scavenge_hint_day2")
	hints.set_enabled(false)
	await frames()
	check(roster._panel.get_global_rect().position.y >= 80.0, "roster begins below forecast")
	var config: Dictionary = state.data._expeditions
	for outcome: String in ["loot", "hurt", "lost", "newcomer"]:
		state.clock.phase = GameClock.Phase.DAY
		state.clock.elapsed = 5.0
		person = state.survivors.all()[0]
		state.set_job(person.uid, Survivor.Job.IDLE)
		selection.select_survivor(person.uid)
		for prefix: String in ["hurt", "lost"]:
			config[prefix + "_base"] = 1.0 if outcome == prefix else 0.0
			config[prefix + "_per_day"] = 0.0
			config[prefix + "_max"] = 1.0
		config["newcomer_chance"] = 1.0 if outcome == "newcomer" else 0.0
		if outcome == "newcomer":
			state.buildings.add("shelter", state.map.command_center_origin() + Vector2i(4, 0), true)
		await frames()
		main.get_node("InfoPanel")._scavenge_btn.pressed.emit()
		check(state.expeditions.is_running(person), outcome + ": send button starts run")
		await capture("scavenge_" + outcome + "_outbound")
		state.survivors.tick(1000.0, state.pathfinder, state.map)
		state.expeditions.tick(state, 0.0)
		check(person.away, outcome + ": reaches edge and goes away")
		await capture("scavenge_" + outcome + "_away")
		var count: int = state.survivors.count()
		state.clock.elapsed = float(state.data.balance("day_length")) - 0.1
		state.clock.advance(0.2)
		check(not person.away and state.expeditions.active().is_empty(), outcome + ": returns at nightfall")
		if outcome == "hurt":
			check(person.hp == person.max_hp / 2, "hurt halves HP")
		elif outcome == "lost":
			check(state.survivors.get_by_uid(person.uid) == null, "lost removes survivor")
		elif outcome == "newcomer":
			check(state.survivors.count() == count + 1, "newcomer occupies free bed")
		await capture("scavenge_" + outcome + "_return")
		state.clock.elapsed = float(state.data.balance("night_min_length")) - 0.1
		state.clock.advance(0.2)
		await frames()
		var rows: Array[Array] = DawnReportPanel.report_rows(state.last_dawn_report)
		check(rows.any(func(row: Array) -> bool: return str(row[0]).begins_with("Scavenging (")), outcome + ": named Dawn Report row")
		await capture("scavenge_" + outcome + "_dawn")
		main.get_node("DawnReport/Center/Panel/Margin/Content/Buttons/Continue").pressed.emit()
		state.clock.set_paused(true)
		check(state.clock.phase == GameClock.Phase.DAY and not state.clock.locked, outcome + ": Continue starts next day")
		await capture("scavenge_" + outcome + "_next_day")
	# Record the eligibility reasons through the real selected-survivor panel.
	person = state.survivors.all()[0]
	selection.select_survivor(person.uid)
	for reason: String in ["guard", "sheltered", "not morning", "run limit"]:
		state.clock.elapsed = 5.0
		person.job = Survivor.Job.GUARD if reason == "guard" else Survivor.Job.IDLE
		person.sheltered = reason == "sheltered"
		state.expeditions._sent_today[state.clock.day] = 1 if reason == "run limit" else 0
		if reason == "not morning":
			state.clock.elapsed = 40.0
		if reason != "sheltered":
			selection.select_survivor(person.uid)
		await frames()
		var button: Button = roster._vbox.get_child(0).get_child(3) as Button
		check(button.disabled and button.tooltip_text == ScavengeToast.reason_text(reason), "disabled reason: " + reason)
		await capture("scavenge_disabled_" + reason.replace(" ", "_"))
	person.sheltered = false
	var next_day: int = state.clock.day
	Game.save_path = "user://qa_m8_scavenge_%d.json" % OS.get_process_id()
	check(Game.save_now({"hints": {"scavenge": true}}), "save next day after scavenging outcomes")
	var expected: Dictionary = SaveGame.capture(state)
	main.get_node("PauseMenu").open()
	main.get_node("PauseMenu/Dim/Center/Panel/Margin/Content/Buttons/MainMenu").pressed.emit()
	await get_tree().scene_changed
	main = get_tree().current_scene
	await frames(35)
	await capture("scavenge_next_day_menu_continue")
	main.get_node("MainMenu/Dim/Center/Panel/Margin/Content/Buttons/Continue").pressed.emit()
	await get_tree().scene_changed
	main = get_tree().current_scene
	await settle_transition()
	state = Game.state
	state.clock.set_paused(true)
	var actual: Dictionary = SaveGame.capture(state)
	check(state.clock.day == next_day and actual["resources"] == expected["resources"] and actual["survivors"] == expected["survivors"],
		"real Continue next day preserves scavenging loot, lost survivor and newcomer")
	await capture("scavenge_next_day_restored")
	Game.delete_save()
	Game.save_path = Game.SAVE_PATH
	hints = main.get_node("Hints")
	roster = main.get_node("RosterPanel")
	roster.toggle()
	state.clock.day = 2
	state.clock.elapsed = 5.0
	for s: Survivor in state.survivors.all():
		s.job = Survivor.Job.GUARD
	roster.refresh()
	check(state.survivors.all().all(func(s: Survivor) -> bool: return state.expeditions.can_send(s) != ""), "all-guards fixture has zero sendable survivors")
	hints.set_enabled(true)
	hints.set_shown({"welcome": true, "farm": true, "night_soon": true, "ammo": true})
	state.clock.set_paused(false)
	hints._process(0.0)
	state.clock.set_paused(true)
	check(hints.current_hint() != "scavenge", "hint suppressed when all survivors are guards and no run is sendable")
	await capture("scavenge_hint_all_guards")

func spitter() -> void:
	preload("res://dev/scenarios/spitter.gd").setup(main)
	var state: GameState = Game.state
	main.get_node("BuildBarLayer").refresh_if_stale()
	await capture("spitter_night_sprite_glob_splash")
	var layer: ZombieLayer = main.get_node("World/YSort/Zombies")
	var z: Zombie = state.zombies.all()[0]
	var sprite: AnimatedSprite2D = layer._active_sprites[z.uid]
	check(sprite.sprite_frames == load("res://assets/pixel/frames/zombie_spitter.tres"), "real spitter SpriteFrames")
	check((sprite.get_child(0) as HpBar).always_show and layer._night, "night rim and persistent HP bar")
	var turret: Building = state.buildings.all_of_type("turret")[0]
	state.projectiles.clear()
	z.pos = Grid.tile_to_world(turret.origin + Vector2i(3, 0))
	z.spit_timer = 2.0
	ZombieAI.tick(state, 0.01)
	check(not state.projectiles.globs.is_empty() and z.target_building_uid == turret.uid, "AI fires at turret from three tiles")
	check(str(sprite.animation).begins_with("spit_"), "spit event selects directional animation")
	await capture("spitter_spit_animation")
	for index: int in range(sprite.sprite_frames.get_frame_count(sprite.animation)):
		sprite.set_frame_and_progress(index, 0.0)
		await capture("spitter_spit_frame_%d" % index)
	var hp: int = turret.hp
	state.projectiles.tick(state, 3.0)
	check(turret.hp < hp, "ranged acid damages turret")
	var tower: Building = state.buildings.add("watchtower", turret.origin + Vector2i(0, 5), true)
	z.pos = Grid.tile_to_world(tower.origin + Vector2i(3, 0))
	z.defence_scan_timer = 0.0
	z.defence_uid = 0
	z.spit_timer = 2.0
	ZombieAI.tick(state, 0.01)
	ZombieAI.tick(state, 2.0)
	hp = tower.hp
	state.projectiles.tick(state, 3.0)
	check(tower.hp < hp and z.target_building_uid == tower.uid, "ranged acid damages watchtower")
	main.get_node("World/Camera2D").position = tower.center_world() + Vector2(64, 0)
	await capture("spitter_watchtower_damage")
	state.damage_zombie(z, z.hp)
	check(not layer._death_sprites.is_empty(), "spitter death animation allocated")
	await capture("spitter_death_fx")
	var fx: CombatFx = main.get_node("World/CombatFx")
	state.clock.set_paused(false)
	fx._process(0.6)
	state.clock.set_paused(true)
	check(fx._corpses.any(func(body: Sprite2D) -> bool: return body.visible), "death leaves a corpse")
	await capture("spitter_corpse_stain")
