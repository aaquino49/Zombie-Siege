class_name CCAlarm extends CanvasLayer
## Full-screen red edge flash shown while the Command Center is under attack.
##
## Lives on its own CanvasLayer above the world (and the night CanvasModulate,
## which only tints world nodes) but below every menu. bind() connects
## GameState.building_damaged; Command Center hits flash the vignette to full
## and fade out over FADE_SECONDS. Hits faster than RETRIGGER_SECONDS are
## ignored so repeated damage cannot strobe. The vignette stays hidden while
## the game is over or any menu is open.

const FADE_SECONDS := 1.2
const RETRIGGER_SECONDS := 0.4
const EDGE_ALPHA := 0.45
const CENTER_SAFE_RADIUS := 0.28
const EDGE_FULL_RADIUS := 0.62

const VIGNETTE_SHADER := """shader_type canvas_item;
uniform float intensity = 0.0;
uniform vec4 edge_color : source_color = vec4(0.8, 0.05, 0.05, 1.0);
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv);
	float edge = smoothstep(0.28, 0.62, d);
	COLOR = vec4(edge_color.rgb, edge * 0.45 * intensity);
}
"""

const MENU_NODES: Array[String] = ["MainMenu", "PauseMenu", "SettingsScreen",
	"DawnReport", "GameOverScreen", "VictoryScreen", "HowToPlay", "CreditsScreen"]

var _state: GameState
var _rect: ColorRect
var _material: ShaderMaterial
var _level: float = 0.0
var _since_trigger: float = 999.0

func _init() -> void:
	layer = 5
	_rect = ColorRect.new()
	_rect.name = "Vignette"
	_rect.color = Color.WHITE
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("intensity", 0.0)
	_rect.material = _material
	add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func bind(state: GameState) -> void:
	if _state != null:
		if _state.building_damaged.is_connected(_on_building_damaged):
			_state.building_damaged.disconnect(_on_building_damaged)
		if _state.game_lost.is_connected(_on_game_ended):
			_state.game_lost.disconnect(_on_game_ended)
		if _state.game_won.is_connected(_on_game_won):
			_state.game_won.disconnect(_on_game_won)
	_state = state
	_level = 0.0
	_since_trigger = 999.0
	_apply()
	_state.building_damaged.connect(_on_building_damaged)
	_state.game_lost.connect(_on_game_ended)
	_state.game_won.connect(_on_game_won)

func intensity() -> float:
	return _level

func force_trigger() -> void:
	_since_trigger = 0.0
	_level = 1.0
	_apply()

func tick(delta: float) -> void:
	_since_trigger += delta
	_level = clampf(1.0 - _since_trigger / FADE_SECONDS, 0.0, 1.0)
	_apply()

func _process(delta: float) -> void:
	if _state == null:
		return
	tick(delta)

func _on_building_damaged(b: Building, _amount: int) -> void:
	if b == null or b.type_id != "command_center":
		return
	if _since_trigger < RETRIGGER_SECONDS:
		return
	force_trigger()

func _on_game_ended(_reason: String) -> void:
	_apply()

func _on_game_won() -> void:
	_apply()

func _apply() -> void:
	_material.set_shader_parameter("intensity", _level)
	visible = _level > 0.02 and _state != null and not _state.game_over and not _menus_open()

func _menus_open() -> bool:
	if not is_inside_tree():
		return false
	var scene: Node = get_tree().current_scene
	if scene == null:
		return false
	for node_name: String in MENU_NODES:
		var node: Node = scene.get_node_or_null(node_name)
		if node != null and (node as CanvasLayer).visible:
			return true
	return false
