extends Node
## クラフトレシピの定義データベース。

var recipes: Array = []

func _ready() -> void:
	_register("plank", "木の板", {"wood": 2}, "plank", 1)
	_register("stone_brick", "石レンガ", {"stone": 2}, "stone_brick", 1)
	_register("rope", "ロープ", {"fiber": 3}, "rope", 1)
	_register("iron_ingot", "鉄インゴット", {"iron_ore": 2, "wood": 1}, "iron_ingot", 1)
	_register("axe", "斧", {"plank": 3, "stone": 2}, "axe", 1)
	_register("pickaxe", "ツルハシ", {"plank": 3, "iron_ingot": 2}, "pickaxe", 1)
	_register("basket", "採集かご", {"plank": 2, "rope": 2}, "basket", 1)
	_register("stall_kit", "露店キット", {"plank": 6, "rope": 3, "stone_brick": 2}, "stall_kit", 1)
	_register("berry_pie", "木の実パイ", {"berry": 3, "wood": 1}, "berry_pie", 1)

func _register(id: String, display_name: String, inputs: Dictionary, output_id: String, output_count: int) -> void:
	recipes.append({
		"id": id,
		"name": display_name,
		"inputs": inputs,
		"output_id": output_id,
		"output_count": output_count,
	})

func get_recipe(id: String) -> Dictionary:
	for r in recipes:
		if r["id"] == id:
			return r
	return {}

func can_craft(id: String) -> bool:
	var r := get_recipe(id)
	if r.is_empty():
		return false
	for item_id in r["inputs"].keys():
		if Inventory.get_count(item_id) < int(r["inputs"][item_id]):
			return false
	return true

func craft(id: String) -> bool:
	if not can_craft(id):
		return false
	var r := get_recipe(id)
	for item_id in r["inputs"].keys():
		Inventory.remove_item(item_id, int(r["inputs"][item_id]))
	Inventory.add_item(r["output_id"], int(r["output_count"]))
	return true
