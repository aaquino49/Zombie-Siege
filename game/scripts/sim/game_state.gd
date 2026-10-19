class_name GameState extends RefCounted

signal dawn_processed(report: Dictionary)
signal game_lost(reason: String)
signal game_won

signal resource_delivered(kind: String, amount: int, world_pos: Vector2)
signal shot_fired(from: Vector2, to: Vector2, is_turret: bool)
signal spit_fired(from: Vector2, to: Vector2)
signal acid_hit(pos: Vector2)
signal zombie_killed(z: Zombie)
signal survivor_killed(s: Survivor)
signal building_destroyed(b: Building)
signal command_center_destroyed
signal building_replaced(old_uid: int, replacement: Building)
signal zombie_hit(z: Zombie)
signal building_damaged(b: Building, amount: int)
signal survivor_damaged(s: Survivor, amount: int)
signal survivor_unsheltered(s: Survivor)

var data: GameData
var map: WorldMap
var map_seed: int
var difficulty: String = "normal"
var difficulty_multipliers: Dictionary = {}
var resources: ResourceStore
var tech: TechTree
var clock: GameClock
var buildings: BuildingStore
var pathfinder: Pathfinder
var survivors: SurvivorStore
var rng: RandomNumberGenerator
var combat_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var last_feast_day: int = 0
var morale_snapshot: Dictionary = {}
var last_dawn_report: Dictionary = {}
var night_log: NightLog
var _weather_day_cache_key: Array[int] = []
var _weather_day_cache_result: String = ""
var _weather_night_cache_key: Array[int] = []
var _weather_night_cache_result: String = ""

var flow: FlowField
var waves: WaveSpawner
var expeditions: Expeditions
var projectiles: Projectiles = Projectiles.new()
var zombies: ZombieStore
var zombies_killed: int = 0
var survivors_lost: int = 0
var buildings_lost: int = 0
var cc_destroyed: bool = false
var game_over: bool = false
var won: bool = false
var endless: bool = false
var lose_reason: String = ""
var time_played: float = 0.0
var buildings_built: int = 0
var survivors_left: int = 0

func _init(game_data: GameData, p_seed: int, p_difficulty: String = "normal") -> void:
	data = game_data
	map_seed = p_seed
	difficulty_multipliers = data.difficulty_config(p_difficulty)
	difficulty = p_difficulty if p_difficulty in ["easy", "normal", "hard"] else "normal"
	resources = ResourceStore.new(data, difficulty_multipliers)
	tech = TechTree.new(data.tech_config())
	var tech_state_ref: WeakRef = weakref(self)
	tech.game_over_provider = func() -> bool:
		var live_state: GameState = tech_state_ref.get_ref() as GameState
		return live_state == null or live_state.game_over
	map = WorldMap.new(data, map_seed)
	clock = GameClock.new(data)
	night_log = NightLog.new()
	# Capture a weak reference: state owns clock, so capturing self forms a cycle.
	var state_ref: WeakRef = weakref(self)
	clock.night_end_check = func() -> bool:
		var state: GameState = state_ref.get_ref() as GameState
		return state == null or state.hostiles_remaining() == 0
	buildings = BuildingStore.new(data, map)
	buildings.tech = tech
	buildings.building_completed.connect(_on_building_completed)
	flow = FlowField.new(map, data, buildings)
	zombies = ZombieStore.new(data)
	waves = WaveSpawner.new(self)
	expeditions = Expeditions.new(self)
	
	map.generate()
	buildings.add("command_center", map.command_center_origin(), true)
	
	pathfinder = Pathfinder.new(map)
	survivors = SurvivorStore.new(data)
	
	var start_count: int = data.balance("start_survivors", 4)
	var names: Array = data.balance("survivor_names", [])
	var variants: Array = data.balance("survivor_variants", ["blue"])
	
	rng = RandomNumberGenerator.new()
	rng.seed = map_seed + 2
	var start_rng := RandomNumberGenerator.new()
	start_rng.seed = map_seed + 1
	var names_shuffled := names.duplicate()
	for i in range(names_shuffled.size() - 1, 0, -1):
		var j := start_rng.randi() % (i + 1)
		var tmp: String = names_shuffled[i]
		names_shuffled[i] = names_shuffled[j]
		names_shuffled[j] = tmp
		
	var ring_tiles: Array[Vector2i] = cc_ring_tiles()

	for i in range(min(start_count, ring_tiles.size())):
		var s_name: String = "Survivor"
		if names_shuffled.size() > 0:
			s_name = names_shuffled[i % names_shuffled.size()]
		var variant: String = "blue"
		if variants.size() > 0:
			variant = variants[i % variants.size()]
		survivors.add(s_name, variant, ring_tiles[i])
		
	var start_jobs: Array = data.balance("start_jobs", [])
	var all_s := survivors.all()
	for i in range(all_s.size()):
		var j_name: String = "idle"
		if i < start_jobs.size():
			j_name = start_jobs[i]
		all_s[i].job = Survivor.job_from_name(j_name)
		if j_name.begins_with("gatherer_"):
			all_s[i].gather_kind = j_name.trim_prefix("gatherer_")
	Morale.on_new_game(self)

	clock.dawn.connect(_on_dawn)
	clock.phase_changed.connect(_on_phase_changed)

func hostiles_remaining() -> int:
	return zombies.count() + waves.pending()

func weather_day() -> String:
	var key: Array[int] = [map_seed, clock.day, data.weather_config().hash()]
	if key != _weather_day_cache_key:
		_weather_day_cache_key = key
		_weather_day_cache_result = Weather.day_weather(data, map_seed, clock.day)
	return _weather_day_cache_result

func weather_night() -> String:
	var key: Array[int] = [map_seed, clock.day, data.weather_config().hash()]
	if key != _weather_night_cache_key:
		_weather_night_cache_key = key
		_weather_night_cache_result = Weather.night_weather(data, map_seed, clock.day)
	return _weather_night_cache_result

func _on_phase_changed(phase: int, _day: int) -> void:
	if phase == GameClock.Phase.NIGHT:
		combat_rng.seed = hash([map_seed, clock.day, "combat"])
		night_log.begin(self)
		for s: Survivor in survivors.all():
			s.reset_shelter_exclusions()
	elif phase == GameClock.Phase.DAY:
		for s: Survivor in survivors.all():
			s.shelter_night = 0
			s.reset_shelter_exclusions()

func spawn_zombie(type_id: String, world_pos: Vector2) -> Zombie:
	return zombies.add(type_id, world_pos, float(difficulty_multipliers.get("zombie_hp_mult", 1.0)))

func damage_zombie(z: Zombie, amount: int) -> bool:
	if zombies.damage(z.uid, amount):
		zombies_killed += 1
		zombie_killed.emit(z)
		return true
	if zombies.get_by_uid(z.uid) != null:
		zombie_hit.emit(z)
	return false

func damage_building(b: Building, amount: int) -> void:
	if amount > 0:
		amount = maxi(1, roundi(float(amount) * tech.mult("structure_damage_taken")))
	var lost: int = mini(amount, maxi(b.hp, 0))
	if lost > 0:
		night_log.on_building_damaged(b, lost)
		building_damaged.emit(b, amount)

	b.hp -= amount
	if b.hp <= 0:
		if b.type_id == "command_center":
			b.hp = 0
			if not cc_destroyed:
				cc_destroyed = true
				command_center_destroyed.emit()
		else:
			var dname: String = str(data.get_building(b.type_id).get("name", b.type_id))
			night_log.on_building_destroyed(b, dname)
			buildings.remove(b.uid)
			buildings_lost += 1
			building_destroyed.emit(b)

func damage_survivor(s: Survivor, amount: int) -> void:
	survivor_damaged.emit(s, amount)
	s.hp -= amount
	if s.hp <= 0:
		night_log.on_survivor_killed(s)
		Morale.on_survivor_lost(self, s)
		survivors.remove(s.uid)
		survivors_lost += 1
		survivor_killed.emit(s)

func _on_dawn(_day: int) -> void:
	Morale.begin_dawn(self)
	for s: Survivor in survivors.all():
		s.shelter_night = 0
		s.reset_shelter_exclusions()
	var zombies_fled: int = zombies.count()
	for z: Zombie in zombies.all():
		zombies.remove(z.uid)
	waves.clear_pending()
	projectiles.clear()
	var report: Dictionary = DawnRules.process(self)
	tech.apply_dawn_heal(self)
	report["research"] = tech.take_dawn_report(self)
	report["scavenging"] = expeditions.take_dawn_report()
	report["zombies_fled"] = zombies_fled
	
	var summary: Dictionary = night_log.summary(self)
	for k: String in summary.keys():
		report[k] = summary[k]
	Morale.end_dawn(self, report)
	tech.game_over = game_over
		
	var building_ids: Array = data.building_ids()
	var unlocked_ids: Array[String] = []
	for id: String in building_ids:
		var b_data: Dictionary = data.get_building(id)
		if int(b_data.get("unlock_day", 999)) == clock.day:
			unlocked_ids.append(id)
	unlocked_ids.sort()
	
	var unlocked: Array[String] = []
	for id: String in unlocked_ids:
		unlocked.append(str(data.get_building(id).get("name", id)))
	report["unlocked"] = unlocked
	
	var tower_state: String = "none"
	if radio_tower_complete():
		tower_state = "complete"
	elif buildings.count_of("radio_tower") > 0:
		tower_state = "building"
		
	var nights_to_win: int = int(data.balance("nights_to_win"))
	var tower_unlock_day: int = int(data.get_building("radio_tower").get("unlock_day", 0))
	report["objective"] = DawnReport.objective_text(clock.day, nights_to_win, tower_state, tower_unlock_day, endless)
	
	var had_won: bool = won
	_check_lose()
	_check_win()
	if won and not had_won:
		Morale.add_mood_all(self, "rescued")
		Morale.refresh_report(self, report)
	last_dawn_report = report
	dawn_processed.emit(report)

func radio_tower_complete() -> bool:
	for b: Building in buildings.all():
		if b.type_id == "radio_tower" and b.complete:
			return true
	return false

func _check_win() -> void:
	if game_over or endless:
		return
	if radio_tower_complete() and (clock.day - 1) >= int(data.balance("nights_to_win")):
		won = true
		game_over = true
		tech.game_over = true
		game_won.emit()

func _on_building_completed(b: Building) -> void:
	if b.type_id != "command_center":
		buildings_built += 1
	if b.type_id == "radio_tower":
		Morale.add_mood_all(self, "radio_tower")

func stats() -> Dictionary:
	return {"nights_survived": clock.day - 1, "zombies_killed": zombies_killed,
		"survivors_lost": survivors_lost + survivors_left,
		"buildings_built": buildings_built, "time_played": time_played}

func _check_lose() -> void:
	if game_over or (not cc_destroyed and survivors.count() > 0):
		return
	game_over = true
	tech.game_over = true
	lose_reason = "command_center" if cc_destroyed else "survivors"
	game_lost.emit(lose_reason)

func cc_ring_tiles() -> Array[Vector2i]:
	var cc_origin: Vector2i = map.command_center_origin()
	var ring_tiles: Array[Vector2i] = []
	for y in range(cc_origin.y - 1, cc_origin.y + 3):
		for x in range(cc_origin.x - 1, cc_origin.x + 3):
			if x >= cc_origin.x and x < cc_origin.x + 2 and y >= cc_origin.y and y < cc_origin.y + 2:
				continue
			var t := Vector2i(x, y)
			if map.is_passable(t):
				ring_tiles.append(t)
				
	ring_tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return ring_tiles

func try_place(type_id: String, origin: Vector2i) -> int:
	var r := Placement.check(self, type_id, origin)
	if r == Placement.Result.OK:
		var b_data := data.get_building(type_id)
		var cost: Dictionary = b_data.get("cost", {})
		resources.spend(cost)
		var build_time := float(b_data.get("build_time", 0.0))
		buildings.add(type_id, origin, build_time <= 0.0)
	return r

func try_upgrade(uid: int) -> int:
	var old: Building = buildings.get_by_uid(uid)
	if old == null or not old.complete:
		return Placement.Result.NOT_UPGRADABLE
	var target: String = Placement.upgrade_target(data, old.type_id)
	if target == "":
		return Placement.Result.NOT_UPGRADABLE
	var target_data: Dictionary = data.get_building(target)
	if int(target_data.get("unlock_day", 0)) > clock.day:
		return Placement.Result.LOCKED
	var cost: Dictionary = target_data.get("cost", {})
	if not resources.can_afford(cost):
		return Placement.Result.UNAFFORDABLE
	resources.spend(cost)
	# Map listeners only mark views/pathfinding dirty; no simulation runs
	# between removal and addition in this synchronous command.
	buildings.remove(old.uid)
	var replacement: Building = buildings.add(target, old.origin, float(target_data.get("build_time", 0.0)) <= 0.0)
	replacement.upgraded_from = old.type_id
	building_replaced.emit(old.uid, replacement)
	return Placement.Result.OK

func set_job(uid: int, job: int, gather_kind: String = "") -> bool:
	var s: Survivor = survivors.get_by_uid(uid)
	if s == null:
		return false
	if gather_kind != "":
		if gather_kind != "wood" and gather_kind != "scrap":
			return false
	var next_kind: String = s.gather_kind if gather_kind == "" else gather_kind
	if s.job == job and s.gather_kind == next_kind:
		return true
	if s.job == Survivor.Job.GUARD:
		GuardJob.leave_post(self, s)
	s.gather_kind = next_kind
	if s.carry_amount > 0:
		resources.add(s.carry_kind, s.carry_amount)
		s.carry_amount = 0
		s.carry_kind = ""
	s.job = job
	s.path.clear()
	s.work_uid = 0
	s.work_acc = 0.0
	s.job_timer = 0.0
	s.activity = Survivor.Activity.SHELTERED if s.sheltered else Survivor.Activity.IDLE
	s.work_tile = Vector2i(-1, -1)
	return true

func cancel_building(uid: int) -> bool:
	var b := buildings.get_by_uid(uid)
	if b == null or b.type_id == "command_center" or b.complete:
		return false
	var b_data := data.get_building(b.type_id)
	var cost: Dictionary = b_data.get("cost", {})
	resources.refund(cost, Construction.refund_fraction(data, b))
	buildings.remove(uid)
	if b.upgraded_from != "":
		var restored: Building = buildings.add(b.upgraded_from, b.origin, true)
		building_replaced.emit(uid, restored)
	return true

func order_move(uid: int, t: Vector2i) -> bool:
	var s := survivors.get_by_uid(uid)
	if not s or s.sheltered or s.on_tower or s.refusing or s.day_off:
		return false
	var p := pathfinder.find_path(s.tile(), t)
	if p.is_empty():
		return false
	s.target = t
	s.path = p
	return true

func tick(delta: float) -> void:
	var remaining: float = clock.scale(delta)

	while remaining > 0.0:
		waves.tick(self, remaining)
		var left := clock.time_to_boundary()
		var step: float = remaining
		if left > 0.0 and left < remaining:
			step = left

		# Split large ticks at scheduled spawns so they cannot arrive late.
		var spawn_left: float = waves.time_left(clock)
		if spawn_left > 0.0:
			step = minf(step, spawn_left)

		survivors.evict_from_solid(map)
		Jobs.tick(self, step)
		Combat.tick_turrets(self, step)
		survivors.tick(step, pathfinder, map)
		expeditions.tick(self, step)
		projectiles.tick(self, step)
		ZombieAI.tick(self, step)
		time_played += step
		clock.advance(step)

		remaining -= step
		if clock.paused:
			break
	_check_lose()


