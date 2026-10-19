class_name DawnReport extends RefCounted

static func objective_text(day: int, nights_to_win: int, tower_state: String, tower_unlock_day: int, endless: bool = false) -> String:
	if endless:
		return "Survive as long as you can (Endless, night %d)" % maxi(0, day - 1)
	var nights_survived: int = day - 1
	var left: int = nights_to_win - nights_survived
	
	if tower_state == "complete":
		if left <= 0:
			return "Radio Tower ready. Rescue comes at the next dawn."
		else:
			var s: String = "night" if left == 1 else "nights"
			return "Radio Tower ready. Survive %d more %s for rescue." % [left, s]
	else:
		if left <= 0:
			return "Nights are getting worse. Finish the Radio Tower!"
			
		var tower_str: String = ""
		if tower_state == "building":
			tower_str = "Radio Tower under construction."
		else:
			if day < tower_unlock_day:
				tower_str = "Build the Radio Tower (unlocks day %d)." % tower_unlock_day
			else:
				tower_str = "Build the Radio Tower."
				
		var s: String = "night" if left == 1 else "nights"
		return "%s %d %s to go." % [tower_str, left, s]

static func lines(report: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var zombies_killed: int = int(report.get("zombies_killed", 0))
	if zombies_killed > 0:
		out.append("Zombies killed: %d" % zombies_killed)
	
	var survivors_killed: Array = report.get("survivors_killed", [])
	if survivors_killed.size() > 0:
		out.append("Lost: %s" % ", ".join(survivors_killed))
		
	var b_destroyed: Array = report.get("buildings_destroyed", [])
	if b_destroyed.size() > 0:
		out.append("Destroyed: %s" % ", ".join(b_destroyed))
		
	var b_damaged: int = int(report.get("buildings_damaged", 0))
	if b_damaged > 0:
		var s: String = "building" if b_damaged == 1 else "buildings"
		out.append("Damaged: %d %s" % [b_damaged, s])
		
	var cc_damage: int = int(report.get("cc_damage", 0))
	if cc_damage > 0:
		out.append("Command Center took %d damage" % cc_damage)
		
	var food: int = int(report.get("food_eaten", 0))
	if food > 0:
		out.append("Food eaten: %d" % food)
		
	var hungry: Array = report.get("hungry", [])
	if hungry.size() > 0:
		out.append("Hungry: %s" % ", ".join(hungry))
		
	var left_s: Array = report.get("left", [])
	if left_s.size() > 0:
		out.append("Left: %s" % ", ".join(left_s))
		
	var arrived: Array = report.get("arrived", [])
	if arrived.size() > 0:
		out.append("Arrived: %s" % ", ".join(arrived))

	var scavenging: Array = report.get("scavenging", [])
	for entry: Variant in scavenging:
		if entry is Dictionary:
			var s_name: String = str((entry as Dictionary).get("name", "?"))
			out.append("Scavenging (%s): %s" % [s_name, ScavengeToast.dawn_value(entry as Dictionary)])

	var unlocked: Array = report.get("unlocked", [])
	if unlocked.size() > 0:
		out.append("New buildings unlocked: %s" % ", ".join(unlocked))
		
	var obj: String = str(report.get("objective", ""))
	if obj != "":
		out.append(obj)
		
	return out
