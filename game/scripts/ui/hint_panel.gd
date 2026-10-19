class_name HintPanel extends CanvasLayer

var _state: GameState
var _hints: TutorialHints
var _current_id: String = ""
var _queue: Array[String] = []
var _close_timer: float = 0.0

var _panel: PanelContainer
var _label: Label
var _button: Button
var _hud: CanvasLayer
var _build_bar_panel: Control
const HUD_GAP: float = 8.0
const CARD_WIDTH: float = 380.0

func _ready() -> void:
	_ensure_nodes()
	if _panel:
		_panel.visible = false

func _ensure_nodes() -> void:
	if _panel != null:
		return
	_panel = get_node_or_null("PanelContainer")
	if _panel:
		_label = _panel.get_node_or_null("MarginContainer/VBoxContainer/HintLabel")
		_button = _panel.get_node_or_null("MarginContainer/VBoxContainer/BottomRow/GotItButton")
		if _label:
			_label.minimum_size_changed.connect(_queue_layout)
		if _button and not _button.pressed.is_connected(_on_got_it_pressed):
			_button.pressed.connect(_on_got_it_pressed)

func bind(state: GameState) -> void:
	_ensure_nodes()
	_state = state
	if _hud and _hud.top_left_stack_changed.is_connected(_position_below_hud):
		_hud.top_left_stack_changed.disconnect(_position_below_hud)
	_hud = get_parent().get_node_or_null("HUD") as CanvasLayer if get_parent() else null
	if _build_bar_panel and _build_bar_panel.item_rect_changed.is_connected(_queue_layout):
		_build_bar_panel.item_rect_changed.disconnect(_queue_layout)
	_build_bar_panel = null
	if get_parent():
		for sibling: Node in get_parent().get_children():
			if sibling is BuildBar:
				_build_bar_panel = sibling.get_node("Panel") as Control
				_build_bar_panel.item_rect_changed.connect(_queue_layout)
				break
	if _hud:
		_hud.top_left_stack_changed.connect(_position_below_hud)
		_position_below_hud()
	_hints = TutorialHints.new()
	_hints.enabled = HintSettings.load_enabled()
	_current_id = ""
	_close_timer = 0.0
	_queue.clear()
	if _panel:
		_panel.visible = false

func set_enabled(on: bool) -> void:
	if _hints:
		_hints.enabled = on
	if not on:
		_current_id = ""
		_close_timer = 0.0
		_queue.clear()
		if _panel:
			_panel.visible = false

func show_hint(id: String) -> void:
	_ensure_nodes()
	_queue.clear()
	_display_card(id)

func current_hint() -> String:
	return _current_id

func get_shown() -> Dictionary:
	return _hints.shown.duplicate(true) if _hints else {}

func set_shown(shown: Dictionary) -> void:
	if _hints:
		_hints.shown = shown.duplicate(true)

func is_showing() -> bool:
	return _current_id != "" and _panel != null and _panel.visible

func _on_got_it_pressed() -> void:
	_close_current()

func _close_current() -> void:
	_current_id = ""
	_close_timer = 0.0
	if _panel:
		_panel.visible = false
	if not _queue.is_empty() and (_hints == null or _hints.enabled):
		var next_id: String = _queue.pop_front()
		_display_card(next_id)

func _display_card(id: String) -> void:
	_ensure_nodes()
	_current_id = id
	_close_timer = 12.0
	if _label:
		_label.max_lines_visible = -1
		_label.text = TutorialHints.text(id, _state.data if _state else null)
	if _panel:
		_panel.visible = true
		_layout_card()
		_queue_layout()

func _position_below_hud() -> void:
	if _panel and _hud:
		_panel.position.y = _hud.top_left_stack_bottom() + HUD_GAP
		_layout_card()
		_queue_layout()

func _queue_layout() -> void:
	# Text and container minima can change again during the layout pass.
	_layout_card.call_deferred()

func _layout_card() -> void:
	if not _panel or not _label:
		return
	var margins: MarginContainer = _panel.get_node("MarginContainer")
	var box: VBoxContainer = margins.get_node("VBoxContainer")
	var row: HBoxContainer = box.get_node("BottomRow")
	var style_size: Vector2 = _panel.get_theme_stylebox("panel").get_minimum_size()
	# Give autowrap its final width before it measures the new text, including
	# both the panel style and the explicit content margins.
	var wrap_width: float = CARD_WIDTH - style_size.x - margins.get_theme_constant("margin_left") - margins.get_theme_constant("margin_right")
	_label.custom_minimum_size.x = wrap_width
	_label.size.x = wrap_width
	if _build_bar_panel and is_inside_tree():
		var available: float = _build_bar_panel.get_global_rect().position.y - HUD_GAP - _panel.position.y
		var padding: float = style_size.y + margins.get_theme_constant("margin_top") + margins.get_theme_constant("margin_bottom") + box.get_theme_constant("separation") + row.get_combined_minimum_size().y
		var spacing: int = _label.get_theme_constant("line_spacing")
		var line_height: float = _label.get_line_height() + spacing
		# Limit the label's minimum height as well as its drawing; keep the
		# top fixed and the dismiss button inside the compact panel.
		_label.max_lines_visible = maxi(0, floori((available - padding + spacing) / maxf(1.0, line_height)))
	# Containers grow automatically, but need their old height cleared to shrink.
	_panel.size = Vector2(CARD_WIDTH, 0.0)

func _process(delta: float) -> void:
	if _current_id != "":
		_close_timer -= delta
		if _close_timer <= 0.0:
			_close_current()

	if not _state or not _hints or not _hints.enabled:
		return
	if _state.clock.paused:
		return

	var sim_delta: float = _state.clock.scale(delta)
	var next_id: String = _hints.check(_state, sim_delta)
	if next_id != "":
		if _current_id == "":
			_display_card(next_id)
		else:
			_queue.append(next_id)
