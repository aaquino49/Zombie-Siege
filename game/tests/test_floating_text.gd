extends TestCase

func test_floating_text_lifecycle_and_pooling() -> void:
	var layer := FloatingTextLayer.new()
	
	layer.spawn("+10 wood", Vector2(100, 100), "wood")
	assert_eq(layer._active.size(), 1)
	assert_eq(layer._pool.size(), 0)
	assert_eq(layer.get_child_count(), 1)
	
	var label: Label = layer.get_child(0)
	assert_eq(label.text, "+10 wood")
	assert_true(label.visible)
	
	layer.advance(1.3)
	assert_eq(layer._active.size(), 0)
	assert_eq(layer._pool.size(), 1)
	assert_false(label.visible)
	
	for i in range(40):
		layer.spawn("+1 scrap", Vector2(0, 0), "scrap")
		
	assert_eq(layer.get_child_count(), 32)
	assert_true(layer._active.size() <= 32)
	
	layer.free()
