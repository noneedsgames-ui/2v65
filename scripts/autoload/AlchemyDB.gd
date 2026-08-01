extends Node
## 錬成(魔法研究)の仕組み。
##
## 決まった組み合わせで作る。釜に素材を入れて焚くと、その中身とぴったり一致する
## レシピがあれば成果物になる。一致しなければ澱(sludge)にしかならない。
##
## レシピは最初は伏せられていて、図鑑には「？？？」と手がかりだけが載る。
## 実際に作れたものから順に書き足されていく。
##
## 上の段の霊薬は下の段の霊薬を材料にするので、
##   薬草だけの一段目 → 鉱石を足した二段目 → 三段目 → 杖・護符
## と積み上げていくことになる。
##
## 焚くときは魔力の脈にあわせて拍を打つリズムゲームになり、
## その精度で出来高が変わる(外しすぎると澱む)。

signal formula_discovered(formula_id: String)

const SLOT_COUNT := 4
const FAILURE_ID := "sludge"

## 表の並び: id, 名前, 材料, 成果物, 個数, 手がかり
const RECIPE_TABLE := [
	["draught_ember", "燠の霊薬", {"emberleaf": 2, "scorchroot": 1}, "draught_ember", 2, "薬草だけで作れる、いちばん易しい調合"],
	["draught_blaze", "烈火の霊薬", {"draught_ember": 1, "flamecap": 1, "ruby_shard": 1}, "draught_blaze", 1, "燠の霊薬に薬草と鉱石を重ねる"],
	["draught_inferno", "業火の霊薬", {"draught_blaze": 1, "cinderbloom": 1, "magma_stone": 1}, "draught_inferno", 1, "烈火の霊薬をさらに煮詰める"],
	["wand_ember", "燠の杖", {"draught_inferno": 1, "phoenix_moss": 1, "sunsteel_ore": 1, "catalyst_quick": 1}, "wand_ember", 1, "業火の霊薬に希少な鉱を溶かし、水銀で形を留める"],
	["charm_salamander", "火竜の護符", {"draught_inferno": 1, "ifrit_core": 1, "catalyst_prima": 1}, "charm_salamander", 1, "業火の霊薬と核を第一質料で結びつける"],
	["draught_dew", "露の霊薬", {"dewgrass": 2, "tidefern": 1}, "draught_dew", 2, "薬草だけで作れる、いちばん易しい調合"],
	["draught_tide", "潮の霊薬", {"draught_dew": 1, "mirror_lily": 1, "aqua_shard": 1}, "draught_tide", 1, "露の霊薬に薬草と鉱石を重ねる"],
	["draught_abyss", "深淵の霊薬", {"draught_tide": 1, "deepkelp": 1, "frost_stone": 1}, "draught_abyss", 1, "潮の霊薬をさらに煮詰める"],
	["wand_tide", "潮の杖", {"draught_abyss": 1, "tearvine": 1, "abyss_ore": 1, "catalyst_quick": 1}, "wand_tide", 1, "深淵の霊薬に希少な鉱を溶かし、水銀で形を留める"],
	["charm_undine", "水霊の護符", {"draught_abyss": 1, "leviath_core": 1, "catalyst_prima": 1}, "charm_undine", 1, "深淵の霊薬と核を第一質料で結びつける"],
	["draught_breeze", "微風の霊薬", {"whistlereed": 2, "driftcotton": 1}, "draught_breeze", 2, "薬草だけで作れる、いちばん易しい調合"],
	["draught_gale", "疾風の霊薬", {"draught_breeze": 1, "galeleaf": 1, "gale_shard": 1}, "draught_gale", 1, "微風の霊薬に薬草と鉱石を重ねる"],
	["draught_storm", "嵐の霊薬", {"draught_gale": 1, "skyroot": 1, "cloud_stone": 1}, "draught_storm", 1, "疾風の霊薬をさらに煮詰める"],
	["wand_gale", "疾風の杖", {"draught_storm": 1, "stormpetal": 1, "tempest_ore": 1, "catalyst_quick": 1}, "wand_gale", 1, "嵐の霊薬に希少な鉱を溶かし、水銀で形を留める"],
	["charm_sylph", "風霊の護符", {"draught_storm": 1, "sylph_core": 1, "catalyst_prima": 1}, "charm_sylph", 1, "嵐の霊薬と核を第一質料で結びつける"],
	["draught_clay", "土の霊薬", {"clayleaf": 2, "ironbark": 1}, "draught_clay", 2, "薬草だけで作れる、いちばん易しい調合"],
	["draught_stone", "岩の霊薬", {"draught_clay": 1, "stonefungus": 1, "granite_shard": 1}, "draught_stone", 1, "土の霊薬に薬草と鉱石を重ねる"],
	["draught_titan", "巨人の霊薬", {"draught_stone": 1, "deeproot": 1, "crystal_stone": 1}, "draught_titan", 1, "岩の霊薬をさらに煮詰める"],
	["wand_stone", "岩の杖", {"draught_titan": 1, "titan_seed": 1, "adaman_ore": 1, "catalyst_quick": 1}, "wand_stone", 1, "巨人の霊薬に希少な鉱を溶かし、水銀で形を留める"],
	["charm_golem", "土霊の護符", {"draught_titan": 1, "golem_core": 1, "catalyst_prima": 1}, "charm_golem", 1, "巨人の霊薬と核を第一質料で結びつける"],
	["draught_dawn", "暁の霊薬", {"sunpetal": 2, "glowmoss": 1}, "draught_dawn", 2, "薬草だけで作れる、いちばん易しい調合"],
	["draught_radiance", "光輝の霊薬", {"draught_dawn": 1, "dawnthistle": 1, "opal_shard": 1}, "draught_radiance", 1, "暁の霊薬に薬草と鉱石を重ねる"],
	["draught_seraph", "聖光の霊薬", {"draught_radiance": 1, "halo_bloom": 1, "prism_stone": 1}, "draught_seraph", 1, "光輝の霊薬をさらに煮詰める"],
	["wand_dawn", "暁の杖", {"draught_seraph": 1, "star_lotus": 1, "radiant_ore": 1, "catalyst_quick": 1}, "wand_dawn", 1, "聖光の霊薬に希少な鉱を溶かし、水銀で形を留める"],
	["charm_seraph", "光霊の護符", {"draught_seraph": 1, "seraph_core": 1, "catalyst_prima": 1}, "charm_seraph", 1, "聖光の霊薬と核を第一質料で結びつける"],
	["draught_shade", "陰の霊薬", {"shadeleaf": 2, "nightcap": 1}, "draught_shade", 2, "薬草だけで作れる、いちばん易しい調合"],
	["draught_gloom", "幽闇の霊薬", {"draught_shade": 1, "gloomvine": 1, "onyx_shard": 1}, "draught_gloom", 1, "陰の霊薬に薬草と鉱石を重ねる"],
	["draught_eclipse", "蝕の霊薬", {"draught_gloom": 1, "voidbloom": 1, "umbra_stone": 1}, "draught_eclipse", 1, "幽闇の霊薬をさらに煮詰める"],
	["wand_shade", "陰の杖", {"draught_eclipse": 1, "eclipse_herb": 1, "abyssal_ore": 1, "catalyst_quick": 1}, "wand_shade", 1, "蝕の霊薬に希少な鉱を溶かし、水銀で形を留める"],
	["charm_nether", "闇霊の護符", {"draught_eclipse": 1, "nether_core": 1, "catalyst_prima": 1}, "charm_nether", 1, "蝕の霊薬と核を第一質料で結びつける"],
]

## 一度でも作ったことのあるレシピ id
var discovered: Dictionary = {}

var recipes: Array = []

func _ready() -> void:
	for row in RECIPE_TABLE:
		recipes.append({
			"id": row[0],
			"name": row[1],
			"inputs": row[2],
			"output_id": row[3],
			"output_count": row[4],
			"hint": row[5],
		})

func get_recipe(id: String) -> Dictionary:
	for r in recipes:
		if r["id"] == id:
			return r
	return {}

## 釜の中身(空きは "")を {id: 個数} にまとめる。
func _tally(ingredient_ids: Array) -> Dictionary:
	var counts := {}
	for id in ingredient_ids:
		if id == "":
			continue
		counts[id] = int(counts.get(id, 0)) + 1
	return counts

## 釜の中身と materials がぴったり同じか(過不足なし)。
func _matches(counts: Dictionary, inputs: Dictionary) -> bool:
	if counts.size() != inputs.size():
		return false
	for id in inputs.keys():
		if int(counts.get(id, 0)) != int(inputs[id]):
			return false
	return true

## 釜の中身に一致するレシピを返す。無ければ空。
func find_match(ingredient_ids: Array) -> Dictionary:
	var counts := _tally(ingredient_ids)
	if counts.is_empty():
		return {}
	for r in recipes:
		if _matches(counts, r["inputs"]):
			return r
	return {}

## 釜の中身を見て、UI に出す実況を返す。
## { "ready": bool, "recipe": Dictionary, "note": String }
func preview(ingredient_ids: Array) -> Dictionary:
	var counts := _tally(ingredient_ids)
	if counts.is_empty():
		return {"ready": false, "recipe": {}, "note": "釜が空っぽだ"}
	var r := find_match(ingredient_ids)
	if r.is_empty():
		return {"ready": true, "recipe": {},
			"note": "この組み合わせに心当たりはない。焚けば澱むかもしれない"}
	if is_discovered(r["id"]):
		return {"ready": true, "recipe": r, "note": "%s になりそうだ" % r["name"]}
	return {"ready": true, "recipe": r, "note": "何かができそうな手応えがある…"}

## 手持ちだけで作れるレシピがあるか(図鑑の「作れる」印に使う)。
func can_make(id: String) -> bool:
	var r := get_recipe(id)
	if r.is_empty():
		return false
	for item_id in r["inputs"].keys():
		if Inventory.get_count(item_id) < int(r["inputs"][item_id]):
			return false
	return true

## 釜の中身を消費し、リズムゲームの出来(0.0〜1.0)に応じて成果物を作る。
## 戻り値は成果物 id。失敗なら FAILURE_ID。
func brew(ingredient_ids: Array, performance: float) -> String:
	var r := find_match(ingredient_ids)

	for id in ingredient_ids:
		if id != "":
			Inventory.remove_item(id, 1)

	if r.is_empty():
		EventBus.notify.emit("錬成失敗… 組み合わせが噛み合わなかった")
		EventBus.companion_say.emit("うーん、澱んじゃったね。配合を変えてみよう。")
		Inventory.add_item(FAILURE_ID, 1)
		return FAILURE_ID

	# 拍を外しすぎると魔力が散って澱む
	if performance < 0.4:
		EventBus.notify.emit("錬成失敗… 魔力が乱れて散ってしまった")
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
	EventBus.notify.emit("錬成成功: %s x%d" % [ItemDB.get_display_name(r["output_id"]), amount])
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
