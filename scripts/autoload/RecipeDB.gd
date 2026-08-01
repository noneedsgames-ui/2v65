extends Node
## クラフトレシピの定義データベース。
##
## レシピは最初から全部見えているわけではない。材料をひとつでも持ったことがあると
## 「発見」され、名前と必要材料が読めるようになる。それまでは「？？？」のまま。
## また、作るときに手さばき(タイミング)のミニゲームがあり、結果で品質が変わる。

signal recipe_discovered(recipe_id: String)

enum Category { MATERIAL, TOOL, FOOD, SPECIAL }

const CATEGORY_LABELS := {
	Category.MATERIAL: "加工材",
	Category.TOOL: "道具",
	Category.FOOD: "食べ物",
	Category.SPECIAL: "特別",
}

## 品質。ミニゲームの結果で決まり、出来高や売値に効く。
enum Quality { POOR, NORMAL, GOOD, PERFECT }

const QUALITY_LABELS := {
	Quality.POOR: "粗い出来",
	Quality.NORMAL: "ふつうの出来",
	Quality.GOOD: "良い出来",
	Quality.PERFECT: "会心の出来",
}

var recipes: Array = []
var discovered: Dictionary = {}

func _ready() -> void:
	_register("plank", "木の板", {"wood": 2}, "plank", 1, Category.MATERIAL)
	_register("stone_brick", "石レンガ", {"stone": 2}, "stone_brick", 1, Category.MATERIAL)
	_register("rope", "ロープ", {"fiber": 3}, "rope", 1, Category.MATERIAL)
	_register("iron_ingot", "鉄インゴット", {"iron_ore": 2, "wood": 1}, "iron_ingot", 1, Category.MATERIAL)
	_register("axe", "斧", {"plank": 3, "stone": 2}, "axe", 1, Category.TOOL)
	_register("pickaxe", "ツルハシ", {"plank": 3, "iron_ingot": 2}, "pickaxe", 1, Category.TOOL)
	_register("basket", "採集かご", {"plank": 2, "rope": 2}, "basket", 1, Category.TOOL)
	_register("stall_kit", "露店キット", {"plank": 6, "rope": 3, "stone_brick": 2}, "stall_kit", 1, Category.SPECIAL)
	_register("berry_pie", "木の実パイ", {"berry": 3, "wood": 1}, "berry_pie", 1, Category.FOOD)

func _register(id: String, display_name: String, inputs: Dictionary,
		output_id: String, output_count: int, category: int) -> void:
	recipes.append({
		"id": id,
		"name": display_name,
		"inputs": inputs,
		"output_id": output_id,
		"output_count": output_count,
		"category": category,
	})

func get_recipe(id: String) -> Dictionary:
	for r in recipes:
		if r["id"] == id:
			return r
	return {}

# ---- レシピの発見 ----

func is_discovered(id: String) -> bool:
	return discovered.has(id)

## 手持ちの材料を見て、作れそうなレシピを「発見」する。
## 材料をひとつでも持っていれば、そのレシピの存在に気づく。
func discover_from_inventory() -> void:
	for r in recipes:
		if discovered.has(r["id"]):
			continue
		for item_id in r["inputs"].keys():
			if Inventory.get_count(item_id) > 0:
				discovered[r["id"]] = true
				recipe_discovered.emit(r["id"])
				EventBus.notify.emit("レシピをひらめいた: %s" % r["name"])
				break

func categories_in_order() -> Array:
	return [Category.MATERIAL, Category.TOOL, Category.FOOD, Category.SPECIAL]

func recipes_in_category(category: int) -> Array:
	var out: Array = []
	for r in recipes:
		if r["category"] == category:
			out.append(r)
	return out

# ---- 作成 ----

func can_craft(id: String) -> bool:
	var r := get_recipe(id)
	if r.is_empty():
		return false
	for item_id in r["inputs"].keys():
		if Inventory.get_count(item_id) < int(r["inputs"][item_id]):
			return false
	return true

## 品質に応じた出来高。会心なら1つおまけ、粗いと1つ減ることがある。
func _bonus_for(quality: int) -> int:
	match quality:
		Quality.PERFECT: return 1
		Quality.GOOD: return 0
		Quality.POOR: return -1
	return 0

## quality は Quality の値。UI 側のミニゲームの結果を渡す。
func craft(id: String, quality: int = Quality.NORMAL) -> bool:
	if not can_craft(id):
		return false
	var r := get_recipe(id)
	for item_id in r["inputs"].keys():
		Inventory.remove_item(item_id, int(r["inputs"][item_id]))
	var amount: int = max(1, int(r["output_count"]) + _bonus_for(quality))
	Inventory.add_item(r["output_id"], amount)
	return true

func craft_amount(id: String, quality: int) -> int:
	var r := get_recipe(id)
	if r.is_empty():
		return 0
	return max(1, int(r["output_count"]) + _bonus_for(quality))

func to_save_data() -> Dictionary:
	return {"discovered": discovered.keys()}

func load_save_data(data: Dictionary) -> void:
	discovered.clear()
	for id in data.get("discovered", []):
		discovered[str(id)] = true
