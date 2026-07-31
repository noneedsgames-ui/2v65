extends Node
## プレイヤーの所持品とゴールドを管理するシングルトン。

signal changed()
signal gold_changed(amount: int)

const MAX_SLOTS := 20

var slots: Array = []  # [{ "id": String, "count": int }, ...]
var gold: int = 100

func _ready() -> void:
	slots.resize(MAX_SLOTS)
	for i in range(MAX_SLOTS):
		slots[i] = null

func add_item(id: String, count: int = 1) -> int:
	var remaining := count
	var stack_max := ItemDB.get_stack_max(id)

	for i in range(MAX_SLOTS):
		if remaining <= 0:
			break
		var slot = slots[i]
		if slot != null and slot["id"] == id and slot["count"] < stack_max:
			var can_add: int = min(stack_max - slot["count"], remaining)
			slot["count"] += can_add
			remaining -= can_add

	for i in range(MAX_SLOTS):
		if remaining <= 0:
			break
		if slots[i] == null:
			var add_count: int = min(stack_max, remaining)
			slots[i] = {"id": id, "count": add_count}
			remaining -= add_count

	if remaining < count:
		changed.emit()
	if remaining > 0:
		EventBus.notify.emit("インベントリがいっぱいです")
	return count - remaining

func get_count(id: String) -> int:
	var total := 0
	for slot in slots:
		if slot != null and slot["id"] == id:
			total += slot["count"]
	return total

func has_item(id: String, count: int = 1) -> bool:
	return get_count(id) >= count

func remove_item(id: String, count: int = 1) -> bool:
	if not has_item(id, count):
		return false
	var remaining := count
	for i in range(MAX_SLOTS):
		if remaining <= 0:
			break
		var slot = slots[i]
		if slot != null and slot["id"] == id:
			var take: int = min(slot["count"], remaining)
			slot["count"] -= take
			remaining -= take
			if slot["count"] <= 0:
				slots[i] = null
	changed.emit()
	return true

func remove_from_slot(index: int, count: int = 1) -> bool:
	if index < 0 or index >= MAX_SLOTS or slots[index] == null:
		return false
	var slot = slots[index]
	var take: int = min(slot["count"], count)
	slot["count"] -= take
	if slot["count"] <= 0:
		slots[index] = null
	changed.emit()
	return true

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true

func is_full_for(id: String) -> bool:
	var stack_max := ItemDB.get_stack_max(id)
	for slot in slots:
		if slot == null:
			return false
		if slot["id"] == id and slot["count"] < stack_max:
			return false
	return true

func to_save_data() -> Dictionary:
	var slot_data := []
	for slot in slots:
		if slot == null:
			slot_data.append(null)
		else:
			slot_data.append({"id": slot["id"], "count": slot["count"]})
	return {"slots": slot_data, "gold": gold}

func load_save_data(data: Dictionary) -> void:
	if data.has("gold"):
		gold = int(data["gold"])
		gold_changed.emit(gold)
	if data.has("slots"):
		var slot_data: Array = data["slots"]
		for i in range(MAX_SLOTS):
			if i < slot_data.size() and slot_data[i] != null:
				slots[i] = {"id": slot_data[i]["id"], "count": int(slot_data[i]["count"])}
			else:
				slots[i] = null
	changed.emit()
