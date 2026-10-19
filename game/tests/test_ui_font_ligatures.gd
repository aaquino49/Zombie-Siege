extends TestCase

func test_theme_font_disables_standard_and_contextual_ligatures() -> void:
	var theme: Theme = load("res://assets/pixel/ui/game_theme.tres") as Theme
	var font: FontVariation = theme.default_font as FontVariation
	assert_not_null(font, "Theme default font is a FontVariation")
	if font == null:
		return
	assert_eq(font.base_font, load("res://assets/pixel/ui/font/siege_pixel.ttf"), "Variation keeps the original pixel font")
	var text_server: TextServer = TextServerManager.get_primary_interface()
	for feature: String in ["liga", "clig"]:
		assert_eq(font.opentype_features.get(text_server.name_to_tag(feature), -1), 0, "%s is disabled" % feature)

func test_theme_font_shapes_fi_and_fl_as_separate_letters() -> void:
	var theme: Theme = load("res://assets/pixel/ui/game_theme.tres") as Theme
	var font: Font = theme.default_font
	var text_server: TextServer = TextServerManager.get_primary_interface()
	for word: String in ["finish", "flag"]:
		var shaped: RID = text_server.create_shaped_text()
		assert_true(text_server.shaped_text_add_string(shaped, word, font.get_rids(), UiFont.BODY, font.get_opentype_features()), "Add %s to the shaper" % word)
		assert_true(text_server.shaped_text_shape(shaped), "Shape %s" % word)
		assert_eq(text_server.shaped_text_get_glyph_count(shaped), word.length(), "%s has one glyph per letter" % word)
		text_server.free_rid(shaped)
