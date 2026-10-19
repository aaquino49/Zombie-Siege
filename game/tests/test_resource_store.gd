extends TestCase

var _last_changed_kind: String = ""
var _last_changed_amount: int = -1
var _changed_count: int = 0

func _on_store_changed(kind: String, amount: int) -> void:
	_last_changed_kind = kind
	_last_changed_amount = amount
	_changed_count += 1

func test_start_values() -> void:
	var data: GameData = GameData.load_default()
	var store: ResourceStore = ResourceStore.new(data)
	assert_eq(store.get_amount("food"), int(data.balance("start_food", 0)))
	assert_eq(store.get_amount("wood"), int(data.balance("start_wood", 0)))
	assert_eq(store.get_amount("scrap"), int(data.balance("start_scrap", 0)))
	assert_eq(store.get_amount("ammo"), int(data.balance("start_ammo", 0)))

func test_add_and_take() -> void:
	var store: ResourceStore = ResourceStore.new(null)
	store.add("wood", 10)
	assert_eq(store.get_amount("wood"), 10)
	var taken: int = store.take("wood", 5)
	assert_eq(taken, 5)
	assert_eq(store.get_amount("wood"), 5)

func test_take_caps_at_current_amount() -> void:
	var store: ResourceStore = ResourceStore.new(null)
	store.add("food", 5)
	var taken: int = store.take("food", 10)
	assert_eq(taken, 5)
	assert_eq(store.get_amount("food"), 0)

func test_can_afford() -> void:
	var store: ResourceStore = ResourceStore.new(null)
	store.add("wood", 10)
	store.add("scrap", 5)
	
	assert_true(store.can_afford({"wood": 10, "scrap": 5}))
	assert_true(store.can_afford({"wood": 5}))
	assert_true(store.can_afford({"wood": 5, "ammo": 0}))
	
	assert_false(store.can_afford({"wood": 11}))
	assert_false(store.can_afford({"wood": 10, "scrap": 6}))
	assert_false(store.can_afford({"ammo": 1}))

func test_spend_success() -> void:
	var store: ResourceStore = ResourceStore.new(null)
	store.add("wood", 10)
	store.add("scrap", 5)
	
	var success: bool = store.spend({"wood": 5, "scrap": 2})
	assert_true(success)
	assert_eq(store.get_amount("wood"), 5)
	assert_eq(store.get_amount("scrap"), 3)

func test_spend_failure_is_atomic() -> void:
	var store: ResourceStore = ResourceStore.new(null)
	store.add("wood", 10)
	store.add("scrap", 5)
	
	var success: bool = store.spend({"wood": 5, "scrap": 10})
	assert_false(success)
	assert_eq(store.get_amount("wood"), 10)
	assert_eq(store.get_amount("scrap"), 5)

func test_refund_floors() -> void:
	var store: ResourceStore = ResourceStore.new(null)
	store.refund({"wood": 5}, 0.5)
	assert_eq(store.get_amount("wood"), 2)

func test_changed_signal() -> void:
	var store: ResourceStore = ResourceStore.new(null)
	store.changed.connect(_on_store_changed)
	
	_changed_count = 0
	store.add("wood", 10)
	assert_eq(_changed_count, 1)
	assert_eq(_last_changed_kind, "wood")
	assert_eq(_last_changed_amount, 10)
	
	_changed_count = 0
	store.add("wood", 0)
	assert_eq(_changed_count, 0)
	
	_changed_count = 0
	store.take("wood", 5)
	assert_eq(_changed_count, 1)
	assert_eq(_last_changed_amount, 5)
	
	_changed_count = 0
	store.take("wood", 0)
	assert_eq(_changed_count, 0)

func test_spend_unknown_kind_changes_nothing() -> void:
	var store: ResourceStore = ResourceStore.new(null)
	var success: bool = store.spend({"gold": 1})
	assert_false(success)
	assert_eq(store.get_amount("food"), 0)
	assert_eq(store.get_amount("wood"), 0)
	assert_eq(store.get_amount("scrap"), 0)
	assert_eq(store.get_amount("ammo"), 0)

func test_refund_skips_unknown_kind() -> void:
	var store: ResourceStore = ResourceStore.new(null)
	store.refund({"wood": 10, "gold": 5}, 1.0)
	assert_eq(store.get_amount("wood"), 10)
	assert_eq(store.get_amount("food"), 0)
	assert_eq(store.get_amount("scrap"), 0)
	assert_eq(store.get_amount("ammo"), 0)
