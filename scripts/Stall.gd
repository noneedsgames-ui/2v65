extends Area2D
## プレイヤーの露店(出店)。並べたアイテムを一定間隔で客が自動購入する。

@export var customer_interval_min: float = 8.0
@export var customer_interval_max: float = 18.0

@onready var timer: Timer = $CustomerTimer

func _ready() -> void:
	add_to_group("interactable")
	timer.timeout.connect(_on_customer_timeout)
	_schedule_next_customer()

func get_prompt() -> String:
	return "露店を管理する [E]"

func interact(_actor: Node) -> void:
	EventBus.request_open_stall.emit()

func _schedule_next_customer() -> void:
	timer.wait_time = randf_range(customer_interval_min, customer_interval_max)
	timer.start()

func _on_customer_timeout() -> void:
	_try_sell_to_customer()
	_schedule_next_customer()

func _try_sell_to_customer() -> void:
	if GameState.stall_items.is_empty():
		return
	var idx := randi() % GameState.stall_items.size()
	var entry = GameState.stall_items[idx]
	var buy_count: int = min(entry["count"], randi_range(1, 3))
	if buy_count <= 0:
		return
	entry["count"] -= buy_count
	var earned: int = entry["price"] * buy_count
	Inventory.add_gold(earned)
	var log_entry := "客が%sを%d個購入(+%dG)" % [ItemDB.get_name(entry["id"]), buy_count, earned]
	GameState.stall_earnings_log.append(log_entry)
	if GameState.stall_earnings_log.size() > 20:
		GameState.stall_earnings_log.remove_at(0)
	EventBus.notify.emit(log_entry)
	if entry["count"] <= 0:
		GameState.stall_items.remove_at(idx)
