class_name ScavengeToast extends RefCounted
## Shared scavenging text: button reasons, return toasts and Dawn Report values.
## Pure helpers so unit tests can check the wording without a live HUD.

const LOOT_ORDER: Array[String] = ["wood", "scrap", "food", "ammo"]

static func reason_text(reason: String) -> String:
	match reason:
		"":
			return ""
		"not morning":
			return "Only in the morning"
		"guard":
			return "Guards stay on watch"
		"already away":
			return "Already out"
		"run limit":
			return "No more runs today"
		"sheltered":
			return "Can't leave the shelter"
		_:
			return ""

static func loot_text(loot: Dictionary) -> String:
	var parts: Array[String] = []
	for kind: String in LOOT_ORDER:
		var amount: int = int(loot.get(kind, 0))
		if amount > 0:
			parts.append("+%d %s" % [amount, kind])
	return ", ".join(parts)

static func text(survivor_name: String, result: Dictionary) -> String:
	if bool(result.get("lost", false)):
		return "%s didn't come back" % survivor_name
	var loot: String = loot_text(result.get("loot", {}) as Dictionary)
	var base: String
	if bool(result.get("hurt", false)):
		base = "%s came back hurt" % survivor_name
	else:
		base = "%s is back" % survivor_name
	if loot != "":
		base += ": " + loot
	if bool(result.get("newcomer", false)):
		base += ", and found a newcomer"
	return base

static func dawn_value(entry: Dictionary) -> String:
	if bool(entry.get("lost", false)):
		return "didn't come back"
	var loot: String = loot_text(entry.get("loot", {}) as Dictionary)
	var shown: String = loot if loot != "" else "no loot"
	if bool(entry.get("hurt", false)):
		return "(hurt) " + shown
	return shown

## Morale toasts reuse the scavenging toast box (GDD §22.7). Values are read
## from the mood config so they stay right after balance passes.
static func feast_text(state: GameState) -> String:
	var value: int = 10
	var moods: Dictionary = state.data.morale_config().get("moods", {})
	if moods.has("feast"):
		value = int((moods["feast"] as Dictionary).get("value", value))
	return "Feast! Everyone +%d morale" % value

static func refusal_text(survivor_name: String) -> String:
	return "%s refuses to work today" % survivor_name

static func refusal_texts(report: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var morale: Dictionary = report.get("morale", {})
	for survivor_name: String in morale.get("refusing", []):
		out.append(refusal_text(survivor_name))
	return out

## Pushes an already-formatted line into the HUD scavenging toast queue
## without touching hud.gd. No-ops outside the live tree (unit tests).
## Takes Variant so tests can pass a mock with the same two members.
static func push_to_hud(hud: Variant, text: String) -> bool:
	if hud == null or not (hud is Object):
		return false
	if text.is_empty() or not (hud as Object).has_method("_pump_toasts"):
		return false
	var queue: Array = (hud as Object).get("_toast_queue")
	queue.append({"text": text})
	(hud as Object).set("_toast_queue", queue)
	(hud as Object).call("_pump_toasts")
	return true
