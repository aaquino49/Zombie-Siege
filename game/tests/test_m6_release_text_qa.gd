extends TestCase
## T-113: the owner-requested glyphs and fi/fl remain separate at every UI size.

func test_required_glyphs_and_finish_shape_at_all_ui_sizes() -> void:
	var theme: Theme = load("res://assets/pixel/ui/game_theme.tres") as Theme
	var font: Font = theme.default_font
	var server: TextServer = TextServerManager.get_primary_interface()
	for size: int in [UiFont.NATIVE, UiFont.BODY, UiFont.LARGE, UiFont.TITLE, UiFont.BANNER]:
		for sample: String in ["vwy g", "0123456789Ss", "finish", "flag"]:
			for character: String in sample:
				assert_true(font.has_char(character.unicode_at(0)), "Required glyph %s at size %d" % [character, size])
			var shaped: RID = server.create_shaped_text()
			assert_true(server.shaped_text_add_string(shaped, sample, font.get_rids(), size, font.get_opentype_features()))
			assert_true(server.shaped_text_shape(shaped))
			assert_eq(server.shaped_text_get_glyph_count(shaped), sample.length(),
				"%s has one glyph per character at size %d; finish cannot become Anish" % [sample, size])
			server.free_rid(shaped)
