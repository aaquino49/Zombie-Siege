class_name TutorialHints extends RefCounted

var enabled: bool = true
var shown: Dictionary = {}
var day_time: float = 0.0

var _last_day: int = 0
var _day_initialized: bool = false

func check(state: GameState, delta: float) -> String:
	if not _day_initialized:
		_last_day = state.clock.day
		_day_initialized = true
	elif state.clock.day != _last_day:
		_last_day = state.clock.day
		day_time = 0.0

	if state.clock.phase == GameClock.Phase.DAY:
		day_time += delta

	if not enabled or state.game_over or state.clock.phase != GameClock.Phase.DAY:
		return ""

	if not shown.has("welcome") and state.clock.day == 1:
		shown["welcome"] = true
		return "welcome"

	if not shown.has("farm") and state.clock.day == 1 and day_time >= 20.0 and state.buildings.count_of("farm") == 0:
		shown["farm"] = true
		return "farm"

	if not shown.has("night_soon") and state.clock.day == 1 and state.clock.time_left() <= 30.0:
		shown["night_soon"] = true
		return "night_soon"

	var workshop_data: Dictionary = state.data.get_building("workshop")
	var workshop_unlock: int = int(workshop_data.get("unlock_day", 0))
	if not shown.has("ammo") and state.clock.day >= workshop_unlock and state.buildings.count_of("workshop") == 0 and state.resources.get_amount("ammo") < 30:
		shown["ammo"] = true
		return "ammo"

	var morning_cutoff: float = float(state.data.balance("day_length")) * float(state.data.expeditions().get("morning_fraction", 0.4))
	if not shown.has("scavenge") and state.clock.day >= 2 and state.clock.phase == GameClock.Phase.DAY and state.clock.elapsed < morning_cutoff:
		for s: Survivor in state.survivors.all():
			if state.expeditions.can_send(s) == "":
				shown["scavenge"] = true
				return "scavenge"

	if not shown.has("hungry"):
		var has_hungry: bool = false
		for s: Survivor in state.survivors.all():
			if s.is_hungry():
				has_hungry = true
				break
		if has_hungry:
			shown["hungry"] = true
			return "hungry"

	var radio_data: Dictionary = state.data.get_building("radio_tower")
	var radio_unlock: int = int(radio_data.get("unlock_day", 0))
	if not shown.has("radio") and state.clock.day >= radio_unlock and state.buildings.count_of("radio_tower") == 0:
		shown["radio"] = true
		return "radio"

	var tonight: Dictionary = WaveSpawner.forecast(state.data, state.clock.day, state.difficulty_multipliers)
	if not shown.has("spitters") and int(tonight.get("spitter", 0)) > 0:
		shown["spitters"] = true
		return "spitters"

	if not shown.has("research"):
		for lab: Building in state.buildings.all_of_type("field_lab"):
			if lab.complete:
				shown["research"] = true
				return "research"

	if not shown.has("morale"):
		for s: Survivor in state.survivors.all():
			var band_id: String = str(Morale.band(state, s).get("id", "steady"))
			if band_id == "low" or band_id == "breaking":
				shown["morale"] = true
				return "morale"

	return ""

static func text(id: String, data: GameData = null) -> String:
	match id:
		"welcome":
			return "Day 1. Gather, build and farm by day. Zombies attack at night. Press B to build."
		"farm":
			return "Every survivor eats 1 food each dawn. Build a Farm and give it Farmers (R opens the roster)."
		"night_soon":
			return "Night is coming. Zombies walk in from the map edge. Wall in the Command Center and keep a Guard posted."
		"ammo":
			return "Guards and turrets spend 1 ammo per shot. Build a Workshop and assign a Crafter to turn scrap into ammo."
		"scavenge":
			return "Send a survivor scavenging for supplies. They're back at nightfall, but it's risky."
		"hungry":
			return "Hungry survivors work at half speed and leave after 2 hungry days. Build more Farms."
		"radio":
			return "The Radio Tower is unlocked. Build it and survive night 20 to call the rescue helicopter."
		"spitters":
			var game_data: GameData = data if data != null else GameData.load_default()
			var range_tiles: int = int(game_data.get_zombie("spitter")["ranged"]["range_tiles"])
			var tile_word: String = "tile" if range_tiles == 1 else "tiles"
			return "Spitters come tonight. They stop %d %s out and spit acid at turrets and watchtowers. Post Guards and place turrets so they cover each other." % [range_tiles, tile_word]
		"research":
			return "Your Field Lab is ready. Make someone a Researcher, then press T to choose what they study."
		"morale":
			return "Morale is slipping. Low and Breaking survivors work slower and guards miss shots. Build a Campfire, keep beds and food up, or hold a Feast at the Command Center."
		_:
			return ""
