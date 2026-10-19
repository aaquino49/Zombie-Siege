extends RefCounted
## T-109 QA: visible info/roster panels, state swatches and the job dropdown.

static func setup(main: Node) -> void:
	Game.state.waves.enabled = false
	Game.state.clock.set_paused(true)
	var roster: RosterPanel = main.get_node("RosterPanel") as RosterPanel
	roster.toggle()
	var selection: SelectionController = main.get_node("World/Selection") as SelectionController
	var survivor: Survivor = Game.state.survivors.all()[0]
	survivor.max_hp = 120
	survivor.hp = 120
	selection.select_survivor(survivor.uid)
	var bar: BuildBar = main.get_node("BuildBarLayer") as BuildBar
	bar.set_active_type("farm")
	var layer := CanvasLayer.new()
	layer.layer = 20
	main.add_child(layer)
	var row := HBoxContainer.new()
	row.position = Vector2(320, 340)
	row.add_theme_constant_override("separation", 8)
	layer.add_child(row)
	for state: String in ["normal", "hover", "pressed", "toggle", "disabled"]:
		var button := Button.new()
		button.text = state
		button.custom_minimum_size = Vector2(128, 48)
		if state == "hover":
			# A fixed swatch avoids a capture depending on the desktop pointer.
			button.add_theme_stylebox_override("normal", button.get_theme_stylebox("hover"))
		elif state in ["pressed", "toggle"]:
			button.toggle_mode = true
			button.button_pressed = true
			if state == "toggle":
				button.theme_type_variation = &"ToggleButton"
		elif state == "disabled":
			button.disabled = true
		row.add_child(button)
	if "--qa-popup=true" in OS.get_cmdline_user_args():
		main.get_tree().create_timer(0.3).timeout.connect(func() -> void:
			var option: OptionButton = main.get_node("InfoPanel/PanelContainer/VBoxContainer/JobButton") as OptionButton
			option.show_popup()
		)
