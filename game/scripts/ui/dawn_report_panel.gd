class_name DawnReportPanel extends CanvasLayer

const CONTENT := "Center/Panel/Margin/Content/"
const SCREEN_MARGIN := 24.0

var _state: GameState
var _was_paused: bool = false

func _ready() -> void:
	MenuStyle.apply(get_node("Center/Panel/Margin/Content"), MenuStyle.CREAM)
	get_viewport().size_changed.connect(_update_lines_height)
	get_node(CONTENT + "Scroll/Lines").minimum_size_changed.connect(_update_lines_height)
	get_node(CONTENT + "Scroll").resized.connect(_update_lines_height)
	_update_lines_height()

func bind(state: GameState) -> void:
	_state = state
	visible = false
	_state.dawn_processed.connect(_on_dawn_processed)
	var continue_btn: Button = get_node("Center/Panel/Margin/Content/Buttons/Continue") as Button
	continue_btn.pressed.connect(_on_continue)

func _on_dawn_processed(report: Dictionary) -> void:
	call_deferred("_show_report", report)

func _show_report(report: Dictionary) -> void:
	if _state.game_over:
		return
		
	if not visible:
		_was_paused = _state.clock.paused
		
	_state.clock.set_paused(true)
		
	var title: Label = get_node("Center/Panel/Margin/Content/Title") as Label
	var subtitle: Label = get_node("Center/Panel/Margin/Content/Subtitle") as Label
	var lines_container: GridContainer = get_node(CONTENT + "Scroll/Lines") as GridContainer
	
	var day: int = int(report.get("day", _state.clock.day))
	title.text = "DAWN: DAY %d" % day
	var night: int = int(report.get("night", 0))
	subtitle.text = "Night %d survived" % night
	
	MenuStyle.fill_stats(lines_container, report_rows(report, _state.tech.data))
	var scroll: ScrollContainer = get_node(CONTENT + "Scroll")
	scroll.scroll_vertical = 0
	# Measure wrapping at the full row width before an automatic scrollbar can
	# narrow it and make an otherwise fitting normal report overflow.
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		
	visible = true
	_update_lines_height()
	_enable_scrollbar_after_layout()
	_toast_refusals(report)

## Refusal toast once per survivor per dawn, reusing the scavenging toast box.
func _toast_refusals(report: Dictionary) -> void:
	if not is_inside_tree():
		return
	var hud: Node = get_parent().get_node_or_null("HUD") if get_parent() != null else null
	for text: String in ScavengeToast.refusal_texts(report):
		ScavengeToast.push_to_hud(hud, text)

func _enable_scrollbar_after_layout() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	get_node(CONTENT + "Scroll").vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_update_lines_height()

func _update_lines_height() -> void:
	if is_inside_tree():
		fit_lines_height(get_viewport().get_visible_rect().size.y)

func fit_lines_height(viewport_height: float) -> void:
	var panel: PanelContainer = get_node("Center/Panel")
	var scroll: ScrollContainer = get_node(CONTENT + "Scroll")
	var lines: GridContainer = scroll.get_node("Lines")
	# Subtract the current scroll minimum to measure title, margins and buttons.
	# A short report keeps its natural height; only overflowing rows scroll.
	var chrome_height: float = panel.get_combined_minimum_size().y - scroll.get_combined_minimum_size().y
	var available: float = maxf(1.0, viewport_height - SCREEN_MARGIN * 2.0 - chrome_height)
	scroll.custom_minimum_size.y = minf(lines.get_combined_minimum_size().y, available)

func _on_continue() -> void:
	visible = false
	if not _was_paused:
		_state.clock.set_paused(false)

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_accept"):
		_on_continue()
		get_viewport().set_input_as_handled()

static func report_rows(report: Dictionary, tech_config: Dictionary = {}) -> Array[Array]:
	var rows: Array[Array] = []
	var morale: Dictionary = report.get("morale", {})
	var left_morale: Array = morale.get("left_morale", [])
	for line: String in DawnReport.lines(report):
		var split_at: int = line.find(": ")
		if split_at >= 0:
			var key: String = line.substr(0, split_at)
			if key == "Left" and not left_morale.is_empty():
				continue # re-emitted below, split into hunger vs lost-heart
			rows.append([key, line.substr(split_at + 2)])
		elif line.begins_with("Command Center took "):
			rows.append(["Command Center damage", str(report.get("cc_damage", 0))])
		else:
			rows.append(["Objective", line])
	rows.append_array(morale_rows(report))
	rows.append_array(research_rows(report, tech_config))
	return rows

static func research_rows(report: Dictionary, tech_config: Dictionary) -> Array[Array]:
	var research: Dictionary = report.get("research", {})
	var rows: Array[Array] = []
	if research.is_empty():
		return rows
	var upgrades: Dictionary = tech_config.get("upgrades", {})
	var done: Array[String] = []
	for id: String in research.get("done_today", []):
		done.append(str(upgrades.get(id, {}).get("name", id)))
	if not done.is_empty():
		rows.append(["Research done", ", ".join(done)])
	var active: String = str(research.get("active", ""))
	if active != "":
		rows.append(["Research", "%s %d/%d" % [upgrades.get(active, {}).get("name", active), floori(float(research.get("progress", 0.0))), int(research.get("cost", 0))]])
	else:
		rows.append(["Research", "banked %d RP" % floori(float(research.get("banked", 0.0)))])
	return rows

## Morale rows for the Dawn Report (GDD §22.7). Pure so detached tests can
## check band counts, refusal names and lost-heart de-duplication. Old
## fixtures without report["morale"] get no rows.
static func morale_rows(report: Dictionary) -> Array[Array]:
	var rows: Array[Array] = []
	var morale: Dictionary = report.get("morale", {})
	if morale.is_empty():
		return rows
	var bands: Dictionary = morale.get("bands", {})
	var order: Array[String] = ["inspired", "steady", "low", "breaking"]
	var names := {"inspired": "Inspired", "steady": "Steady", "low": "Low", "breaking": "Breaking"}
	var parts: Array[String] = []
	for id: String in order:
		var n: int = int(bands.get(id, 0))
		if n > 0:
			parts.append("%d %s" % [n, str(names[id])])
	if not parts.is_empty():
		rows.append(["Morale", " · ".join(parts)])
	var refusing: Array = morale.get("refusing", [])
	if not refusing.is_empty():
		var sorted_names: Array = refusing.duplicate()
		sorted_names.sort()
		rows.append(["Refusing work", ", ".join(sorted_names)])
	# Morale leavers show once as lost heart and are filtered out of the
	# generic Left line so no name prints twice.
	var left: Array = report.get("left", [])
	var left_morale: Array = morale.get("left_morale", [])
	if not left_morale.is_empty():
		var generic: Array[String] = []
		for survivor_name: String in left:
			if not left_morale.has(survivor_name):
				generic.append(survivor_name)
		if not generic.is_empty():
			rows.append(["Left", ", ".join(generic)])
		rows.append(["Left (lost heart)", ", ".join(left_morale)])
	return rows
