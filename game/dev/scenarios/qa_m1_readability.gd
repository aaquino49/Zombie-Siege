extends RefCounted
## Every building at native 1x size over a outlined data-defined footprint.

static func setup(main: Node) -> void:
	Game.state.clock.set_paused(true)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 20
	main.add_child(layer)
	var background: ColorRect = ColorRect.new()
	background.size = Vector2(1280, 720)
	background.color = Color(0.12, 0.14, 0.16)
	layer.add_child(background)
	var title: Label = Label.new()
	title.text = "M1 readability: native 1x sprites / cyan footprint perimeter"
	title.position = Vector2(28, 12)
	layer.add_child(title)
	var ids: PackedStringArray = Game.state.data.building_ids()
	for i: int in range(ids.size()):
		var cell: Node2D = Node2D.new()
		cell.position = Vector2(30 + (i % 4) * 310, 62 + (i / 4) * 210)
		layer.add_child(cell)
		var definition: Dictionary = Game.state.data.get_building(ids[i])
		var size_data: Array = definition["size"]
		var size: Vector2i = Vector2i(int(size_data[0]), int(size_data[1]))
		for x: int in range(size.x):
			for y: int in range(size.y):
				var grass: Sprite2D = Sprite2D.new()
				grass.texture = preload("res://assets/tiles/grass_1.png")
				grass.position = Grid.tile_to_world(Vector2i(x, y))
				cell.add_child(grass)
		var building: Building = Building.new()
		building.type_id = ids[i]
		building.origin = Vector2i.ZERO
		building.size = size
		building.complete = true
		cell.add_child(BuildingSprites.make(Game.state.data, building))
		var bounds: Vector2 = Vector2(size) * Grid.TILE
		var outline: Line2D = Line2D.new()
		outline.points = PackedVector2Array([Vector2.ZERO, Vector2(bounds.x, 0), bounds, Vector2(0, bounds.y), Vector2.ZERO])
		outline.width = 2.0
		outline.default_color = Color(0.3, 0.9, 1.0)
		cell.add_child(outline)
		var label: Label = Label.new()
		label.text = "%s (%dx%d)" % [ids[i], size.x, size.y]
		label.position = Vector2(0, 140)
		cell.add_child(label)
