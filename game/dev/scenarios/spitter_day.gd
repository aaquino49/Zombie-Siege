extends RefCounted
## Daylight comparison crop for the spitter capture.

const SPITTER_SCENARIO = preload("res://dev/scenarios/spitter.gd")

static func setup(main: Node) -> void:
	SPITTER_SCENARIO.setup_day(main)
