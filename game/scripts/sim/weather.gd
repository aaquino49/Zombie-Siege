class_name Weather extends RefCounted

static func day_weather(data: GameData, map_seed: int, day: int) -> String:
	var rain: Dictionary = data.weather_config().get("rain", {})
	if day < int(rain["first_day"]):
		return "clear"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([map_seed, day, "rain"])
	return "rain" if rng.randf() < float(rain["chance"]) else "clear"

static func night_weather(data: GameData, map_seed: int, night: int) -> String:
	var fog: Dictionary = data.weather_config().get("fog", {})
	if night < int(fog["first_night"]):
		return "clear"
	var rng := RandomNumberGenerator.new()
	var previous_weather: String = "clear"
	var first_night: int = int(fog["first_night"])
	var no_repeat: bool = bool(fog["no_repeat"])
	var never_final: bool = bool(fog["never_final"])
	var chance: float = float(fog["chance"])
	for current_night: int in range(first_night, night + 1):
		if never_final and current_night == data.final_night():
			previous_weather = "clear"
			continue
		if no_repeat and current_night > 1 and previous_weather == "fog":
			previous_weather = "clear"
			continue
		rng.seed = hash([map_seed, current_night, "fog"])
		previous_weather = "fog" if rng.randf() < chance else "clear"
	return previous_weather

static func range_delta_px(state: GameState) -> float:
	if state.clock.phase != GameClock.Phase.NIGHT or state.weather_night() != "fog":
		return 0.0
	var fog: Dictionary = state.data.weather_config().get("fog", {})
	return float(fog["range_delta_tiles"]) * Grid.TILE
