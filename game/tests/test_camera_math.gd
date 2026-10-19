extends TestCase


func test_each_edge_at_all_required_zooms() -> void:
	var map_px := Vector2(3072, 3072)
	var viewport := Vector2(1280, 720)
	for z: float in [0.5, 1.0, 2.0]:
		var half_size: Vector2 = viewport / z / 2.0
		var center: Vector2 = map_px / 2.0
		assert_eq(CameraMath.clamp_position(Vector2(-100, center.y), z, viewport, map_px), Vector2(half_size.x, center.y), "Left edge at %s" % z)
		assert_eq(CameraMath.clamp_position(Vector2(4000, center.y), z, viewport, map_px), Vector2(map_px.x - half_size.x, center.y), "Right edge at %s" % z)
		assert_eq(CameraMath.clamp_position(Vector2(center.x, -100), z, viewport, map_px), Vector2(center.x, half_size.y), "Top edge at %s" % z)
		assert_eq(CameraMath.clamp_position(Vector2(center.x, 4000), z, viewport, map_px), Vector2(center.x, map_px.y - half_size.y), "Bottom edge at %s" % z)
		assert_eq(CameraMath.clamp_position(center, z, viewport, map_px), center, "Interior must stay put")

func test_oversized_view_centers_only_the_oversized_axis() -> void:
	assert_eq(CameraMath.clamp_position(Vector2(-100, -100), 1.0, Vector2(1280, 720), Vector2(1000, 3000)), Vector2(500, 360))
	assert_eq(CameraMath.clamp_position(Vector2(4000, 4000), 1.0, Vector2(1280, 720), Vector2(3000, 600)), Vector2(2360, 300))

func test_zoom_toward_preserves_world_anchor_in_both_directions() -> void:
	var pos := Vector2(1536, 1536)
	for offset: Vector2 in [Vector2.ZERO, Vector2(-500, -250), Vector2(400, 200)]:
		for zoom_pair: Vector2 in [Vector2(0.5, 2.0), Vector2(2.0, 0.5), Vector2(1.0, 1.1)]:
			var new_pos: Vector2 = CameraMath.zoom_toward(pos, zoom_pair.x, zoom_pair.y, offset)
			var before: Vector2 = pos + offset / zoom_pair.x
			var after: Vector2 = new_pos + offset / zoom_pair.y
			assert_almost_eq(after.x, before.x, 0.01, "Cursor world x")
			assert_almost_eq(after.y, before.y, 0.01, "Cursor world y")
			if offset == Vector2.ZERO:
				assert_eq(new_pos, pos, "Center cursor must not move camera")

func test_clamp_position_zoomed_in():
	var map_px := Vector2(3000, 3000)
	var vp := Vector2(1000, 1000)
	
	var visible := vp / 2.0
	var half_size := visible / 2.0
	
	var pos: Vector2 = CameraMath.clamp_position(Vector2(0, 0), 2.0, vp, map_px)
	assert_eq(pos, half_size, "Should clamp to top left")
	
	pos = CameraMath.clamp_position(Vector2(4000, 4000), 2.0, vp, map_px)
	assert_eq(pos, map_px - half_size, "Should clamp to bottom right")

func test_clamp_position_zoomed_out():
	var map_px := Vector2(3000, 3000)
	var vp := Vector2(1000, 1000)
	
	var half_size := vp / 0.5 / 2.0
	
	var pos: Vector2 = CameraMath.clamp_position(Vector2(0, 0), 0.5, vp, map_px)
	assert_eq(pos, half_size, "Should clamp to top left zoomed out")
	
	pos = CameraMath.clamp_position(Vector2(4000, 4000), 0.5, vp, map_px)
	assert_eq(pos, map_px - half_size, "Should clamp to bottom right zoomed out")

func test_clamp_position_view_bigger_than_map():
	var map_px := Vector2(500, 500)
	var vp := Vector2(1000, 1000)
	var pos: Vector2 = CameraMath.clamp_position(Vector2(100, 100), 1.0, vp, map_px)
	assert_eq(pos, Vector2(250, 250), "Should center when view is bigger than map")

func test_clamp_zoom():
	assert_eq(CameraMath.clamp_zoom(0.1), 0.5, "Clamp min zoom")
	assert_eq(CameraMath.clamp_zoom(1.0), 1.0, "Leave valid zoom")
	assert_eq(CameraMath.clamp_zoom(3.0), 2.0, "Clamp max zoom")

func test_zoom_toward():
	var pos := Vector2(1000, 1000)
	var cursor_offset := Vector2(100, -100)
	
	var new_pos: Vector2 = CameraMath.zoom_toward(pos, 1.0, 2.0, cursor_offset)
	assert_eq(new_pos, Vector2(1050, 950), "Zooming toward cursor")
	
	new_pos = CameraMath.zoom_toward(pos, 1.0, 2.0, Vector2.ZERO)
	assert_eq(new_pos, pos, "Zooming at center")
