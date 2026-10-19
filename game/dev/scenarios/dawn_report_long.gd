extends RefCounted
## Synthetic worst-case casualty lists without ending the running game.

static func report() -> Dictionary:
	return {
		"day": 2, "night": 1, "zombies_killed": 25,
		"survivors_killed": ["Alexandra", "Benjamin", "Charlotte", "Dominic", "Eleanor", "Frederick"],
		"buildings_destroyed": ["Wooden Wall", "Reinforced Wall", "Watchtower", "Workshop", "Shelter", "Storage"],
		"buildings_damaged": 6, "cc_damage": 40, "food_eaten": 12,
		"arrived": ["Alex"], "unlocked": ["Storage", "Watchtower", "Workshop"],
		"objective": DawnReport.objective_text(2, 20, "missing", 8),
	}

static func setup(main: Node) -> void:
	Game.state.waves.enabled = false
	var panel: DawnReportPanel = main.get_node("DawnReport")
	panel._show_report(report())
	var camera: Camera2D = main.get_node("World/Camera2D")
	camera.position = Game.state.buildings.all_of_type("command_center")[0].center_world()
