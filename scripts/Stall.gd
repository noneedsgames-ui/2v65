extends Area2D
## 町の広場に構えるプレイヤーの露店。
## 売れるのは町人(TownNPC)が実際に歩いて来たときだけで、
## 一定確率で代金を払わずに持ち去られる(万引き)。

const STALL_KIT_ID := "stall_kit"

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("player_stall")

func get_prompt() -> String:
	if not Inventory.has_item(STALL_KIT_ID):
		return "露店 (%sが必要)" % ItemDB.get_display_name(STALL_KIT_ID)
	return "露店を管理する [E]"

func interact(_actor: Node) -> void:
	if not Inventory.has_item(STALL_KIT_ID):
		EventBus.notify.emit("%sがあれば露店を開けます" % ItemDB.get_display_name(STALL_KIT_ID))
		return
	EventBus.request_open_stall.emit()

func has_stock() -> bool:
	for entry in GameState.stall_items:
		if int(entry["count"]) > 0:
			return true
	return false

func _random_stocked_index() -> int:
	var candidates: Array = []
	for i in range(GameState.stall_items.size()):
		if int(GameState.stall_items[i]["count"]) > 0:
			candidates.append(i)
	if candidates.is_empty():
		return -1
	return candidates[randi() % candidates.size()]

## 町人ひとりぶんの取引を処理する。steal_chance の確率で万引きになる。
func serve_customer(steal_chance: float) -> void:
	var idx := _random_stocked_index()
	if idx < 0:
		return

	var entry: Dictionary = GameState.stall_items[idx]
	var quantity: int = min(int(entry["count"]), randi_range(1, 2))
	entry["count"] = int(entry["count"]) - quantity

	var item_name := ItemDB.get_display_name(entry["id"])
	var message := ""
	if randf() < steal_chance:
		message = "万引き! %sを%d個盗まれた" % [item_name, quantity]
		EventBus.companion_say.emit("あっ、今の人お金払ってないよ！ 追いかける？")
	else:
		var earned: int = int(entry["price"]) * quantity
		Inventory.add_gold(earned)
		message = "%sが%d個売れた (+%dG)" % [item_name, quantity, earned]

	GameState.stall_earnings_log.append(message)
	if GameState.stall_earnings_log.size() > 20:
		GameState.stall_earnings_log.remove_at(0)
	EventBus.notify.emit(message)

	if int(entry["count"]) <= 0:
		GameState.stall_items.remove_at(idx)
