class_name NightLights extends Node2D
## Building lights share one small radial texture and follow the world tint ramps.

const LIT_TYPES: Array[String] = ["command_center", "shelter", "watchtower", "turret", "radio_tower", "campfire", "field_lab"]
const WARM_COLOR: Color = Color("ffcf8a")
const TEXTURE_SIZE: int = 128

static var _texture: GradientTexture2D
var _state: GameState
var _lights: Dictionary = {}
var _energy: float = 0.0

static func energy_for(phase: int, elapsed: float, time_left: float, day: int) -> float:
	if phase == GameClock.Phase.NIGHT:
		return 1.0
	if day > 1 and elapsed < DayNightTint.DAWN_SECONDS:
		return 1.0 - clampf(elapsed / DayNightTint.DAWN_SECONDS, 0.0, 1.0)
	if time_left < DayNightTint.DUSK_SECONDS:
		return clampf(1.0 - time_left / DayNightTint.DUSK_SECONDS, 0.0, 1.0)
	return 0.0

static func shared_texture() -> GradientTexture2D:
	if _texture == null:
		var gradient: Gradient = Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		# Reserve headroom where towers and the CC overlap so sprite detail survives.
		gradient.colors = PackedColorArray([Color(0.65, 0.65, 0.65), Color(0.25, 0.25, 0.25), Color.BLACK])
		_texture = GradientTexture2D.new()
		_texture.width = TEXTURE_SIZE
		_texture.height = TEXTURE_SIZE
		_texture.fill = GradientTexture2D.FILL_RADIAL
		_texture.fill_from = Vector2(0.5, 0.5)
		_texture.fill_to = Vector2(1.0, 0.5)
		_texture.gradient = gradient
	return _texture

func bind(state: GameState) -> void:
	if _state != null:
		_state.buildings.building_added.disconnect(_add_light)
		_state.buildings.building_completed.disconnect(_add_light)
		_state.buildings.building_removed.disconnect(_remove_light)
		_state.command_center_destroyed.disconnect(_command_center_destroyed)
	for uid: int in _lights.keys():
		_drop_light(uid)
	_state = state
	_process(0.0)
	if _state == null:
		return
	_state.buildings.building_added.connect(_add_light)
	_state.buildings.building_completed.connect(_add_light)
	_state.buildings.building_removed.connect(_remove_light)
	_state.command_center_destroyed.connect(_command_center_destroyed)
	for building: Building in _state.buildings.all():
		_add_light(building)

func _add_light(building: Building) -> void:
	if not building.complete or building.hp <= 0 or building.type_id not in LIT_TYPES or _lights.has(building.uid):
		return
	var light: PointLight2D = PointLight2D.new()
	light.name = "BuildingLight%d" % building.uid
	light.position = building.center_world()
	light.texture = shared_texture()
	light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Campfires use the existing warm color/energy curve at 0.75 of a
	# Shelter light's scale (GDD 22.5); removed on destruction via _remove_light.
	var radius_tiles: float = 2.0
	if building.type_id == "command_center":
		radius_tiles = 3.0
	elif building.type_id == "campfire":
		radius_tiles = 1.5
	light.texture_scale = radius_tiles * Grid.TILE * 2.0 / TEXTURE_SIZE
	light.color = WARM_COLOR
	light.energy = _energy
	light.enabled = _energy > 0.0
	light.shadow_enabled = false
	add_child(light)
	_lights[building.uid] = light

func _remove_light(building: Building) -> void:
	_drop_light(building.uid)

func _drop_light(uid: int) -> void:
	if not _lights.has(uid):
		return
	var light: PointLight2D = _lights[uid]
	_lights.erase(uid)
	remove_child(light)
	if is_inside_tree():
		light.queue_free()
	else:
		light.free()

func _command_center_destroyed() -> void:
	for building: Building in _state.buildings.all_of_type("command_center"):
		if building.hp <= 0:
			_drop_light(building.uid)

func _process(_delta: float) -> void:
	var energy: float = 0.0
	if _state != null:
		var clock: GameClock = _state.clock
		energy = energy_for(clock.phase, clock.elapsed, clock.time_left(), clock.day)
	if is_equal_approx(energy, _energy):
		return
	_energy = energy
	for light: PointLight2D in _lights.values():
		light.energy = _energy
		light.enabled = _energy > 0.0
