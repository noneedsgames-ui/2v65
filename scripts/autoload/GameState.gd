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

const FIELD_SCENE := "res://scenes/Main.tscn"
const TOWN_SCENE := "res://scenes/Town.tscn"
const WILDS_SCENE := "res://scenes/Wilds.tscn"
const HOUSE_SCENE := "res://scenes/HouseInterior.tscn"

## 次に入る探索地の id(AreaDB)。町の外れで選ぶ。
var selected_area: String = "forest"

## 風呂に入るとさっぱりして採集がはかどる。寝ると翌日になって解ける。
const REFRESHED_GATHER_BONUS := 1
var refreshed: bool = false

const PLAYER_MAX_HP := 100
var player_hp: int = PLAYER_MAX_HP

func damage_player(amount: int) -> void:
	if player_hp <= 0:
		return
	player_hp = max(0, player_hp - amount)
	EventBus.player_hp_changed.emit(player_hp, PLAYER_MAX_HP)
	if player_hp <= 0:
		# 力尽きたら全回復して町の入り口へ運ばれる(持ち物は失わない)
		EventBus.notify.emit("力尽きた…気がつくと町に運ばれていた")
		EventBus.companion_say.emit("もう、無茶しないでよ…。町まで運んだからね。")
		restore_player_hp()
		travel_to(TOWN_SCENE, Vector2(2400, 380))

func restore_player_hp() -> void:
	player_hp = PLAYER_MAX_HP
	EventBus.player_hp_changed.emit(player_hp, PLAYER_MAX_HP)

func set_refreshed(value: bool) -> void:
	refreshed = value

## シーン遷移でプレイヤーを置く座標。change_scene 後の新シーンが _ready で読み取る。
## NAN のときは指定なし(シーン既定のプレイヤー位置を使う)。
var pending_spawn: Vector2 = Vector2(NAN, NAN)

func has_pending_spawn() -> bool:
	return not is_nan(pending_spawn.x)

func clear_pending_spawn() -> void:
	pending_spawn = Vector2(NAN, NAN)

## 指定シーンへ遷移し、遷移先で spawn 位置にプレイヤーを配置する。
func travel_to(scene_path: String, spawn: Vector2) -> void:
	pending_spawn = spawn
	# メニューを開いたまま遷移しても新シーンが止まったままにならないようにする
	get_tree().paused = false
	# 物理コールバック中に呼ばれても安全なように遅延実行する
	get_tree().change_scene_to_file.call_deferred(scene_path)

func chest_add(id: String, count: int) -> void:
	for entry in chest_items:
		if entry["id"] == id:
			entry["count"] += count
			EventBus.notify.emit("収納箱に%sを預けました" % ItemDB.get_display_name(id))
			return
	chest_items.append({"id": id, "count": count})
	EventBus.notify.emit("収納箱に%sを預けました" % ItemDB.get_display_name(id))

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

## 「はじめから」を選んだとき、持ち越しの状態をすべて捨てる。
## オートロードはシーンを跨いで生き続けるので、明示的に消さないと前の周回が混ざる。
func reset_for_new_game() -> void:
	chest_items.clear()
	stall_items.clear()
	stall_earnings_log.clear()
	refreshed = false
	selected_area = "forest"
	player_spawn_position = Vector2(200, 300)
	has_save = false
	restore_player_hp()
	Inventory.reset()
	Equipment.reset()
	Journal.reset()
	Story.reset()
	AlchemyDB.reset()
	ToolDB.reset()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func save_game() -> void:
	var data := {
		"inventory": Inventory.to_save_data(),
		"equipment": Equipment.to_save_data(),
		"refreshed": refreshed,
		"journal": Journal.to_save_data(),
		"story": Story.to_save_data(),
		"alchemy": AlchemyDB.to_save_data(),
		"tools": ToolDB.to_save_data(),
		"hp": player_hp,
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

## JSON は数値をすべて float で復元するため、int を期待するキーを整数に戻す。
## これをしないと Stall や UI 側で int 型変数への代入が実行時エラーになる。
func _restore_entries(raw, int_keys: Array) -> Array:
	var result: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return result
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY or not entry.has("id"):
			continue
		var restored := {"id": str(entry["id"])}
		for key in int_keys:
			restored[key] = int(entry.get(key, 0))
		result.append(restored)
	return result

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
	if data.has("equipment"):
		Equipment.load_save_data(data["equipment"])
	if data.has("journal"):
		Journal.load_save_data(data["journal"])
	if data.has("story"):
		Story.load_save_data(data["story"])
	if data.has("alchemy"):
		AlchemyDB.load_save_data(data["alchemy"])
	if data.has("tools"):
		ToolDB.load_save_data(data["tools"])
	refreshed = bool(data.get("refreshed", false))
	player_hp = clamp(int(data.get("hp", PLAYER_MAX_HP)), 1, PLAYER_MAX_HP)
	EventBus.player_hp_changed.emit(player_hp, PLAYER_MAX_HP)
	if data.has("chest"):
		chest_items = _restore_entries(data["chest"], ["count"])
	if data.has("stall"):
		stall_items = _restore_entries(data["stall"], ["count", "price"])
	if data.has("spawn_x") and data.has("spawn_y"):
		player_spawn_position = Vector2(data["spawn_x"], data["spawn_y"])
	has_save = true
	EventBus.notify.emit("ロードしました")
	return true
