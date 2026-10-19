class_name DifficultyPicker extends CanvasLayer

const CONTENT := "Dim/Center/Panel/Margin/Content/"
const LEVELS: Array[String] = ["easy", "normal", "hard"]

var _data: GameData

func _ready() -> void:
	MenuStyle.apply(get_node(CONTENT + "Title").get_parent(), MenuStyle.CREAM)
	for difficulty: String in LEVELS:
		get_node(CONTENT + "Options/" + difficulty.capitalize() + "/Select").pressed.connect(_choose.bind(difficulty))
	get_node(CONTENT + "SeedRow/Reroll").pressed.connect(_reroll)
	get_node(CONTENT + "Buttons/Back").pressed.connect(close)

func open(data: GameData, selected_override: String = "") -> void:
	_data = data
	_refresh_descriptions()
	get_node(CONTENT + "SeedRow/Seed").text = "Seed: %d" % Game.preview_seed
	visible = true
	var selected: String = selected_override if selected_override in LEVELS else GameSettings.load_difficulty()
	get_node(CONTENT + "Options/" + selected.capitalize() + "/Select").grab_focus()

func close() -> void:
	visible = false
	var menu: MainMenu = get_parent() as MainMenu
	if menu:
		menu.get_node("Dim/Center/Panel/Margin/Content/Buttons/NewGame").grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("cancel") and not event.is_echo():
		close()
		get_viewport().set_input_as_handled()

func _refresh_descriptions() -> void:
	var all: Dictionary = _data.balance("difficulty")
	for difficulty: String in LEVELS:
		var config: Dictionary = all.get(difficulty, {})
		get_node(CONTENT + "Options/" + difficulty.capitalize() + "/Description").text = _description(difficulty, config)

static func _description(difficulty: String, config: Dictionary) -> String:
	var description: String
	var wave_mult: float = float(config.get("wave_size_mult", 1.0))
	if is_equal_approx(wave_mult, 1.0):
		description = "The intended siege"
	else:
		var percent: int = roundi(absf(wave_mult - 1.0) * 100.0)
		description = "Hordes %d%% %s" % [percent, "smaller" if wave_mult < 1.0 else "bigger"]
	var extras: Array[String] = []
	for key: String in ["zombie_hp_mult", "start_resource_mult", "food_eaten_mult"]:
		var multiplier: float = float(config.get(key, 1.0))
		if is_equal_approx(multiplier, 1.0):
			continue
		var percent: int = roundi(absf(multiplier - 1.0) * 100.0)
		var direction: String = "more" if multiplier > 1.0 else "less"
		var label: String = "zombie HP" if key == "zombie_hp_mult" else "starting supplies" if key == "start_resource_mult" else "food use"
		extras.append("%d%% %s %s" % [percent, direction, label])
	if not extras.is_empty():
		description += " · " + ", ".join(PackedStringArray(extras))
	return description

func _choose(difficulty: String) -> void:
	visible = false
	Game.start_new_game(difficulty, Game.preview_seed)

func _reroll() -> void:
	get_node(CONTENT + "SeedRow/Seed").text = "Seed: %d" % Game.reroll_seed()
