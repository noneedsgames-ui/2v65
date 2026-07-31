extends Node
## 全アイテムの定義データベース。
## アイコンは res://assets/icons/<id>.svg を使用する。Godot でまだインポートされて
## いない場合は読み込みに失敗するため、UI 側は color をフォールバックとして使う。

enum ItemType { MATERIAL, TOOL, FOOD, SEED, PRODUCT }

const ICON_DIR := "res://assets/icons/"

# 装備スロット識別子(Equipment.gd と共有)
const SLOT_TOOL := "tool"
const SLOT_ACCESSORY := "accessory"

var items: Dictionary = {}

var _icon_cache: Dictionary = {}

func _ready() -> void:
	# sell_price: 店に売る時の受取額 / buy_price: 店から買う時の支払額(常に sell より高い)
	_register("wood", "木材", ItemType.MATERIAL, Color(0.55, 0.35, 0.15), 2, 4, 99, "木を伐って手に入る素材。建材やクラフトの基本になる。")
	_register("stone", "石", ItemType.MATERIAL, Color(0.6, 0.6, 0.6), 2, 4, 99, "岩を採掘して手に入る素材。加工すると石レンガになる。")
	_register("berry", "木の実", ItemType.MATERIAL, Color(0.8, 0.1, 0.3), 3, 6, 99, "茂みから採れる甘い木の実。焼き菓子の材料。")
	_register("iron_ore", "鉄鉱石", ItemType.MATERIAL, Color(0.75, 0.55, 0.4), 6, 12, 99, "硬い鉱脈から採れる鉄鉱石。精錬にはツルハシが要る。")
	_register("fiber", "繊維", ItemType.MATERIAL, Color(0.4, 0.7, 0.3), 2, 4, 99, "草むらから採れる繊維。編むとロープになる。")

	_register("plank", "木の板", ItemType.PRODUCT, Color(0.7, 0.5, 0.25), 5, 10, 99, "木材を加工した板材。道具作りに使う。")
	_register("stone_brick", "石レンガ", ItemType.PRODUCT, Color(0.5, 0.5, 0.55), 6, 12, 99, "石を四角く整えたレンガ。しっかりした造りの材料。")
	_register("iron_ingot", "鉄インゴット", ItemType.PRODUCT, Color(0.8, 0.8, 0.85), 14, 28, 99, "鉄鉱石を精錬したインゴット。上質な道具の材料。")
	_register("rope", "ロープ", ItemType.PRODUCT, Color(0.85, 0.75, 0.5), 5, 10, 99, "繊維を編んだ丈夫なロープ。")

	_register("axe", "斧", ItemType.TOOL, Color(0.65, 0.65, 0.7), 15, 30, 1,
		"木を伐るための斧。装備すると木からの採集量が増える。", SLOT_TOOL, 1)
	_register("pickaxe", "ツルハシ", ItemType.TOOL, Color(0.55, 0.55, 0.6), 15, 30, 1,
		"岩や鉱脈を砕くツルハシ。鉄鉱脈の採掘には装備が必須。", SLOT_TOOL, 1)
	_register("basket", "採集かご", ItemType.TOOL, Color(0.75, 0.6, 0.35), 12, 24, 1,
		"背負って使う採集かご。装備するとどの採集でも取れ高が増える。", SLOT_ACCESSORY, 1)
	_register("stall_kit", "露店キット", ItemType.TOOL, Color(0.9, 0.7, 0.2), 25, 50, 1,
		"露店を開くための道具一式。持っていると町の広場で商売ができる。")

	_register("berry_pie", "木の実パイ", ItemType.FOOD, Color(0.9, 0.6, 0.3), 6, 12, 99, "木の実を使った焼き菓子。食べると元気が出る。")
	_register("seed_wheat", "麦の種", ItemType.SEED, Color(0.9, 0.85, 0.3), 2, 4, 99, "畑に植えられる麦の種。")

func _register(id: String, display_name: String, type: int, color: Color, sell_price: int,
		buy_price: int, stack_max: int, description: String,
		equip_slot: String = "", gather_bonus: int = 0) -> void:
	items[id] = {
		"id": id,
		"name": display_name,
		"type": type,
		"color": color,
		"sell_price": sell_price,
		"buy_price": buy_price,
		"stack_max": stack_max,
		"description": description,
		"equip_slot": equip_slot,
		"gather_bonus": gather_bonus,
		"icon": ICON_DIR + id + ".svg",
	}

func get_item(id: String) -> Dictionary:
	return items.get(id, {})

## Node.get_name() (StringName を返すネイティブメソッド)と衝突するため
## get_display_name という名前にしている。
func get_display_name(id: String) -> String:
	return get_item(id).get("name", id)

func get_description(id: String) -> String:
	return get_item(id).get("description", "")

func get_color(id: String) -> Color:
	return get_item(id).get("color", Color.WHITE)

func get_type(id: String) -> int:
	return get_item(id).get("type", ItemType.MATERIAL)

func get_sell_price(id: String) -> int:
	return get_item(id).get("sell_price", 0)

func get_buy_price(id: String) -> int:
	return get_item(id).get("buy_price", 0)

func get_stack_max(id: String) -> int:
	return get_item(id).get("stack_max", 99)

func get_equip_slot(id: String) -> String:
	return get_item(id).get("equip_slot", "")

func is_equippable(id: String) -> bool:
	return get_equip_slot(id) != ""

func get_gather_bonus(id: String) -> int:
	return get_item(id).get("gather_bonus", 0)

func get_type_label(id: String) -> String:
	match get_type(id):
		ItemType.MATERIAL: return "素材"
		ItemType.TOOL: return "道具"
		ItemType.FOOD: return "食べ物"
		ItemType.SEED: return "種"
		ItemType.PRODUCT: return "加工品"
	return "その他"

## アイコンテクスチャを返す。まだ Godot にインポートされていない SVG の場合は
## null を返すので、呼び出し側は get_color() のフォールバックを使うこと。
func get_icon(id: String) -> Texture2D:
	if _icon_cache.has(id):
		return _icon_cache[id]
	var path: String = get_item(id).get("icon", "")
	var tex: Texture2D = null
	if path != "" and ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_icon_cache[id] = tex
	return tex

func all_ids() -> Array:
	return items.keys()
