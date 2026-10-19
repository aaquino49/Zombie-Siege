extends RefCounted
## QA: display the forecast alongside the existing hint, shelter warning and alarm.

static func setup(main: Node) -> void:
	preload("res://dev/scenarios/night_forecast.gd").setup(main)
	var hud: CanvasLayer = main.get_node("HUD") as CanvasLayer
	hud.call("_on_survivor_unsheltered", Game.state.survivors.all()[0])
	var hints: HintPanel = main.get_node("Hints") as HintPanel
	hints.set_enabled(true)
	Game.state.resources.take("ammo", 20)
	hints.show_hint("ammo")
	var alarm: CCAlarm = main.get_node("CCAlarm") as CCAlarm
	alarm.force_trigger()
	alarm.set_process(false)
