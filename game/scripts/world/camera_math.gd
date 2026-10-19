class_name CameraMath extends RefCounted

const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.0

static func clamp_position(pos: Vector2, zoom: float, viewport: Vector2, map_px: Vector2) -> Vector2:
	var visible_size := viewport / zoom
	var result := pos
	
	if visible_size.x >= map_px.x:
		result.x = map_px.x / 2.0
	else:
		var half_w := visible_size.x / 2.0
		result.x = clampf(result.x, half_w, map_px.x - half_w)
		
	if visible_size.y >= map_px.y:
		result.y = map_px.y / 2.0
	else:
		var half_h := visible_size.y / 2.0
		result.y = clampf(result.y, half_h, map_px.y - half_h)
		
	return result

static func clamp_zoom(z: float) -> float:
	return clampf(z, ZOOM_MIN, ZOOM_MAX)

static func zoom_toward(pos: Vector2, old_zoom: float, new_zoom: float, cursor_offset: Vector2) -> Vector2:
	return pos + cursor_offset / old_zoom - cursor_offset / new_zoom

static func viewport_size_for(node: Node) -> Vector2:
	if node.is_inside_tree():
		return node.get_viewport().get_visible_rect().size
	return Vector2(float(ProjectSettings.get_setting("display/window/size/viewport_width")), float(ProjectSettings.get_setting("display/window/size/viewport_height")))
