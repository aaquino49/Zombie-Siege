extends TestCase
## T-033: keep the Windows release packaging contract covered without requiring a build in tests.


func test_windows_preset_embeds_pck_and_excludes_tests() -> void:
	var preset: ConfigFile = ConfigFile.new()
	var result: Error = preset.load("res://export_presets.cfg")
	assert_eq(result, OK, "Windows export preset must exist and parse")
	if result != OK:
		return
	assert_eq(preset.get_value("preset.0", "name", ""), "Windows Desktop")
	assert_eq(preset.get_value("preset.0", "platform", ""), "Windows Desktop")
	assert_eq(preset.get_value("preset.0", "export_path", ""), "../builds/ZombieSiege.exe")
	assert_eq(preset.get_value("preset.0", "export_filter", ""), "all_resources")
	assert_eq(preset.get_value("preset.0", "exclude_filter", ""), "tests/*", "Exclude tests while retaining runtime scenarios")
	assert_eq(preset.get_value("preset.0.options", "binary_format/embed_pck", false), true, "Release must be a single executable")
	assert_eq(preset.get_value("preset.0.options", "binary_format/architecture", ""), "x86_64")


func test_release_version_matches_windows_product_version() -> void:
	var preset: ConfigFile = ConfigFile.new()
	var result: Error = preset.load("res://export_presets.cfg")
	assert_eq(result, OK)
	if result != OK:
		return
	assert_eq(ProjectSettings.get_setting("application/config/version", ""), "1.7.0")
	assert_eq(preset.get_value("preset.0.options", "application/file_version", ""), "1.7.0.0")
	assert_eq(preset.get_value("preset.0.options", "application/product_version", ""), "1.7.0.0")
