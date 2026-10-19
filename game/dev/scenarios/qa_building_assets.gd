extends RefCounted
## T-007 asset inspection at 1x scale; leaves normal/default gameplay untouched.


static func setup(main: Node) -> void:
	for child: Node in main.get_children():
		child.queue_free()
	var names: PackedStringArray = [
		"command_center", "shelter", "farm", "storage", "workshop",
		"lumber_yard", "radio_tower", "wall_wood", "watchtower", "gate",
		"wall_reinforced", "construction_1x1", "construction_2x2",
		"turret_base", "turret_barrel",
	]
	for i: int in range(names.size()):
		var origin := Vector2(28 + (i % 5) * 248, 22 + (i / 5) * 228)
		for x: int in range(3):
			for y: int in range(3):
				_add_sprite(main, "tiles/grass_%d.png" % (1 + (x + y) % 3),
					origin + Vector2(x * 64 + 32, y * 64 + 32))
		_add_sprite(main, "buildings/%s.png" % names[i], origin + Vector2(64, 64))
		_add_sprite(main, "characters/survivor_blue_stand.png", origin + Vector2(154, 96))
		var label := Label.new()
		label.text = names[i]
		label.position = origin + Vector2(0, 195)
		main.add_child(label)


static func _add_sprite(main: Node, path: String, position: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/" + path) as Texture2D
	sprite.position = position
	main.add_child(sprite)
