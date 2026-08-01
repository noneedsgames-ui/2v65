extends Node
## 錬成(魔法研究)の仕組み。
##
## 決まったレシピを覚えるのではなく、素材そのものの性質から結果が決まる。
##   1. 釜に素材を最大 SLOT_COUNT 個入れる
##   2. 属性ごとに力を合計する。最も強い属性が「主属性」になる
##   3. 主属性の合計値が階梯(tier)の帯に入っていれば、その霊薬や魔道具ができる
##
## つまり図鑑で素材の属性と力を見比べて、狙った属性を狙った強さまで積むのが遊びになる。
## 触媒(CATALYST)は属性を持たない代わりに、純度(下記)を底上げする。
##
## 純度: 主属性の力が全体に占める割合。混ぜ物が多いと下がる。
##   高いほど成果物の個数が増え、低すぎると失敗して「澱」になる。

signal formula_discovered(formula_id: String)

const SLOT_COUNT := 4
const FAILURE_ID := "sludge"

## 純度がこれ未満だと失敗する
const PURITY_FAIL := 0.5
## 純度がこれ以上なら1個多くできる
const PURITY_BONUS := 0.85

## 階梯。主属性の合計がこの範囲なら、その段の成果物になる。
const TIERS := [
	{"min": 3, "max": 6, "suffix": 0},
	{"min": 7, "max": 10, "suffix": 1},
	{"min": 11, "max": 99, "suffix": 2},
]

## 属性 -> 段ごとの霊薬
const ELIXIRS := {
	"fire": ["draught_ember", "draught_blaze", "draught_inferno"],
	"water": ["draught_dew", "draught_tide", "draught_abyss"],
	"wind": ["draught_breeze", "draught_gale", "draught_storm"],
	"earth": ["draught_clay", "draught_stone", "draught_titan"],
	"light": ["draught_dawn", "draught_radiance", "draught_seraph"],
	"dark": ["draught_shade", "draught_gloom", "draught_eclipse"],
}

## 属性 -> 魔道具(杖と護符)。純度が非常に高いときだけ生まれる。
const ARTIFACTS := {
	"fire": ["wand_ember", "charm_salamander"],
	"water": ["wand_tide", "charm_undine"],
	"wind": ["wand_gale", "charm_sylph"],
	"earth": ["wand_stone", "charm_golem"],
	"light": ["wand_dawn", "charm_seraph"],
	"dark": ["wand_shade", "charm_nether"],
}

## 魔道具ができる条件: 最上段 + 純度がこれ以上 + 触媒が入っていること。
## 触媒を要求しないと、純度の高い最上段がすべて魔道具になってしまい、
## 最上段の霊薬が永久に作れなくなる。
const ARTIFACT_PURITY := 0.95

## 一度でも作ったことのある成果物 id
var discovered: Dictionary = {}

# ---- 予測 ----

## 素材 id の配列から結果を予測する。UI はこれを使って釜の中身を実況する。
## 返り値: {
##   "valid": bool, "element": String, "total": int, "purity": float,
##   "output_id": String, "amount": int, "tier": int, "note": String }
func preview(ingredient_ids: Array) -> Dictionary:
	var sums := {}
	for e in ItemDB.ELEMENTS:
		sums[e] = 0
	var catalyst_power := 0
	var any := false

	for id in ingredient_ids:
		if id == "":
			continue
		any = true
		var elem := ItemDB.get_element(id)
		var pot := ItemDB.get_potency(id)
		if elem == "none":
			catalyst_power += pot
		else:
			sums[elem] = int(sums[elem]) + pot

	var result := {
		"valid": false, "element": "none", "total": 0, "purity": 0.0,
		"output_id": "", "amount": 0, "tier": -1, "note": "",
	}
	if not any:
		result["note"] = "釜が空っぽだ"
		return result

	# 主属性を決める
	var best_elem := ""
	var best := 0
	var elemental_total := 0
	for e in ELIXIRS.keys():
		var v := int(sums[e])
		elemental_total += v
		if v > best:
			best = v
			best_elem = e

	if best_elem == "" or best <= 0:
		result["note"] = "属性を持つ素材が要る"
		return result

	result["element"] = best_elem
	result["total"] = best

	# 純度: 主属性が全体に占める割合。触媒は分母に入らず、下駄をはかせる。
	var purity := float(best) / float(max(1, elemental_total))
	purity = min(1.0, purity + 0.06 * float(catalyst_power))
	result["purity"] = purity

	var tier := _tier_for(best)
	result["tier"] = tier
	if tier < 0:
		result["note"] = "力が足りない(主属性の合計が3以上必要)"
		result["output_id"] = FAILURE_ID
		result["amount"] = 1
		return result

	if purity < PURITY_FAIL:
		result["note"] = "混ざりすぎて澱む(純度%d%%)" % int(purity * 100.0)
		result["output_id"] = FAILURE_ID
		result["amount"] = 1
		return result

	# 最上段・高純度・触媒ありのときだけ器物になる(触媒が無ければ最上段の霊薬)
	if tier == TIERS.size() - 1 and purity >= ARTIFACT_PURITY and catalyst_power > 0:
		var pair: Array = ARTIFACTS[best_elem]
		# 力が飛び抜けていれば護符、そうでなければ杖
		var idx := 1 if best >= 14 else 0
		result["valid"] = true
		result["output_id"] = pair[idx]
		result["amount"] = 1
		result["note"] = "純度が極まっている。器物が生まれそうだ"
		return result

	result["valid"] = true
	result["output_id"] = ELIXIRS[best_elem][tier]
	result["amount"] = 2 if purity >= PURITY_BONUS else 1
	result["note"] = "純度%d%%" % int(purity * 100.0)
	return result

func _tier_for(total: int) -> int:
	for i in range(TIERS.size()):
		var t: Dictionary = TIERS[i]
		if total >= int(t["min"]) and total <= int(t["max"]):
			return i
	return -1

# ---- 実行 ----

## 釜の中身を消費して成果物を作る。成功なら成果物 id を返し、何もできなければ "" を返す。
func brew(ingredient_ids: Array) -> String:
	var result := preview(ingredient_ids)
	var output: String = result["output_id"]
	if output == "":
		return ""

	# 素材を消費する。同じ素材を複数スロットに入れた場合も1つずつ減らす。
	for id in ingredient_ids:
		if id != "":
			Inventory.remove_item(id, 1)

	if output == FAILURE_ID:
		EventBus.notify.emit("錬成失敗… %s" % result["note"])
		EventBus.companion_say.emit("うーん、澱んじゃったね。配合を変えてみよう。")
		return FAILURE_ID

	Inventory.add_item(output, int(result["amount"]))
	if not discovered.has(output):
		discovered[output] = true
		formula_discovered.emit(output)
		EventBus.companion_say.emit("新しい調合だ！ 図鑑に書きとめておくね。")
	EventBus.notify.emit("錬成成功: %s x%d (%s)" % \
		[ItemDB.get_display_name(output), int(result["amount"]), result["note"]])
	return output

## 新規開始用。調合の記録を消す。
func reset() -> void:
	discovered.clear()

func is_discovered(id: String) -> bool:
	return discovered.has(id)

func discovered_count() -> int:
	return discovered.size()

## 図鑑に載る成果物の総数(霊薬 + 魔道具)
func total_outputs() -> int:
	var n := 0
	for e in ELIXIRS.keys():
		n += ELIXIRS[e].size()
		n += ARTIFACTS[e].size()
	return n

func to_save_data() -> Dictionary:
	return {"discovered": discovered.keys()}

func load_save_data(data: Dictionary) -> void:
	discovered.clear()
	for id in data.get("discovered", []):
		discovered[str(id)] = true
