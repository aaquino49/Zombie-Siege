class_name BuildingSprites extends RefCounted

const PIXEL_DIR := "res://assets/pixel/buildings/"
## Completed Campfires loop T-224's four-frame 64x16 strip at exactly 6 fps.
const CAMPFIRE_FPS := 6.0
const CAMPFIRE_FRAMES := 4

static var _campfire_lit: SpriteFrames = null

## Four 16x16 flicker frames from campfire_lit.png, shared across scenes.
static func campfire_lit_frames() -> SpriteFrames:
	if _campfire_lit == null:
		var strip: Texture2D = load(PIXEL_DIR + "campfire_lit.png") as Texture2D
		_campfire_lit = SpriteFrames.new()
		_campfire_lit.set_animation_speed("default", CAMPFIRE_FPS)
		_campfire_lit.set_animation_loop("default", true)
		for i: int in range(CAMPFIRE_FRAMES):
			var cell := AtlasTexture.new()
			cell.atlas = strip
			cell.region = Rect2(i * Grid.PX_TILE, 0, Grid.PX_TILE, Grid.PX_TILE)
			cell.filter_clip = true
			_campfire_lit.add_frame("default", cell)
	return _campfire_lit

static func get_barrel_texture(dir: String) -> Texture2D:
	# Godot caches load() results; a static strong cache outlives scene teardown.
	var path := PIXEL_DIR + "turret_barrel_" + dir + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

static func apply_pixel_sprite(sprite: Sprite2D, tex: Texture2D, footprint_px: Vector2) -> void:
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(Grid.PIXEL_SCALE, Grid.PIXEL_SCALE)
	sprite.centered = true
	sprite.position = Vector2(0.0, footprint_px.y / 2.0)
	sprite.offset = Vector2(0.0, -tex.get_height() / 2.0)

static func texture_for(data: GameData, type_id: String) -> Texture2D:
	if not data.building_ids().has(type_id):
		return null
	var type_data: Dictionary = data.get_building(type_id)
	if type_data.is_empty() or not type_data.has("sprite"):
		return null
	var stem: String = str(type_data["sprite"])
	if type_data.get("autotile", false):
		stem += "_h"
	var path: String = PIXEL_DIR + stem + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

static func wall_suffix(n: bool, e: bool, s: bool, w: bool) -> String:
	var count := (1 if n else 0) + (1 if e else 0) + (1 if s else 0) + (1 if w else 0)
	match count:
		0:
			return "post"
		1:
			if n: return "end_n"
			if e: return "end_e"
			if s: return "end_s"
			return "end_w"
		2:
			if n and s: return "v"
			if e and w: return "h"
			if n and e: return "corner_ne"
			if n and w: return "corner_nw"
			if s and e: return "corner_se"
			if s and w: return "corner_sw"
		3:
			if n and e and s: return "tee_nes"
			if e and s and w: return "tee_esw"
			if n and s and w: return "tee_nsw"
			if n and e and w: return "tee_new"
		4:
			return "cross"
	return "post"

static func _is_wall_connectable(state_or_map, tile: Vector2i) -> bool:
	if state_or_map == null:
		return false
	var type_id: String = ""
	if state_or_map is GameState:
		type_id = state_or_map.map.building_at(tile)
	elif state_or_map is WorldMap:
		type_id = state_or_map.building_at(tile)
	elif state_or_map is BuildingStore:
		var b: Building = state_or_map.get_at(tile)
		if b:
			type_id = b.type_id
	elif state_or_map.has_method("building_at"):
		type_id = state_or_map.building_at(tile)
	elif "map" in state_or_map and state_or_map.map != null:
		type_id = state_or_map.map.building_at(tile)
	return type_id in ["wooden_wall", "reinforced_wall", "gate"]

static func wall_texture(data: GameData, state_or_map, b: Building) -> Texture2D:
	var n: bool = _is_wall_connectable(state_or_map, b.origin + Vector2i(0, -1))
	var e: bool = _is_wall_connectable(state_or_map, b.origin + Vector2i(1, 0))
	var s: bool = _is_wall_connectable(state_or_map, b.origin + Vector2i(0, 1))
	var w: bool = _is_wall_connectable(state_or_map, b.origin + Vector2i(-1, 0))
	var suffix: String = wall_suffix(n, e, s, w)
	
	var type_data: Dictionary = data.get_building(b.type_id)
	if type_data.get("autotile", false):
		var prefix: String = type_data.get("sprite", "")
		var path: String = PIXEL_DIR + prefix + "_" + suffix + ".png"
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return texture_for(data, b.type_id)

static func gate_texture(data: GameData, state_or_map, b: Building) -> Texture2D:
	var n: bool = _is_wall_connectable(state_or_map, b.origin + Vector2i(0, -1))
	var e: bool = _is_wall_connectable(state_or_map, b.origin + Vector2i(1, 0))
	var s: bool = _is_wall_connectable(state_or_map, b.origin + Vector2i(0, 1))
	var w: bool = _is_wall_connectable(state_or_map, b.origin + Vector2i(-1, 0))
	if n and s and not e and not w:
		var vertical_path: String = PIXEL_DIR + "gate_closed_v.png"
		if ResourceLoader.exists(vertical_path):
			return load(vertical_path) as Texture2D
	return texture_for(data, b.type_id)

static func make(data: GameData, b: Building, state_or_map = null) -> Node2D:
	var footprint_size: Vector2 = Vector2(b.size) * Grid.TILE
	# Choose the Campfire factory before allocating the ordinary building
	# node, so each completed fire owns exactly one Node2D.
	if b.type_id == "campfire" and b.complete:
		return make_campfire_lit(footprint_size, b)
	var node: Node2D = Node2D.new()
	node.position = b.center_world()
	node.y_sort_enabled = false
	
	var type_data: Dictionary = data.get_building(b.type_id)
	var footprint_h: float = footprint_size.y
	
	var tex: Texture2D = null
	if state_or_map != null and b.type_id == "gate":
		tex = gate_texture(data, state_or_map, b)
	elif state_or_map != null and type_data.get("autotile", false):
		tex = wall_texture(data, state_or_map, b)
	else:
		tex = texture_for(data, b.type_id)
	
	var tex_h: float = footprint_h / float(Grid.PIXEL_SCALE)
	if tex:
		tex_h = float(tex.get_height())
		var sprite: Sprite2D = Sprite2D.new()
		sprite.name = "Sprite"
		apply_pixel_sprite(sprite, tex, footprint_size)
		node.add_child(sprite)
		
		if type_data.has("sprite_top"):
			var top_tex: Texture2D = null
			var stem: String = str(type_data["sprite_top"])
			if b.type_id == "turret":
				if ResourceLoader.exists(PIXEL_DIR + stem + "_down.png"):
					top_tex = get_barrel_texture("down")
				elif ResourceLoader.exists(PIXEL_DIR + stem + ".png"):
					top_tex = load(PIXEL_DIR + stem + ".png") as Texture2D
			else:
				var top_path: String = PIXEL_DIR + stem + ".png"
				if ResourceLoader.exists(top_path):
					top_tex = load(top_path) as Texture2D
			if top_tex:
				var top_sprite: Sprite2D = Sprite2D.new()
				top_sprite.name = "TurretBarrel" if b.type_id == "turret" else "Top"
				apply_pixel_sprite(top_sprite, top_tex, footprint_size)
				node.add_child(top_sprite)
	else:
		var color_rect: ColorRect = ColorRect.new()
		color_rect.size = footprint_size
		color_rect.position = -footprint_size / 2.0
		if b.type_id == "command_center":
			color_rect.color = Color(0.2, 0.4, 0.8)
		else:
			color_rect.color = Color(0.5, 0.5, 0.5)
		node.add_child(color_rect)
		
	if not b.complete:
		var main_visual: CanvasItem = node.get_child(0)
		main_visual.modulate = Color(0.6, 0.8, 1.0, 0.55)
		if node.get_node_or_null("TurretBarrel"):
			var barrel_visual: CanvasItem = node.get_node("TurretBarrel")
			barrel_visual.modulate = Color(0.6, 0.8, 1.0, 0.55)
		elif node.get_child_count() > 1 and node.get_child(1) is Sprite2D:
			var top_visual: CanvasItem = node.get_child(1)
			top_visual.modulate = Color(0.6, 0.8, 1.0, 0.55)
			
		var scaffold_path: String = PIXEL_DIR + ("construction_2x2.png" if (b.size.x >= 2 or b.size.y >= 2) else "construction_1x1.png")
		if ResourceLoader.exists(scaffold_path):
			var scaffold_tex: Texture2D = load(scaffold_path) as Texture2D
			if scaffold_tex:
				var scaffold: Sprite2D = Sprite2D.new()
				scaffold.name = "Scaffold"
				apply_pixel_sprite(scaffold, scaffold_tex, footprint_size)
				node.add_child(scaffold)
		
		var bg_width := footprint_size.x - 8.0
		var bg_height := 6.0
		var bg := ColorRect.new()
		bg.name = "ProgressBg"
		bg.color = Color(0.1, 0.1, 0.1, 0.8)
		bg.size = Vector2(bg_width, bg_height)
		bg.position = Vector2(-bg_width / 2.0, footprint_size.y / 2.0 - bg_height - 4.0)
		node.add_child(bg)
		
		var fill := ColorRect.new()
		fill.name = "ProgressFill"
		fill.color = Color(1.0, 0.9, 0.2, 1.0)
		fill.size = Vector2(0, bg_height)
		fill.position = bg.position
		node.add_child(fill)
		
		update_progress(node, b)
	else:
		var hp_bar := HpBar.new()
		hp_bar.name = "HpBar"
		hp_bar.bar_width = footprint_size.x - 8.0
		hp_bar.y_offset = footprint_h / 2.0 - tex_h * float(Grid.PIXEL_SCALE) - 4.0
		node.add_child(hp_bar)
		update_hp_bar(node, b)
		
	update_aim(node, b)
	return node

## Completed Campfire: lit flicker loop plus the standard HP bar. No sim
## ticks; the AnimatedSprite2D advances on its own and the node is rebuilt
## on completion and freed on destruction like any other building.
static func make_campfire_lit(footprint_size: Vector2, b: Building) -> Node2D:
	var node: Node2D = Node2D.new()
	node.position = b.center_world()
	node.y_sort_enabled = false
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = campfire_lit_frames()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(Grid.PIXEL_SCALE, Grid.PIXEL_SCALE)
	sprite.centered = true
	sprite.position = Vector2(0.0, footprint_size.y / 2.0)
	sprite.offset = Vector2(0.0, -Grid.PX_TILE / 2.0)
	sprite.play("default")
	node.add_child(sprite)
	var hp_bar := HpBar.new()
	hp_bar.name = "HpBar"
	hp_bar.bar_width = footprint_size.x - 8.0
	hp_bar.y_offset = footprint_size.y / 2.0 - Grid.PX_TILE * float(Grid.PIXEL_SCALE) - 4.0
	node.add_child(hp_bar)
	update_hp_bar(node, b)
	return node

static func update_hp_bar(node: Node2D, b: Building) -> void:
	if not b.complete:
		return
	var hp_bar: HpBar = node.get_node_or_null("HpBar")
	if hp_bar:
		var hp_ratio: float = float(b.hp) / float(b.max_hp)
		hp_bar.set_ratio(hp_ratio)

static func update_progress(node: Node2D, b: Building) -> void:
	if b.complete:
		return
	var bg: ColorRect = node.get_node_or_null("ProgressBg")
	var fill: ColorRect = node.get_node_or_null("ProgressFill")
	if bg and fill:
		fill.size.x = bg.size.x * b.progress_ratio()

static func update_aim(node: Node2D, b: Building) -> void:
	if b.type_id != "turret" or not b.complete:
		return
	var barrel: Sprite2D = node.get_node_or_null("TurretBarrel") as Sprite2D
	if barrel:
		var dir := "down"
		if b.aim == Vector2.ZERO or b.aim.is_zero_approx():
			dir = "down"
		elif absf(b.aim.x) >= absf(b.aim.y):
			dir = "right" if b.aim.x >= 0.0 else "left"
		else:
			dir = "down" if b.aim.y >= 0.0 else "up"
		var tex: Texture2D = get_barrel_texture(dir)
		if tex and barrel.texture != tex:
			barrel.texture = tex
		barrel.rotation = 0.0
