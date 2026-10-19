class_name HowToPlay extends MenuScreen

static func morale_text() -> String:
	return "Morale. Each survivor's mood (0-100) sets how fast they work and how well guards shoot. Beds, food, campfires, feasts, days off and quiet nights help; deaths, hunger and rough nights hurt. A Breaking survivor refuses to work, and two Breaking mornings in a row means they leave."

static func research_text() -> String:
	return "Research. Build a Field Lab (day 3) and assign Researchers. Press T to pick one upgrade at a time from Defense, Economy or Survivors. Research is optional: the Radio Tower never needs it."

func bind(data: GameData) -> void:
	initialize()
	get_node(CONTENT + "Scroll/Sections/Goal").text = "Survive %d nights, finish the Radio Tower, and get rescued at dawn. Protect your Command Center and keep your survivors alive." % int(data.balance("nights_to_win", 20))
	get_node(CONTENT + "Scroll/Sections/Morale").text = HowToPlay.morale_text()
	get_node(CONTENT + "Scroll/Sections/Research").text = HowToPlay.research_text()
