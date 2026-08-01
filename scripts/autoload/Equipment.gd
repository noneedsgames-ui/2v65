extends Node
## 装備スロットの管理。装備中のアイテムはインベントリから取り出され、
## 外すとインベントリに戻る(装備欄とインベントリで二重に持たない)。

signal changed()

# 別オートロードの const は定数式に使えないため、スロット名はここで自己完結させる
# (値は ItemDB.SLOT_TOOL / SLOT_ACCESSORY と一致させること)。
const SLOT_TOOL := "tool"
const SLOT_ACCESSORY := "accessory"

const SLOTS := [SLOT_TOOL, SLOT_ACCESSORY]

const SLOT_LABELS := {
	SLOT_TOOL: "道具",
	SLOT_ACCESSORY: "アクセサリ",
}

# slot 名 -> アイテム id ("" は空)
var slots: Dictionary = {
	SLOT_TOOL: "",
	SLOT_ACCESSORY: "",
}

## 新規開始用。装備をすべて外す(中身は捨てる)。
func reset() -> void:
	for slot in SLOTS:
		slots[slot] = ""
	changed.emit()

func get_equipped(slot: String) -> String:
	return slots.get(slot, "")

func is_equipped(id: String) -> bool:
	for slot in SLOTS:
		if slots[slot] == id:
			return true
	return false

## インベントリから 1 個取り出して装備する。既に同じスロットに装備があれば入れ替える。
func equip(id: String) -> bool:
	var slot := ItemDB.get_equip_slot(id)
	if slot == "":
		EventBus.notify.emit("%sは装備できません" % ItemDB.get_display_name(id))
		return false
	if not Inventory.has_item(id):
		return false
	if not Inventory.remove_item(id, 1):
		return false

	var previous: String = slots[slot]
	slots[slot] = id
	if previous != "":
		Inventory.add_item(previous, 1)

	changed.emit()
	EventBus.notify.emit("%sを装備した" % ItemDB.get_display_name(id))
	return true

## 装備を外してインベントリに戻す。持ち物が満杯なら失敗する。
func unequip(slot: String) -> bool:
	var id: String = slots.get(slot, "")
	if id == "":
		return false
	if Inventory.is_full_for(id):
		EventBus.notify.emit("持ち物がいっぱいで外せません")
		return false
	slots[slot] = ""
	Inventory.add_item(id, 1)
	changed.emit()
	EventBus.notify.emit("%sを外した" % ItemDB.get_display_name(id))
	return true

## 採集時の追加取得量。装備中の全スロットのボーナス合計。
func get_total_gather_bonus() -> int:
	var total := 0
	for slot in SLOTS:
		var id: String = slots[slot]
		if id != "":
			total += ItemDB.get_gather_bonus(id)
	return total

func to_save_data() -> Dictionary:
	return slots.duplicate()

func load_save_data(data: Dictionary) -> void:
	for slot in SLOTS:
		var id = data.get(slot, "")
		slots[slot] = str(id) if typeof(id) == TYPE_STRING else ""
	changed.emit()
