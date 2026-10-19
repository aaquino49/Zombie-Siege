extends TestCase
## T-038: unknown costs preserve stock and the documented skip semantics.

var _events: Array = []

func _record_change(kind: String, amount: int) -> void:
	_events.append([kind, amount])

func _seeded_store() -> ResourceStore:
	var store: ResourceStore = ResourceStore.new(GameData.load_default())
	store.changed.connect(_record_change)
	return store

func _snapshot(store: ResourceStore) -> Dictionary:
	var amounts: Dictionary = {}
	for kind: String in ResourceStore.KINDS:
		amounts[kind] = store.get_amount(kind)
	return amounts

func test_can_afford_unknown_positive_rejects_nonpositive_skips_without_mutation() -> void:
	var store: ResourceStore = _seeded_store()
	var before: Dictionary = _snapshot(store)
	assert_false(store.can_afford({"gold": 1}))
	assert_true(store.can_afford({"gold": 0}))
	assert_true(store.can_afford({"gold": -1}))
	assert_eq(_snapshot(store), before)
	assert_eq(_events.size(), 0)

func test_spend_mixed_unknown_positive_is_atomic_with_existing_stock() -> void:
	var store: ResourceStore = _seeded_store()
	var before: Dictionary = _snapshot(store)
	assert_false(store.spend({"wood": 10, "gold": 1}))
	assert_eq(_snapshot(store), before)
	assert_eq(_events.size(), 0)

func test_spend_skips_nonpositive_unknown_and_spends_valid_cost() -> void:
	var store: ResourceStore = _seeded_store()
	var before: Dictionary = _snapshot(store)
	assert_true(store.spend({"gold": 0, "wood": 10}))
	assert_true(store.spend({"gold": -1}))
	before["wood"] -= 10
	assert_eq(_snapshot(store), before)
	assert_eq(_events, [["wood", before["wood"]]])

func test_refund_unknown_first_skips_and_refunds_valid_kind_only() -> void:
	var store: ResourceStore = _seeded_store()
	var before: Dictionary = _snapshot(store)
	store.refund({"gold": 5, "wood": 10}, 1.0)
	before["wood"] += 10
	assert_eq(_snapshot(store), before)
	assert_eq(_events, [["wood", before["wood"]]])
