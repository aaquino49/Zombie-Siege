extends TestCase
## Acceptance coverage for mutation signals and no-op operations.

var _events: Array = []

func _record_change(kind: String, amount: int) -> void:
	_events.append([kind, amount])

func test_spend_and_refund_emit_only_changed_kinds_with_final_amounts() -> void:
	var store := ResourceStore.new(null)
	store.add("wood", 10)
	store.add("scrap", 5)
	store.changed.connect(_record_change)
	assert_true(store.spend({"wood": 5, "scrap": 2, "ammo": 0}))
	assert_eq(_events.size(), 2)
	assert_has(_events, ["wood", 5])
	assert_has(_events, ["scrap", 3])
	_events.clear()
	store.refund({"wood": 5, "scrap": 3, "ammo": 1}, 0.5)
	assert_eq(_events.size(), 2)
	assert_has(_events, ["wood", 7])
	assert_has(_events, ["scrap", 4])
	assert_eq(store.get_amount("ammo"), 0)

func test_no_op_and_failed_operations_emit_nothing() -> void:
	var store := ResourceStore.new(null)
	store.add("wood", 10)
	store.changed.connect(_record_change)
	assert_true(store.can_afford({}))
	assert_true(store.spend({}))
	assert_true(store.spend({"wood": 0}))
	assert_false(store.spend({"wood": 5, "scrap": 1}))
	store.add("wood", 0)
	assert_eq(store.take("wood", 0), 0)
	assert_eq(store.take("food", 8), 0)
	store.refund({"wood": 9}, 0.0)
	store.refund({"wood": 1}, 0.5)
	store.refund({}, 0.5)
	assert_eq(_events.size(), 0)
	assert_eq(store.get_amount("wood"), 10)
	for kind: String in ResourceStore.KINDS:
		assert_true(store.get_amount(kind) >= 0)

func test_capped_take_reports_zero_once_and_stays_nonnegative() -> void:
	var store := ResourceStore.new(null)
	store.add("food", 3)
	store.changed.connect(_record_change)
	assert_eq(store.take("food", 100), 3)
	assert_eq(_events, [["food", 0]])
	assert_eq(store.take("food", 100), 0)
	assert_eq(_events.size(), 1)
	assert_eq(store.get_amount("food"), 0)
