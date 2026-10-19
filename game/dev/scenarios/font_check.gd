extends RefCounted

static func setup(main: Node) -> void:
	Game.state.waves.enabled = false
	Game.state.clock.set_paused(true)
	Game.state.resources.add("wood", 500 - Game.state.resources.get_amount("wood"))
	Game.state.resources.add("scrap", 15 - Game.state.resources.get_amount("scrap"))
	
	# Open roster panel
	var roster: RosterPanel = main.get_node_or_null("RosterPanel") as RosterPanel
	if roster and not roster.is_open():
		roster.toggle()
		
	# Select a survivor so InfoPanel is open and populated
	var selection: SelectionController = main.get_node_or_null("World/Selection") as SelectionController
	var survivors := Game.state.survivors.all()
	if not survivors.is_empty() and selection != null:
		survivors[0].max_hp = 80
		survivors[0].hp = 80
		selection.select_survivor(survivors[0].uid)
		var info: InfoPanel = main.get_node_or_null("InfoPanel") as InfoPanel
		if info != null:
			info.refresh()
			
	# Framed panel displaying one Label at each UiFont size
	var layer := CanvasLayer.new()
	layer.layer = 20
	main.add_child(layer)
	
	var panel := PanelContainer.new()
	panel.name = "FontCheckPanel"
	# Keep the diagnostic samples above the bottom build bar at 720p.
	panel.position = Vector2(292, 100)
	panel.custom_minimum_size = Vector2(964, 0)
	layer.add_child(panel)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	panel.add_child(margin)
	
	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 2)
	margin.add_child(root_vbox)
	
	var sample_text := "0123456789 S s O o l I  HP 80/80  15  500"
	for font_size: int in [UiFont.NATIVE, UiFont.BODY, UiFont.LARGE, UiFont.TITLE, UiFont.BANNER]:
		var label := Label.new()
		label.text = sample_text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.add_theme_font_size_override("font_size", font_size)
		root_vbox.add_child(label)
