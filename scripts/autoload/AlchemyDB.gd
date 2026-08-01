extends Node
## 調合。素材を「順番に」釜へ入れて霊薬を作る。
##
## レシピは特定の素材ではなく、**性質の並び**で決まっている。
## たとえば〈熱・熱・輝〉なら、熱を持つ素材2つのあとに輝を持つ素材を入れればよい。
## どの素材を使うかはプレイヤーの自由で、手持ち次第で組み替えられる。
##
## ただし隣り合う素材どうしは性質をひとつ以上共有していなければならない(ManaDB.resonates)。
## 〈熱〉のあとに〈輝〉を置きたければ、どちらかが〈熱・輝〉の二重素材である必要がある。
## この「あいだをつなぐ素材」が緩衝材で、調合のいちばんの考えどころになる。
##
## さらに魔力の総量が帯に収まっていないと形にならない。
## 同じ並びでも、強い素材で組めば上位の霊薬になる。

signal formula_discovered(formula_id: String)

const SLOT_COUNT := 5
const FAILURE_ID := "sludge"

## 表の並び: id, 名前, 性質の並び, 魔力の下限, 魔力の上限, 成果物, 個数, 手がかり
const RECIPE_TABLE := [
	# --- 熱の系統 ---
	["draught_ember", "燠の霊薬", ["heat", "heat"], 2, 5, "draught_ember", 2,
		"熱をふたつ重ねるだけの、いちばんやさしい調合"],
	["draught_blaze", "烈火の霊薬", ["heat", "heat", "bright"], 6, 11, "draught_blaze", 1,
		"熱を重ねたあと輝で締める。あいだをつなぐ素材が要る"],
	["draught_inferno", "業火の霊薬", ["heat", "bright", "heat", "solid"], 14, 24, "draught_inferno", 1,
		"熱と輝を行き来し、最後に堅で固める"],
	# --- 潤の系統 ---
	["draught_dew", "露の霊薬", ["moist", "moist"], 2, 5, "draught_dew", 2,
		"潤をふたつ重ねるだけの、やさしい調合"],
	["draught_tide", "潮の霊薬", ["moist", "moist", "solid"], 6, 11, "draught_tide", 1,
		"潤を重ねたあと堅で受ける"],
	["draught_abyss", "深淵の霊薬", ["moist", "solid", "moist", "erode"], 14, 24, "draught_abyss", 1,
		"潤と堅を行き来し、最後に蝕へ沈める"],
	# --- 疾の系統 ---
	["draught_breeze", "微風の霊薬", ["swift", "swift"], 2, 5, "draught_breeze", 2,
		"疾をふたつ重ねるだけの、軽い調合"],
	["draught_gale", "疾風の霊薬", ["swift", "swift", "moist"], 6, 11, "draught_gale", 1,
		"疾を重ねたあと潤で湿らせる"],
	["draught_storm", "嵐の霊薬", ["swift", "moist", "swift", "heat"], 14, 24, "draught_storm", 1,
		"疾と潤を行き来し、最後に熱で荒れさせる"],
	# --- 堅の系統 ---
	["draught_clay", "土の霊薬", ["solid", "solid"], 2, 5, "draught_clay", 2,
		"堅をふたつ重ねるだけの、素朴な調合"],
	["draught_stone", "岩の霊薬", ["solid", "solid", "erode"], 6, 11, "draught_stone", 1,
		"堅を重ねたあと蝕で削る"],
	["draught_titan", "巨人の霊薬", ["solid", "erode", "solid", "bright"], 14, 24, "draught_titan", 1,
		"堅と蝕を行き来し、最後に輝を通す"],
	# --- 輝の系統 ---
	["draught_dawn", "暁の霊薬", ["bright", "bright"], 2, 5, "draught_dawn", 2,
		"輝をふたつ重ねるだけの、明るい調合"],
	["draught_radiance", "光輝の霊薬", ["bright", "bright", "swift"], 6, 11, "draught_radiance", 1,
		"輝を重ねたあと疾で走らせる"],
	["draught_seraph", "聖光の霊薬", ["bright", "swift", "bright", "moist"], 14, 24, "draught_seraph", 1,
		"輝と疾を行き来し、最後に潤で満たす"],
	# --- 蝕の系統 ---
	["draught_shade", "陰の霊薬", ["erode", "erode"], 2, 5, "draught_shade", 2,
		"蝕をふたつ重ねるだけの、暗い調合"],
	["draught_gloom", "幽闇の霊薬", ["erode", "erode", "moist"], 6, 11, "draught_gloom", 1,
		"蝕を重ねたあと潤で溶かす"],
	["draught_eclipse", "蝕の霊薬", ["erode", "moist", "erode", "solid"], 14, 24, "draught_eclipse", 1,
		"蝕と潤を行き来し、最後に堅で閉じ込める"],
]

## 一度でも作ったことのあるレシピ id
var discovered: Dictionary = {}

var recipes: Array = []

func _ready() -> void:
	for row in RECIPE_TABLE:
		recipes.append({
			"id": row[0],
			"name": row[1],
			"sequence": row[2],
			"mana_min": int(row[3]),
			"mana_max": int(row[4]),
			"output_id": row[5],
			"output_count": int(row[6]),
			"hint": row[7],
		})

func get_recipe(id: String) -> Dictionary:
	for r in recipes:
		if r["id"] == id:
			return r
	return {}

## 釜の中身から空きを取り除いて、入れた順に並べ直す。
func compact(ingredient_ids: Array) -> Array:
	var out: Array = []
	for id in ingredient_ids:
		if id != "":
			out.append(id)
	return out

func total_mana(ingredient_ids: Array) -> int:
	var total := 0
	for id in compact(ingredient_ids):
		total += ManaDB.get_mana(id)
	return total

## 隣り合う素材が弾き合っていないか調べる。
## 返り値は弾き合っている位置(0起点、後ろ側の添字)。問題なければ -1。
func find_clash(ingredient_ids: Array) -> int:
	var seq := compact(ingredient_ids)
	for i in range(1, seq.size()):
		if not ManaDB.resonates(seq[i - 1], seq[i]):
			return i
	return -1

## 並びがレシピの性質の並びに沿っているか。
func _follows_sequence(seq: Array, natures: Array) -> bool:
	if seq.size() != natures.size():
		return false
	for i in range(seq.size()):
		if not ManaDB.has_nature(seq[i], natures[i]):
			return false
	return true

## 釜の中身に当てはまるレシピを返す。無ければ空。
func find_match(ingredient_ids: Array) -> Dictionary:
	var seq := compact(ingredient_ids)
	if seq.is_empty() or find_clash(ingredient_ids) >= 0:
		return {}
	var mana := total_mana(ingredient_ids)
	for r in recipes:
		if not _follows_sequence(seq, r["sequence"]):
			continue
		if mana < int(r["mana_min"]) or mana > int(r["mana_max"]):
			continue
		return r
	return {}

## 釜の実況。UI はこれを読んで、いま何が起きているかを見せる。
## { "ready": bool, "recipe": Dictionary, "note": String, "clash": int, "mana": int }
func preview(ingredient_ids: Array) -> Dictionary:
	var seq := compact(ingredient_ids)
	var mana := total_mana(ingredient_ids)
	var clash := find_clash(ingredient_ids)

	if seq.is_empty():
		return {"ready": false, "recipe": {}, "note": "釜が空っぽだ", "clash": -1, "mana": 0}

	if clash >= 0:
		return {"ready": false, "recipe": {}, "clash": clash, "mana": mana,
			"note": "%d番目と%d番目が弾き合っている。あいだをつなぐ素材が要る" % [clash, clash + 1]}

	var r := find_match(ingredient_ids)
	if r.is_empty():
		# 並びは通っているが結果に届いていない。魔力量のずれなら、そう伝える。
		for cand in recipes:
			if _follows_sequence(seq, cand["sequence"]):
				if mana < int(cand["mana_min"]):
					return {"ready": true, "recipe": {}, "clash": -1, "mana": mana,
						"note": "並びは通っている。ただ魔力が足りない(いま%d)" % mana}
				return {"ready": true, "recipe": {}, "clash": -1, "mana": mana,
					"note": "並びは通っているが魔力が強すぎる(いま%d)" % mana}
		return {"ready": true, "recipe": {}, "clash": -1, "mana": mana,
			"note": "この並びに心当たりはない(魔力%d)" % mana}

	if is_discovered(r["id"]):
		return {"ready": true, "recipe": r, "clash": -1, "mana": mana,
			"note": "%s になりそうだ(魔力%d)" % [r["name"], mana]}
	return {"ready": true, "recipe": r, "clash": -1, "mana": mana,
		"note": "何かができそうな手応えがある…(魔力%d)" % mana}

## 釜の中身を消費して作る。performance はリズムの出来(0.0〜1.0)。
func brew(ingredient_ids: Array, performance: float) -> String:
	var r := find_match(ingredient_ids)

	for id in compact(ingredient_ids):
		Inventory.remove_item(id, 1)

	if r.is_empty():
		EventBus.notify.emit("調合失敗… 魔力がまとまらなかった")
		EventBus.companion_say.emit("うーん、澱んじゃったね。並びを見直してみよう。")
		Inventory.add_item(FAILURE_ID, 1)
		return FAILURE_ID

	if performance < 0.4:
		EventBus.notify.emit("調合失敗… 拍が乱れて魔力が散った")
		EventBus.companion_say.emit("拍がずれちゃった。次はもっと落ち着いて。")
		Inventory.add_item(FAILURE_ID, 1)
		return FAILURE_ID

	var amount := int(r["output_count"])
	if performance >= 0.95:
		amount += 1

	Inventory.add_item(r["output_id"], amount)
	if not discovered.has(r["id"]):
		discovered[r["id"]] = true
		formula_discovered.emit(r["id"])
		EventBus.companion_say.emit("新しい調合だ！ 図鑑に書きとめておくね。")
	EventBus.notify.emit("調合成功: %s x%d" % [ItemDB.get_display_name(r["output_id"]), amount])
	return r["output_id"]

## 新規開始用。調合の記録を消す。
func reset() -> void:
	discovered.clear()

func is_discovered(id: String) -> bool:
	return discovered.has(id)

func discovered_count() -> int:
	return discovered.size()

func total_outputs() -> int:
	return recipes.size()

func to_save_data() -> Dictionary:
	return {"discovered": discovered.keys()}

func load_save_data(data: Dictionary) -> void:
	discovered.clear()
	for id in data.get("discovered", []):
		discovered[str(id)] = true
