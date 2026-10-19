class_name FloatingTextLayer extends Node2D

var _pool: Array[Label] = []
var _active: Array[Dictionary] = []
var _max_pool: int = 32

func bind(state: GameState) -> void:
	state.resource_delivered.connect(_on_resource_delivered)

func _on_resource_delivered(kind: String, amount: int, world_pos: Vector2) -> void:
	spawn("+%d %s" % [amount, kind], world_pos + Vector2(0, -40), kind)

func spawn(text: String, pos: Vector2, kind: String = "") -> void:
	var label: Label
	if _pool.is_empty():
		if get_child_count() < _max_pool:
			label = Label.new()
			label.add_theme_font_size_override("font_size", UiFont.BODY)
			label.add_theme_constant_override("outline_size", 4)
			add_child(label)
		else:
			var oldest: Dictionary = _active[0]
			_active.remove_at(0)
			label = oldest.label
	else:
		label = _pool.pop_back()
		
	label.text = text
	label.modulate = Color.WHITE
	label.visible = true
	
	var color: Color = Color.WHITE
	if kind == "wood":
		color = Color.TAN
	elif kind == "scrap":
		color = Color.LIGHT_STEEL_BLUE
	elif kind == "food":
		color = Color.GREEN
	elif kind == "ammo":
		color = Color.YELLOW
	label.add_theme_color_override("font_color", color)
	
	_active.append({
		"label": label,
		"time": 0.0,
		"pos": pos
	})
	label.position = pos - label.size / 2.0

func advance(delta: float) -> void:
	for i: int in range(_active.size() - 1, -1, -1):
		var item: Dictionary = _active[i]
		item.time += delta
		item.pos.y -= 30.0 * delta
		item.label.position = item.pos - item.label.size / 2.0
		
		var t: float = clampf(float(item.time) / 1.2, 0.0, 1.0)
		item.label.modulate.a = 1.0 - t
		
		if item.time >= 1.2:
			item.label.visible = false
			_pool.append(item.label)
			_active.remove_at(i)

func _process(delta: float) -> void:
	advance(delta)
