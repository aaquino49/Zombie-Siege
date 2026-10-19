class_name MenuScreen extends CanvasLayer
## Shared modal navigation: return to the source without changing its clock state.

const CONTENT := "Dim/Center/Panel/Margin/Content/"
var _source: CanvasLayer
var _source_dim: Control

func _ready() -> void:
	MenuStyle.apply(get_node(CONTENT), MenuStyle.CREAM)
	initialize()

func initialize() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var back: Button = get_node(CONTENT + "Buttons/Back")
	if not back.pressed.is_connected(close):
		back.pressed.connect(close)

func open(source: CanvasLayer) -> void:
	_source = source
	# Keep the title backdrop beneath main-menu screens; replace only its UI.
	if _source is MainMenu:
		_source_dim = _source.get_node("Dim")
		_source_dim.visible = false
	else:
		_source.visible = false
	visible = true
	if is_inside_tree():
		get_node(CONTENT + "Buttons/Back").grab_focus()

func close() -> void:
	visible = false
	if is_instance_valid(_source):
		_source.visible = true
		if is_instance_valid(_source_dim):
			_source_dim.visible = true
		if is_inside_tree():
			var buttons: Node = _source.get_node(CONTENT + "Buttons")
			buttons.get_child(0).grab_focus()
	_source = null
	_source_dim = null

func _input(event: InputEvent) -> void:
	if not visible:
		return
	# Handle Esc before the pause menu's _unhandled_input sees this press.
	if event.is_action_pressed("cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()
	elif PauseMenu.blocks_action(event):
		get_viewport().set_input_as_handled()
