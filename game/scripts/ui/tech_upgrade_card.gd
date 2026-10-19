class_name TechUpgradeCard extends Button
## A view of one configured upgrade; commands belong to the screen.

var upgrade_id: String
var _name_label: Label
var _effect_label: Label
var _state_label: Label
var _bar: ProgressBar

static func number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else String.num(value, 1)

static func effect_text(state: GameState, id: String) -> String:
	var upgrade: Dictionary = state.tech.data.upgrades[id]
	var effect: Dictionary = upgrade.effect
	var value: float = float(effect.value)
	match str(effect.key):
		"guard_range_tiles":
			return "Guards see %s tile further." % number(value)
		"turret_fire_interval":
			return "Turrets fire %s%% faster." % number((1.0 / value - 1.0) * 100.0)
		"structure_damage_taken":
			return "Buildings take %s%% less damage." % number((1.0 - value) * 100.0)
		"gather_time":
			return "Gatherers work %s%% faster." % number((1.0 / value - 1.0) * 100.0)
		"farm_food":
			return "Farms grow %s%% more food." % number((value - 1.0) * 100.0)
		"ammo_per_scrap":
			return "Workshops make %s more ammo per scrap." % number(value)
		"campfire_morale":
			return "Campfires give %s%% more morale." % number((value - 1.0) * 100.0)
		"dawn_heal":
			return "Survivors heal %s HP each dawn." % number(value)
		"shelter_beds":
			return "Each Shelter has %s extra beds." % number(value)
	return str(upgrade.text)

func configure(state: GameState, id: String) -> void:
	upgrade_id = id
	name = id
	focus_mode = Control.FOCUS_NONE
	toggle_mode = true
	theme_type_variation = &"ToggleButton"
	custom_minimum_size = Vector2(0, 132)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 0)
	margin.add_child(content)
	var heading := HBoxContainer.new()
	content.add_child(heading)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var path: String = "res://assets/pixel/ui/tech/%s.png" % id
	if ResourceLoader.exists(path):
		icon.texture = load(path) as Texture2D
	heading.add_child(icon)
	_name_label = _label(str(state.tech.data.upgrades[id].name))
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_name_label)
	_effect_label = _label(effect_text(state, id))
	_effect_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_effect_label)
	_state_label = _label("")
	content.add_child(_state_label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size.y = 8
	_bar.show_percentage = false
	content.add_child(_bar)
	_ignore_mouse(margin)
	refresh(state)

func _label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", UiFont.BODY)
	return label

func _ignore_mouse(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		if child is Control:
			_ignore_mouse(child as Control)

func refresh(state: GameState) -> void:
	var upgrade: Dictionary = state.tech.data.upgrades[upgrade_id]
	var status: String = state.tech.status(upgrade_id)
	var progress: int = floori(float(state.tech.progress.get(upgrade_id, 0.0)))
	var cost: int = int(upgrade.cost)
	disabled = status in ["locked", "done"]
	set_pressed_no_signal(status == "researching")
	var detail: String = status.capitalize()
	if status == "locked":
		var names: Array[String] = []
		for required: String in upgrade.requires:
			if not state.tech.is_done(required):
				names.append(str(state.tech.data.upgrades[required].name))
		detail = "Needs " + ", ".join(names)
	elif status == "researching":
		detail = "Researching %d / %d" % [progress, cost]
	elif status == "available" and progress > 0:
		detail = "Saved %d / %d RP" % [progress, cost]
	_state_label.text = "%d RP · %s" % [cost, detail]
	_bar.max_value = cost
	_bar.value = cost if status == "done" else float(state.tech.progress.get(upgrade_id, 0.0))
	_bar.visible = status == "researching" or (status == "available" and progress > 0)
	modulate = Color(0.65, 0.65, 0.65) if status == "locked" else Color.WHITE
	_state_label.add_theme_color_override("font_color", Color("a5cf8a") if status == "done" else MenuStyle.CREAM)
	_effect_label.text = effect_text(state, upgrade_id)
	tooltip_text = "%s · %d RP\n%s\n%s" % [upgrade.name, cost, _effect_label.text, detail]

func _make_custom_tooltip(for_text: String) -> Object:
	var panel := PanelContainer.new()
	var label: Label = _label(for_text)
	label.custom_minimum_size.x = 420
	panel.add_child(label)
	return panel
