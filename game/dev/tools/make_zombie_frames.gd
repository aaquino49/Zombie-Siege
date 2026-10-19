extends SceneTree

const TYPES: Array[String] = ["walker", "runner", "brute"]
const DIRECTIONS: Array[String] = ["down", "up", "left", "right"]
const ROOT := "res://assets/pixel/"

func _initialize() -> void:
	var output_dir: String = ROOT + "frames"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	for type_id: String in TYPES:
		var frames := SpriteFrames.new()
		frames.remove_animation("default")
		for direction: String in DIRECTIONS:
			var walk: Array[Texture2D] = _cells("zombies/%s_walk_%s.png" % [type_id, direction])
			var hurt: Array[Texture2D] = _cells("zombies/%s_hurt_%s.png" % [type_id, direction])
			_add_animation(frames, "idle_%s" % direction, [walk[0]], 4.0, true)
			_add_animation(frames, "walk_%s" % direction, [walk[0], walk[1], walk[0], walk[2]], 12.0 if type_id == "runner" else 8.0, true)
			_add_animation(frames, "attack_%s" % direction, [walk[0], walk[1], walk[0], walk[2]], 10.0, true)
			_add_animation(frames, "hurt_%s" % direction, hurt, 12.0, false)
			_add_animation(frames, "death_%s" % direction, hurt.slice(0, 1), 10.0, false)
		_add_animation(frames, "death", _cells("zombies/%s_hurt_down.png" % type_id).slice(0, 1), 10.0, false)
		var path: String = "%sframes/zombie_%s.tres" % [ROOT, type_id]
		var error: Error = ResourceSaver.save(frames, path)
		if error != OK:
			push_error("Could not save %s: %s" % [path, error_string(error)])
	quit()

func _cells(relative_path: String) -> Array[Texture2D]:
	var texture: Texture2D = load(ROOT + relative_path) as Texture2D
	if texture == null:
		push_error("Missing zombie strip: " + relative_path)
		return []
	var cells: Array[Texture2D] = []
	for index: int in range(3):
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(index * 16, 0, 16, 16)
		cells.append(atlas)
	return cells

func _add_animation(frames: SpriteFrames, name: String, textures: Array[Texture2D], fps: float, loop: bool) -> void:
	frames.add_animation(name)
	frames.set_animation_speed(name, fps)
	frames.set_animation_loop(name, loop)
	for texture: Texture2D in textures:
		frames.add_frame(name, texture)
