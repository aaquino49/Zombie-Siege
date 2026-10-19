class_name BuildInfoCard extends PanelContainer

const MAX_WIDTH: float = 420.0
const RESOURCE_ORDER: Array[String] = ["wood", "scrap", "food", "ammo"]

var _current_type: String = ""
var state: GameState

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

static func lines_for(data: GameData, resources: ResourceStore, type_id: String, hotkey: String = "", effective_state: GameState = null) -> Array[String]:
	var out: Array[String] = []
	if data == null:
		out.append(type_id)
		return out
	if not data.building_ids().has(type_id):
		out.append(type_id)
		return out
	var b: Dictionary = data.get_building(type_id)
	var b_name: String = str(b.get("name", type_id))
	if b_name.is_empty():
		b_name = type_id
	out.append(("[%s] " % hotkey) + b_name if not hotkey.is_empty() else b_name)
	var blurb: String = str(b.get("blurb", ""))
	if not blurb.is_empty():
		out.append(blurb)
	out.append(stats_line(data, type_id, effective_state))
	var need: String = need_line(data, resources, type_id)
	if not need.is_empty():
		out.append(need)
	return out

static func stats_line(data: GameData, type_id: String, effective_state: GameState = null) -> String:
	if data == null or not data.building_ids().has(type_id):
		return "HP 0 · 1×1"
	var b: Dictionary = data.get_building(type_id)
	var hp: int = int(b.get("hp", 0))
	var w: int = 1
	var h: int = 1
	var sz: Array = b.get("size", [1, 1])
	if sz.size() >= 2:
		w = int(sz[0])
		h = int(sz[1])
	var parts: Array[String] = []
	parts.append("HP %d · %d×%d" % [hp, w, h])
	var workers: int = int(b.get("workers", 0))
	if workers == 1:
		parts.append("1 worker")
	elif workers > 1:
		parts.append("up to %d workers" % workers)
	var beds: int = int(b.get("beds", 0))
	if effective_state and type_id == "shelter":
		beds += int(effective_state.tech.bonus("shelter_beds"))
	if beds > 0:
		parts.append("+%d beds" % beds)
	if b.has("range_tiles"):
		parts.append("range %d tiles" % int(b.get("range_tiles")))
	if type_id == "workshop" and b.has("craft_time"):
		var ct: float = float(b.get("craft_time"))
		var ct_str: String = str(int(ct)) if ct == float(int(ct)) else str(ct)
		parts.append("ammo every %s s" % ct_str)
	var output: String = output_line(data, type_id, effective_state)
	if not output.is_empty() and type_id != "shelter":
		parts.append(output)
	if effective_state and type_id == "watchtower":
		var base: float = (float(data.balance("guard_range_tiles")) + effective_state.tech.bonus("guard_range_tiles")) * float(b.guard_range_mult)
		parts.append("guard range %s tiles" % TechUpgradeCard.number(maxf(1.0, base + Weather.range_delta_px(effective_state) / Grid.TILE)))
	return " · ".join(parts)

static func output_line(data: GameData, type_id: String, effective_state: GameState = null) -> String:
	var b: Dictionary = data.get_building(type_id)
	if type_id == "workshop":
		var ammo: int = int(b.ammo_per_scrap) + (int(effective_state.tech.bonus("ammo_per_scrap")) if effective_state else 0)
		return "%d ammo / scrap" % ammo
	if type_id == "farm":
		var food: float = float(b.food_per_farmer) * (effective_state.tech.mult("farm_food") if effective_state else 1.0)
		if effective_state and effective_state.weather_day() == "rain":
			food *= float(data.weather_config().rain.farm_mult)
		return "%s food / farmer / day" % TechUpgradeCard.number(food)
	if type_id == "shelter":
		var beds: int = int(b.beds) + (int(effective_state.tech.bonus("shelter_beds")) if effective_state else 0)
		return "%d beds" % beds
	if type_id == "field_lab":
		return "%s RP / researcher / day" % TechUpgradeCard.number(float(data.tech_config().rp_per_researcher_per_day))
	return ""

static func need_line(data: GameData, resources: ResourceStore, type_id: String) -> String:
	if data == null or resources == null:
		return ""
	if not data.building_ids().has(type_id):
		return ""
	var cost: Dictionary = data.get_building(type_id).get("cost", {})
	var shorts: Array[String] = []
	for kind: String in RESOURCE_ORDER:
		if not cost.has(kind):
			continue
		var need: int = int(cost[kind]) - resources.get_amount(kind)
		if need > 0:
			shorts.append("%d more %s" % [need, kind])
	for kind: String in cost.keys():
		if RESOURCE_ORDER.has(kind):
			continue
		if not ResourceStore.KINDS.has(kind):
			continue
		var short: int = int(cost[kind]) - resources.get_amount(kind)
		if short > 0:
			shorts.append("%d more %s" % [short, kind])
	if shorts.is_empty():
		return ""
	return "Need " + ", ".join(shorts)

func current_type() -> String:
	return _current_type

func _ensure_built() -> void:
	var vbox: VBoxContainer = get_node_or_null("VBox") as VBoxContainer
	if vbox == null:
		vbox = VBoxContainer.new()
		vbox.name = "VBox"
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_theme_constant_override("separation", 0)
		vbox.custom_minimum_size.x = MAX_WIDTH - 24.0
		add_child(vbox)
		var text_w: float = MAX_WIDTH - 40.0
		var name_lbl := Label.new()
		name_lbl.name = "Name"
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_lbl.add_theme_font_size_override("font_size", UiFont.LARGE)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.custom_minimum_size.x = text_w
		vbox.add_child(name_lbl)
		var blurb_lbl := Label.new()
		blurb_lbl.name = "Blurb"
		blurb_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blurb_lbl.add_theme_font_size_override("font_size", UiFont.BODY)
		blurb_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb_lbl.custom_minimum_size.x = text_w
		vbox.add_child(blurb_lbl)
		var stats_lbl := Label.new()
		stats_lbl.name = "Stats"
		stats_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stats_lbl.add_theme_font_size_override("font_size", UiFont.BODY)
		stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats_lbl.custom_minimum_size.x = text_w
		vbox.add_child(stats_lbl)
		var need_lbl := Label.new()
		need_lbl.name = "Need"
		need_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		need_lbl.add_theme_font_size_override("font_size", UiFont.BODY)
		need_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		need_lbl.custom_minimum_size.x = text_w
		vbox.add_child(need_lbl)

func show_for(data: GameData, resources: ResourceStore, type_id: String, hotkey: String = "") -> void:
	_ensure_built()
	_current_type = type_id
	var lines: Array[String] = lines_for(data, resources, type_id, hotkey, state)
	var vbox: VBoxContainer = get_node("VBox") as VBoxContainer
	var name_lbl: Label = vbox.get_node("Name") as Label
	var blurb_lbl: Label = vbox.get_node("Blurb") as Label
	var stats_lbl: Label = vbox.get_node("Stats") as Label
	var need_lbl: Label = vbox.get_node("Need") as Label
	if lines.size() == 1:
		name_lbl.text = lines[0]
		blurb_lbl.hide()
		stats_lbl.hide()
		need_lbl.hide()
		visible = true
		return
	# lines: name, [blurb], stats, [need]
	var idx: int = 0
	name_lbl.text = lines[idx]
	idx += 1
	var has_need: bool = lines[lines.size() - 1].begins_with("Need ")
	var stats_idx: int = lines.size() - 2 if has_need else lines.size() - 1
	# Blurb present when more than name+stats (+need).
	if lines.size() > (3 if has_need else 2):
		blurb_lbl.text = lines[idx]
		blurb_lbl.show()
		idx += 1
	else:
		blurb_lbl.hide()
	stats_lbl.text = lines[stats_idx]
	stats_lbl.show()
	if has_need:
		need_lbl.text = lines[lines.size() - 1]
		need_lbl.show()
	else:
		need_lbl.hide()
	visible = true

func hide_card() -> void:
	_current_type = ""
	visible = false
