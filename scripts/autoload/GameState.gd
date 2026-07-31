extends Node
## セーブ/ロード可能なワールド状態(家の収納・露店の在庫など)を保持するシングルトン。

const SAVE_PATH := "user://savegame.json"

# 家の収納チェスト: [{ "id": String, "count": int }, ...] (null 埋めなし、可変長)
var chest_items: Array = []

# 露店に並べたアイテム: [{ "id": String, "count": int, "price": int }, ...]
var stall_items: Array = []
var stall_earnings_log: Array = []

var player_spawn_position: Vector2 = Vector2(200, 300)
var has_save: bool = false

func chest_add(id: String, count: int) -> void:
	for entry in chest_items:
		if entry["id"] == id:
			entry["count"] += count
			EventBus.notify.emit("収納箱に%sを預けました" % ItemDB.get_name(id))
			return
	chest_items.append({"id": id, "count": count})
	EventBus.notify.emit("収納箱に%sを預けました" % ItemDB.get_name(id))

func chest_remove(id: String, count: int) -> bool:
	for entry in chest_items:
		if entry["id"] == id and entry["count"] >= count:
			entry["count"] -= count
			if entry["count"] <= 0:
				chest_items.erase(entry)
			return true
	return false

func stall_add_item(id: String, count: int, price: int) -> void:
	for entry in stall_items:
		if entry["id"] == id and entry["price"] == price:
			entry["count"] += count
			return
	stall_items.append({"id": id, "count": count, "price": price})

func stall_withdraw(index: int) -> void:
	if index >= 0 and index < stall_items.size():
		var entry = stall_items[index]
		Inventory.add_item(entry["id"], entry["count"])
		stall_items.remove_at(index)

func save_game() -> void:
	var data := {
		"inventory": Inventory.to_save_data(),
		"chest": chest_items,
		"stall": stall_items,
		"spawn_x": player_spawn_position.x,
		"spawn_y": player_spawn_position.y,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		has_save = true
		EventBus.notify.emit("セーブしました")

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	if data.has("inventory"):
		Inventory.load_save_data(data["inventory"])
	if data.has("chest"):
		chest_items = data["chest"]
	if data.has("stall"):
		stall_items = data["stall"]
	if data.has("spawn_x") and data.has("spawn_y"):
		player_spawn_position = Vector2(data["spawn_x"], data["spawn_y"])
	has_save = true
	EventBus.notify.emit("ロードしました")
	return true
