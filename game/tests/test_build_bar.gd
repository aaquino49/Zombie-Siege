extends TestCase

var _state: GameState
var _bar: BuildBar

func before_each() -> void:
	_state = GameState.new(GameData.load_default(), 1337)
	_bar = preload("res://scenes/ui/build_bar.tscn").instantiate() as BuildBar
	_bar.bind(_state)

func after_each() -> void:
	if _bar != null:
		_bar.free()

func _get_buttons() -> Array[Button]:
	var panel := _bar.get_node("Panel")
	var hbox := panel.get_node("HBox")
	var btns: Array[Button] = []
	for c in hbox.get_children():
		btns.append(c as Button)
	return btns

func test_day1_buttons() -> void:
	var btns := _get_buttons()
	assert_eq(btns.size(), 4)
	if btns.size() == 4:
		assert_eq(btns[0].get_meta("type_id"), "wooden_wall")
		assert_eq(btns[1].get_meta("type_id"), "gate")
		assert_eq(btns[2].get_meta("type_id"), "farm")
		assert_eq(btns[3].get_meta("type_id"), "shelter")

func test_day2_buttons() -> void:
	var max_iter := 1000
	var iters := 0
	while _state.clock.day < 2 and iters < max_iter:
		_state.clock.advance(1.0)
		iters += 1
		
	var btns := _get_buttons()
	assert_eq(btns.size(), 8)
	
	var has_cmd := false
	var has_reinf := false
	for b in btns:
		var tid: String = b.get_meta("type_id")
		if tid == "command_center": has_cmd = true
		if tid == "reinforced_wall": has_reinf = true
	assert_false(has_cmd, "command_center should not appear")
	assert_false(has_reinf, "reinforced_wall should not appear")

func test_cost_text() -> void:
	assert_eq(BuildBar.cost_text({"wood": 5, "scrap": 0}), "5 wood")
	assert_eq(BuildBar.cost_text({"wood": 25, "scrap": 5}), "25 wood · 5 scrap")
	assert_eq(BuildBar.cost_text({"wood": 0, "scrap": 0}), "Free")
	
func test_button_content() -> void:
	var btns := _get_buttons()
	for b in btns:
		var tid: String = b.get_meta("type_id")
		var b_data: Dictionary = _state.data.get_building(tid)
		var b_name: String = b_data.get("name", tid)
		var cost_dict: Dictionary = b_data.get("cost", {})
		var cost_row := b.get_node("Content/Cost") as HBoxContainer
		assert_not_null(cost_row, "Cost is an icon/number row")
		assert_eq(b.tooltip_text, "", "Info card replaces the tiny tooltip")
		var name_lines: Array[String] = []
		for child: Node in b.get_node("Content").get_children():
			if child is Label:
				name_lines.append((child as Label).text)
		assert_eq(" ".join(name_lines), b_name, "Caption contains every whole word")
		assert_not_null((b.get_node("Content/Icon") as TextureRect).texture)

func test_affordability() -> void:
	var btns := _get_buttons()
	var shelter_btn: Button = null
	for b in btns:
		if b.get_meta("type_id") == "shelter":
			shelter_btn = b
			break
			
	assert_not_null(shelter_btn)
	if shelter_btn:
		assert_eq(shelter_btn.modulate.a, 1.0)
		
		# take all wood
		var wood: int = _state.resources.get_amount("wood")
		_state.resources.take("wood", wood)
		assert_eq(shelter_btn.modulate.a, 0.5)
		
		# add wood back
		_state.resources.add("wood", wood)
		assert_eq(shelter_btn.modulate.a, 1.0)

func test_set_active_type() -> void:
	var emissions := [0]
	var l := func(tid: String) -> void: emissions[0] += 1
	_bar.building_selected.connect(l)
	
	_bar.set_active_type("farm")
	var btns := _get_buttons()
	for b in btns:
		if b.get_meta("type_id") == "farm":
			assert_true(b.button_pressed)
		else:
			assert_false(b.button_pressed)
			
	assert_eq(emissions[0], 0)

func test_toggling_emits() -> void:
	var emits: Array[String] = []
	var l := func(tid: String) -> void: emits.append(tid)
	_bar.building_selected.connect(l)
	
	var btns := _get_buttons()
	var gate_btn: Button = null
	for b in btns:
		if b.get_meta("type_id") == "gate":
			gate_btn = b
			break
			
	assert_not_null(gate_btn)
	if gate_btn:
		gate_btn.button_pressed = true
		assert_eq(emits.size(), 1)
		if emits.size() > 0:
			assert_eq(emits[0], "gate")

func test_active_button_kept_across_dawn() -> void:
	_bar.set_active_type("wooden_wall")
	
	var emissions := [0]
	var l := func(tid: String) -> void: emissions[0] += 1
	_bar.building_selected.connect(l)
	
	var max_iter := 1000
	var iters := 0
	while _state.clock.day < 2 and iters < max_iter:
		_state.clock.advance(1.0)
		iters += 1
		
	assert_eq(_state.clock.day, 2, "Clock must reach day 2 for the dawn regression")
	var btns := _get_buttons()
	assert_eq(btns.size(), 8, "Dawn must rebuild the bar with day-2 unlocks")
	var wood_btn: Button = null
	for b in btns:
		if b.get_meta("type_id") == "wooden_wall":
			wood_btn = b
			break
			
	assert_not_null(wood_btn)
	if wood_btn:
		assert_true(wood_btn.button_pressed)
		
	assert_eq(emissions[0], 0, "building_selected should not be emitted during rebuild")
