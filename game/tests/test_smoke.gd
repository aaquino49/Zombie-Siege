extends TestCase
## Sanity checks for the test harness itself and the project wiring.


func test_harness_works() -> void:
	assert_eq(1 + 1, 2)
	assert_almost_eq(0.1 + 0.2, 0.3, 0.0001)


func test_main_scene_loads() -> void:
	var main_path: String = ProjectSettings.get_setting("application/run/main_scene")
	assert_true(ResourceLoader.exists(main_path), "main scene missing: " + main_path)
	var packed: PackedScene = load(main_path)
	assert_not_null(packed)
	var main := packed.instantiate()
	assert_not_null(main)
	main.free()
