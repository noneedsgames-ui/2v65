extends Node
## 道具の設計。家の作業台でのみ組める。
##
## 道具はいくつかの部品からできていて、部品ごとに**別の魔力**をまとわせる。
##   1. 部品を選ぶ
##   2. その部品が求める性質を持つ素材を、求める魔力の帯に収まるように入れる
##   3. 全部品ができたら、最後に魔力の回路をつなぐ(ミニゲーム)
##   4. 回路が通れば道具の完成
##
## 部品ごとに違う性質を求めるので、ひとつの道具を作るのに何系統かの素材が要る。
## 調合(AlchemyDB)とは別物で、こちらは並び順ではなく「部品ごとの帯」を満たす作業。

signal part_built(tool_id: String, part_index: int)
signal tool_completed(tool_id: String)

## 部品に入れられる素材の数
const PART_SLOTS := 2

## 表の並び: 道具id, 名前, 説明, 部品の配列
## 部品: { 名前, 求める性質, 魔力の下限, 魔力の上限, 役割の説明 }
const TOOL_TABLE := [
	{
		"id": "axe", "name": "斧", "blurb": "木を伐るための斧。装備すると木からの採集量が増える。",
		"parts": [
			{"name": "柄", "nature": "solid", "min": 2, "max": 6, "note": "手に馴染む堅さがいる"},
			{"name": "刃", "nature": "heat", "min": 3, "max": 8, "note": "打ち出すには熱が要る"},
		],
	},
	{
		"id": "pickaxe", "name": "ツルハシ", "blurb": "岩や鉱脈を砕くツルハシ。鉄鉱脈の採掘には装備が必須。",
		"parts": [
			{"name": "柄", "nature": "solid", "min": 2, "max": 6, "note": "衝撃に耐える堅さ"},
			{"name": "頭", "nature": "solid", "min": 4, "max": 10, "note": "岩に負けない密度"},
			{"name": "楔", "nature": "erode", "min": 2, "max": 7, "note": "岩を噛む蝕の力"},
		],
	},
	{
		"id": "basket", "name": "採集かご", "blurb": "背負って使う採集かご。装備するとどの採集でも取れ高が増える。",
		"parts": [
			{"name": "編み地", "nature": "swift", "min": 2, "max": 6, "note": "軽くしなやかに"},
			{"name": "背当て", "nature": "moist", "min": 2, "max": 7, "note": "肌に触れる部分はやわらかく"},
		],
	},
	{
		"id": "herb_bag", "name": "薬草袋", "blurb": "薬草を潰さず運べる袋。採集量がさらに増える。",
		"parts": [
			{"name": "生地", "nature": "swift", "min": 3, "max": 8, "note": "薄く、破れない"},
			{"name": "内張り", "nature": "moist", "min": 3, "max": 9, "note": "薬草の水気を保つ"},
			{"name": "留め具", "nature": "solid", "min": 2, "max": 6, "note": "しっかり閉じる"},
		],
	},
	{
		"id": "miners_lamp", "name": "坑夫のランプ", "blurb": "暗がりを照らすランプ。鉱石の目利きが利く。",
		"parts": [
			{"name": "外殻", "nature": "solid", "min": 3, "max": 8, "note": "落としても割れない"},
			{"name": "灯芯", "nature": "bright", "min": 4, "max": 10, "note": "絶えず光を放つ"},
			{"name": "油壺", "nature": "heat", "min": 3, "max": 9, "note": "火を絶やさぬために"},
		],
	},
	{
		"id": "stall_kit", "name": "露店キット", "blurb": "露店を開くための道具一式。持っていると町の広場で商売ができる。",
		"parts": [
			{"name": "骨組み", "nature": "solid", "min": 4, "max": 10, "note": "風でも倒れぬように"},
			{"name": "天幕", "nature": "swift", "min": 3, "max": 8, "note": "軽く畳めること"},
			{"name": "看板", "nature": "bright", "min": 3, "max": 9, "note": "遠くからでも目を引く"},
		],
	},
]

## 作りかけの状態。tool_id -> { "parts": [bool, ...] }
var progress: Dictionary = {}
## 一度でも完成させた道具
var built: Dictionary = {}

var tools: Array = []

func _ready() -> void:
	for row in TOOL_TABLE:
		tools.append(row)

func get_tool(id: String) -> Dictionary:
	for t in tools:
		if t["id"] == id:
			return t
	return {}

func part_count(tool_id: String) -> int:
	var t := get_tool(tool_id)
	return t.get("parts", []).size()

func get_part(tool_id: String, index: int) -> Dictionary:
	var t := get_tool(tool_id)
	var parts: Array = t.get("parts", [])
	if index < 0 or index >= parts.size():
		return {}
	return parts[index]

## その道具の部品ができているかの配列。まだ手をつけていなければ全部 false。
func part_states(tool_id: String) -> Array:
	if not progress.has(tool_id):
		var states: Array = []
		for _i in range(part_count(tool_id)):
			states.append(false)
		return states
	return progress[tool_id]["parts"]

func is_part_done(tool_id: String, index: int) -> bool:
	var states := part_states(tool_id)
	return index >= 0 and index < states.size() and bool(states[index])

func all_parts_done(tool_id: String) -> bool:
	var states := part_states(tool_id)
	if states.is_empty():
		return false
	for s in states:
		if not bool(s):
			return false
	return true

func done_count(tool_id: String) -> int:
	var n := 0
	for s in part_states(tool_id):
		if bool(s):
			n += 1
	return n

# ---- 部品づくり ----

## 入れた素材が部品の求めるものを満たしているか調べる。
## { "ok": bool, "mana": int, "note": String }
func check_part(tool_id: String, index: int, ingredient_ids: Array) -> Dictionary:
	var part := get_part(tool_id, index)
	if part.is_empty():
		return {"ok": false, "mana": 0, "note": ""}

	var used: Array = []
	for id in ingredient_ids:
		if id != "":
			used.append(id)
	if used.is_empty():
		return {"ok": false, "mana": 0, "note": "素材を入れよう"}

	var nature: String = part["nature"]
	var mana := 0
	for id in used:
		if not ManaDB.has_nature(id, nature):
			return {"ok": false, "mana": 0,
				"note": "%sは〈%s〉を持っていない" % [
					ItemDB.get_display_name(id), ManaDB.nature_label(nature)]}
		mana += ManaDB.get_mana(id)

	if mana < int(part["min"]):
		return {"ok": false, "mana": mana, "note": "魔力が足りない(いま%d / %d以上)" % [mana, int(part["min"])]}
	if mana > int(part["max"]):
		return {"ok": false, "mana": mana, "note": "魔力が強すぎる(いま%d / %d以下)" % [mana, int(part["max"])]}
	return {"ok": true, "mana": mana, "note": "%sが仕上がりそうだ(魔力%d)" % [part["name"], mana]}

## 素材を消費して部品を仕上げる。
func build_part(tool_id: String, index: int, ingredient_ids: Array) -> bool:
	var check := check_part(tool_id, index, ingredient_ids)
	if not bool(check["ok"]):
		return false

	for id in ingredient_ids:
		if id != "":
			Inventory.remove_item(id, 1)

	if not progress.has(tool_id):
		var states: Array = []
		for _i in range(part_count(tool_id)):
			states.append(false)
		progress[tool_id] = {"parts": states}
	progress[tool_id]["parts"][index] = true

	var part := get_part(tool_id, index)
	part_built.emit(tool_id, index)
	EventBus.notify.emit("%sの%sができた (%d/%d)" % [
		get_tool(tool_id)["name"], part["name"], done_count(tool_id), part_count(tool_id)])
	return true

## 回路がつながったら道具を完成させる。
func complete_tool(tool_id: String) -> bool:
	if not all_parts_done(tool_id):
		return false
	progress.erase(tool_id)
	built[tool_id] = true
	Inventory.add_item(tool_id, 1)
	tool_completed.emit(tool_id)
	EventBus.notify.emit("%sが完成した！" % get_tool(tool_id)["name"])
	EventBus.companion_say.emit("回路がつながったね。いい出来だ。")
	return true

func has_built(tool_id: String) -> bool:
	return built.has(tool_id)

## 新規開始用。作りかけと完成の記録を消す。
func reset() -> void:
	progress.clear()
	built.clear()

func to_save_data() -> Dictionary:
	return {"progress": progress.duplicate(true), "built": built.keys()}

func load_save_data(data: Dictionary) -> void:
	progress.clear()
	built.clear()
	var saved: Dictionary = data.get("progress", {})
	for tool_id in saved.keys():
		var raw = saved[tool_id]
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var states: Array = []
		# JSON から戻すと真偽値が数値になっていることがあるので bool に直す
		for s in raw.get("parts", []):
			states.append(bool(s))
		if states.size() == part_count(str(tool_id)):
			progress[str(tool_id)] = {"parts": states}
	for id in data.get("built", []):
		built[str(id)] = true
