extends Node
## 全アイテムの定義データベース。
## 見た目はプレースホルダーとして色付きアイコンを使用する(id -> color)。

enum ItemType { MATERIAL, TOOL, FOOD, SEED, PRODUCT }

var items: Dictionary = {}

func _ready() -> void:
	# sell_price: 店に売る時の受取額 / buy_price: 店から買う時の支払額(常に sell より高い)
	_register("wood", "木材", ItemType.MATERIAL, Color(0.55, 0.35, 0.15), 2, 4, 99, "木を伐って手に入る素材。")
	_register("stone", "石", ItemType.MATERIAL, Color(0.6, 0.6, 0.6), 2, 4, 99, "岩を採掘して手に入る素材。")
	_register("berry", "木の実", ItemType.MATERIAL, Color(0.8, 0.1, 0.3), 3, 6, 99, "茂みから採れる木の実。")
	_register("iron_ore", "鉄鉱石", ItemType.MATERIAL, Color(0.75, 0.55, 0.4), 6, 12, 99, "硬い鉱脈から採れる鉄鉱石。")
	_register("fiber", "繊維", ItemType.MATERIAL, Color(0.4, 0.7, 0.3), 2, 4, 99, "草むらから採れる繊維。")

	_register("plank", "木の板", ItemType.PRODUCT, Color(0.7, 0.5, 0.25), 5, 10, 99, "木材を加工した板材。")
	_register("stone_brick", "石レンガ", ItemType.PRODUCT, Color(0.5, 0.5, 0.55), 6, 12, 99, "石を加工したレンガ。")
	_register("iron_ingot", "鉄インゴット", ItemType.PRODUCT, Color(0.8, 0.8, 0.85), 14, 28, 99, "鉄鉱石を精錬したインゴット。")
	_register("rope", "ロープ", ItemType.PRODUCT, Color(0.85, 0.75, 0.5), 5, 10, 99, "繊維を編んだロープ。")

	_register("axe", "斧", ItemType.TOOL, Color(0.65, 0.65, 0.7), 15, 30, 1, "木を効率よく伐るための道具。")
	_register("pickaxe", "ツルハシ", ItemType.TOOL, Color(0.55, 0.55, 0.6), 15, 30, 1, "岩を効率よく採掘するための道具。")
	_register("basket", "採集かご", ItemType.TOOL, Color(0.75, 0.6, 0.35), 12, 24, 1, "所持数上限を増やすかご。")
	_register("stall_kit", "露店キット", ItemType.TOOL, Color(0.9, 0.7, 0.2), 25, 50, 1, "露店を開くための道具一式。")

	_register("berry_pie", "木の実パイ", ItemType.FOOD, Color(0.9, 0.6, 0.3), 6, 12, 99, "木の実を使った焼き菓子。")
	_register("seed_wheat", "麦の種", ItemType.SEED, Color(0.9, 0.85, 0.3), 2, 4, 99, "畑に植えられる種。")

func _register(id: String, display_name: String, type: int, color: Color, sell_price: int, buy_price: int, stack_max: int, description: String) -> void:
	items[id] = {
		"id": id,
		"name": display_name,
		"type": type,
		"color": color,
		"sell_price": sell_price,
		"buy_price": buy_price,
		"stack_max": stack_max,
		"description": description,
	}

func get_item(id: String) -> Dictionary:
	return items.get(id, {})

## Node.get_name() (StringName を返すネイティブメソッド)と衝突するため
## get_display_name という名前にしている。
func get_display_name(id: String) -> String:
	var it := get_item(id)
	return it.get("name", id) if not it.is_empty() else id

func get_color(id: String) -> Color:
	var it := get_item(id)
	return it.get("color", Color.WHITE) if not it.is_empty() else Color.WHITE

func get_sell_price(id: String) -> int:
	var it := get_item(id)
	return it.get("sell_price", 0) if not it.is_empty() else 0

func get_buy_price(id: String) -> int:
	var it := get_item(id)
	return it.get("buy_price", 0) if not it.is_empty() else 0

func get_stack_max(id: String) -> int:
	var it := get_item(id)
	return it.get("stack_max", 99) if not it.is_empty() else 99

func all_ids() -> Array:
	return items.keys()
