extends RefCounted

static func setup(main: Node) -> void:
	var state: GameState = Game.state
	
	var ticks: int = 0
	var initial_wood: int = state.resources.get_amount("wood")
	var delivered: bool = false
	
	# wait for first delivery, then wait until all wood gatherers are harvesting
	while ticks < 600:
		state.tick(0.1)
		ticks += 1
		
		if not delivered and state.resources.get_amount("wood") > initial_wood:
			delivered = true
			
		if delivered:
			var all_harvesting: bool = true
			for s: Survivor in state.survivors.all():
				if s.job == Survivor.Job.GATHERER and s.gather_kind == "wood":
					if s.activity != Survivor.Activity.HARVESTING:
						all_harvesting = false
						break
			if all_harvesting:
				break
			
	state.clock.paused = true
	
	var cc: Building = state.buildings.all_of_type("command_center")[0]
	var text_layer: FloatingTextLayer = main.get_node("World/FloatingText") as FloatingTextLayer
	if text_layer:
		text_layer.spawn("+10 wood", cc.center_world() + Vector2(0, -40), "wood")
		text_layer.set_process(false)

	var cam: Camera2D = main.get_node("World/Camera2D")
	if cam:
		var sum_pos: Vector2 = Vector2.ZERO
		var count: int = 0
		# Include the full CC and tree tiles, plus the gatherer sprites.
		var bounds: Rect2 = Rect2(Vector2(cc.origin) * Grid.TILE, Vector2(cc.size) * Grid.TILE)
		for s: Survivor in state.survivors.all():
			if s.job == Survivor.Job.GATHERER and s.gather_kind == "wood":
				sum_pos += s.pos
				count += 1
				bounds = bounds.merge(Rect2(s.pos - Vector2(24, 24), Vector2(48, 48)))
				bounds = bounds.merge(Rect2(Vector2(s.work_tile) * Grid.TILE, Vector2(Grid.TILE, Grid.TILE)))
		var avg_pos: Vector2 = cc.center_world()
		if count > 0:
			avg_pos = sum_pos / float(count)
		var mid: Vector2 = (cc.center_world() + avg_pos) / 2.0
		var extent: Vector2 = (bounds.position - mid).abs().max((bounds.end - mid).abs())
		# Largest zoom fitting the fixed capture, with a 64 screen-pixel margin.
		var available: Vector2 = Vector2(1280, 720) / 2.0 - Vector2(64, 64)
		var framing_zoom: float = clampf(minf(available.x / extent.x, available.y / extent.y), 0.6, 1.0)
		cam.position = mid
		cam.zoom = Vector2.ONE * framing_zoom
