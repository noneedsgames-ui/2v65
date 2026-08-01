extends Node
## 全アイテムの定義データベース。
##
## すべてのアイテムは属性(火・水・風・土・光・闇・無)と力(1〜5)を持つ。
## この2つが錬成(AlchemyDB)の入力になり、図鑑で見比べながら組み合わせを考える。
##
## アイコンは res://assets/icons/<id>.svg。Godot でまだインポートされていない場合は
## 読み込みに失敗するため、UI 側は color をフォールバックとして使う。

enum ItemType { MATERIAL, HERB, ORE, ELIXIR, MAGIC, CATALYST, TOOL, FOOD }

const ICON_DIR := "res://assets/icons/"

# 装備スロット識別子(Equipment.gd と共有)
const SLOT_TOOL := "tool"
const SLOT_ACCESSORY := "accessory"

const TYPE_LABELS := {
	ItemType.MATERIAL: "素材",
	ItemType.HERB: "薬草",
	ItemType.ORE: "鉱石",
	ItemType.ELIXIR: "霊薬",
	ItemType.MAGIC: "魔道具",
	ItemType.CATALYST: "触媒",
	ItemType.TOOL: "道具",
	ItemType.FOOD: "食べ物",
}

## 属性。錬成では同じ属性どうしが響き合い、力が積み上がる。
const ELEMENTS := ["fire", "water", "wind", "earth", "light", "dark", "none"]

const ELEMENT_LABELS := {
	"fire": "火", "water": "水", "wind": "風", "earth": "土",
	"light": "光", "dark": "闇", "none": "無",
}

const ELEMENT_COLORS := {
	"fire": Color(0.88, 0.35, 0.25),
	"water": Color(0.3, 0.58, 0.85),
	"wind": Color(0.45, 0.8, 0.6),
	"earth": Color(0.72, 0.56, 0.32),
	"light": Color(0.95, 0.88, 0.55),
	"dark": Color(0.45, 0.38, 0.6),
	"none": Color(0.7, 0.7, 0.72),
}

## 表の並び: id, 名前, 種別, 属性, 力, 売値, 買値, 最大重ね, 説明
const ITEM_TABLE := [
	["sludge", "澱", "MATERIAL", "none", 0, 1, 2, 99, "錬成に失敗してできた濁り。売り払うくらいしか使い道がない。"],
	["wood", "木材", "MATERIAL", "earth", 1, 2, 4, 99, "木を伐って手に入る素材。建材やクラフトの基本になる。"],
	["stone", "石", "MATERIAL", "earth", 1, 2, 4, 99, "岩を採掘して手に入る素材。加工すると石レンガになる。"],
	["berry", "木の実", "HERB", "water", 1, 3, 6, 99, "茂みから採れる甘い木の実。焼き菓子の材料。"],
	["iron_ore", "鉄鉱石", "ORE", "earth", 2, 6, 12, 99, "硬い鉱脈から採れる鉄鉱石。精錬にはツルハシが要る。"],
	["fiber", "繊維", "HERB", "wind", 1, 2, 4, 99, "草むらから採れる繊維。編むとロープになる。"],
	["plank", "木の板", "MATERIAL", "earth", 1, 5, 10, 99, "木材を加工した板材。道具作りに使う。"],
	["stone_brick", "石レンガ", "MATERIAL", "earth", 2, 6, 12, 99, "石を四角く整えたレンガ。しっかりした造りの材料。"],
	["iron_ingot", "鉄インゴット", "MATERIAL", "earth", 3, 14, 28, 99, "鉄鉱石を精錬したインゴット。上質な道具の材料。"],
	["rope", "ロープ", "MATERIAL", "wind", 1, 5, 10, 99, "繊維を編んだ丈夫なロープ。"],
	["berry_pie", "木の実パイ", "FOOD", "water", 1, 6, 12, 99, "木の実を使った焼き菓子。食べると元気が出る。"],
	["seed_wheat", "麦の種", "HERB", "earth", 1, 2, 4, 99, "畑に植えられる麦の種。"],
	["emberleaf", "燃え葉", "HERB", "fire", 1, 8, 16, 99, "触れるとほのかに熱い葉。火の気を溜め込む。"],
	["scorchroot", "焦げ根", "HERB", "fire", 2, 12, 24, 99, "地熱で焼けた根。噛むと舌が痺れる。"],
	["flamecap", "火傘茸", "HERB", "fire", 3, 16, 32, 99, "傘の裏が赤く光る茸。乾かすと粉が舞う。"],
	["cinderbloom", "燠花", "HERB", "fire", 4, 20, 40, 99, "散り際に火の粉を散らす花。"],
	["phoenix_moss", "不死鳥苔", "HERB", "fire", 5, 24, 48, 99, "焼いても翌朝には生えている苔。"],
	["dewgrass", "露草", "HERB", "water", 1, 8, 16, 99, "朝露をよく含む草。搾ると澄んだ雫が出る。"],
	["tidefern", "潮しだ", "HERB", "water", 2, 12, 24, 99, "海辺に育つしだ。塩気と水気を併せ持つ。"],
	["mirror_lily", "鏡百合", "HERB", "water", 3, 16, 32, 99, "花弁が水面のように景色を映す。"],
	["deepkelp", "深海藻", "HERB", "water", 4, 20, 40, 99, "日の届かぬ淵に育つ藻。ひやりと重い。"],
	["tearvine", "涙蔓", "HERB", "water", 5, 24, 48, 99, "切ると止めどなく雫を垂らす蔓。"],
	["whistlereed", "笛葦", "HERB", "wind", 1, 8, 16, 99, "風が抜けると鳴る葦。軽くしなやか。"],
	["driftcotton", "流れ綿", "HERB", "wind", 2, 12, 24, 99, "風に乗ってどこまでも飛ぶ綿毛。"],
	["galeleaf", "疾風葉", "HERB", "wind", 3, 16, 32, 99, "手を離すと勝手に飛んでいく葉。"],
	["skyroot", "天翔根", "HERB", "wind", 4, 20, 40, 99, "根なのに地面から浮いている。"],
	["stormpetal", "嵐花弁", "HERB", "wind", 5, 24, 48, 99, "近づけると小さな旋風が起きる。"],
	["clayleaf", "土くれ葉", "HERB", "earth", 1, 8, 16, 99, "泥をまとった厚い葉。ずっしり重い。"],
	["ironbark", "鉄樹皮", "HERB", "earth", 2, 12, 24, 99, "刃が欠けるほど硬い樹皮。"],
	["stonefungus", "石茸", "HERB", "earth", 3, 16, 32, 99, "岩そっくりの茸。叩くと硬い音がする。"],
	["deeproot", "地脈根", "HERB", "earth", 4, 20, 40, 99, "地下深くまで伸びる根。土の力を吸う。"],
	["titan_seed", "巨人の種", "HERB", "earth", 5, 24, 48, 99, "抱えるほど大きな種。芽吹く気配はない。"],
	["sunpetal", "陽花弁", "HERB", "light", 1, 8, 16, 99, "日向でだけ開く花弁。ほのかに温かい。"],
	["glowmoss", "灯り苔", "HERB", "light", 2, 12, 24, 99, "夜になると柔らかく光る苔。"],
	["dawnthistle", "暁あざみ", "HERB", "light", 3, 16, 32, 99, "朝日を浴びると棘が透ける。"],
	["halo_bloom", "光輪花", "HERB", "light", 4, 20, 40, 99, "花の周りに淡い輪が浮かぶ。"],
	["star_lotus", "星蓮", "HERB", "light", 5, 24, 48, 99, "夜空を写したような花。芯が瞬く。"],
	["shadeleaf", "陰葉", "HERB", "dark", 1, 8, 16, 99, "日陰でしか育たない黒い葉。"],
	["nightcap", "夜傘茸", "HERB", "dark", 2, 12, 24, 99, "月の出た晩にだけ傘を開く茸。"],
	["gloomvine", "幽蔓", "HERB", "dark", 3, 16, 32, 99, "触れた場所が少し冷たくなる蔓。"],
	["voidbloom", "虚ろ花", "HERB", "dark", 4, 20, 40, 99, "見つめると視線が吸い込まれる花。"],
	["eclipse_herb", "蝕草", "HERB", "dark", 5, 24, 48, 99, "影が本体より濃い、不思議な草。"],
	["ruby_shard", "紅玉のかけら", "ORE", "fire", 2, 20, 40, 99, "欠片でも掌が熱くなる紅い石。"],
	["magma_stone", "溶岩石", "ORE", "fire", 3, 26, 52, 99, "内側がまだ赤い岩。"],
	["sunsteel_ore", "陽鋼鉱", "ORE", "fire", 4, 32, 64, 99, "打つと火花が長く尾を引く。"],
	["ifrit_core", "炎核", "ORE", "fire", 5, 38, 76, 99, "手に取ると脈打つように熱い核。"],
	["aqua_shard", "蒼玉のかけら", "ORE", "water", 2, 20, 40, 99, "内に水が閉じ込められた石。"],
	["frost_stone", "氷結石", "ORE", "water", 3, 26, 52, 99, "常に霜をまとう石。"],
	["abyss_ore", "深淵鉱", "ORE", "water", 4, 32, 64, 99, "底の見えない青をたたえた鉱石。"],
	["leviath_core", "海核", "ORE", "water", 5, 38, 76, 99, "耳を寄せると波の音がする。"],
	["gale_shard", "翠玉のかけら", "ORE", "wind", 2, 20, 40, 99, "軽く、風で転がる石。"],
	["cloud_stone", "雲母石", "ORE", "wind", 3, 26, 52, 99, "層がめくれるたび風が抜ける。"],
	["tempest_ore", "嵐鉱", "ORE", "wind", 4, 32, 64, 99, "帯電していて髪が逆立つ。"],
	["sylph_core", "風核", "ORE", "wind", 5, 38, 76, 99, "手放すと浮かびそうになる核。"],
	["granite_shard", "花崗のかけら", "ORE", "earth", 2, 20, 40, 99, "ありふれた硬い石。"],
	["crystal_stone", "水晶石", "ORE", "earth", 3, 26, 52, 99, "透きとおった六角の柱。"],
	["adaman_ore", "堅牢鉱", "ORE", "earth", 4, 32, 64, 99, "槌を跳ね返すほど硬い。"],
	["golem_core", "土核", "ORE", "earth", 5, 38, 76, 99, "抱えると地に足がつく感じがする。"],
	["opal_shard", "乳白のかけら", "ORE", "light", 2, 20, 40, 99, "角度で色を変える石。"],
	["prism_stone", "稜光石", "ORE", "light", 3, 26, 52, 99, "光を虹に分ける石。"],
	["radiant_ore", "輝鉱", "ORE", "light", 4, 32, 64, 99, "暗がりでも自ら光る。"],
	["seraph_core", "光核", "ORE", "light", 5, 38, 76, 99, "見つめると目の奥が温かい。"],
	["onyx_shard", "黒瑪瑙のかけら", "ORE", "dark", 2, 20, 40, 99, "光を吸う黒い石。"],
	["umbra_stone", "影石", "ORE", "dark", 3, 26, 52, 99, "置くと影が二重になる。"],
	["abyssal_ore", "冥鉱", "ORE", "dark", 4, 32, 64, 99, "重さの割に持つと軽い。"],
	["nether_core", "闇核", "ORE", "dark", 5, 38, 76, 99, "周りの音が少し遠くなる。"],
	["draught_ember", "燠の霊薬", "ELIXIR", "fire", 2, 48, 96, 99, "飲むと芯から温まる。寒さを忘れる。"],
	["draught_blaze", "烈火の霊薬", "ELIXIR", "fire", 3, 62, 124, 99, "血が沸くような高揚。力が湧く。"],
	["draught_inferno", "業火の霊薬", "ELIXIR", "fire", 4, 76, 152, 99, "扱いを誤れば身を焼く、危うい薬。"],
	["draught_dew", "露の霊薬", "ELIXIR", "water", 2, 48, 96, 99, "喉の渇きが嘘のように引く。"],
	["draught_tide", "潮の霊薬", "ELIXIR", "water", 3, 62, 124, 99, "体の澱みが流れ落ちる心地。"],
	["draught_abyss", "深淵の霊薬", "ELIXIR", "water", 4, 76, 152, 99, "静けさが体の芯まで満ちる。"],
	["draught_breeze", "微風の霊薬", "ELIXIR", "wind", 2, 48, 96, 99, "足取りが軽くなる。"],
	["draught_gale", "疾風の霊薬", "ELIXIR", "wind", 3, 62, 124, 99, "風になったように駆けられる。"],
	["draught_storm", "嵐の霊薬", "ELIXIR", "wind", 4, 76, 152, 99, "抑えが利かないほど体が急く。"],
	["draught_clay", "土の霊薬", "ELIXIR", "earth", 2, 48, 96, 99, "体が芯から据わる。"],
	["draught_stone", "岩の霊薬", "ELIXIR", "earth", 3, 62, 124, 99, "打たれても揺るがない硬さ。"],
	["draught_titan", "巨人の霊薬", "ELIXIR", "earth", 4, 76, 152, 99, "腕に山を持てそうな錯覚。"],
	["draught_dawn", "暁の霊薬", "ELIXIR", "light", 2, 48, 96, 99, "目の前が明るく晴れる。"],
	["draught_radiance", "光輝の霊薬", "ELIXIR", "light", 3, 62, 124, 99, "傷の痛みが遠のく。"],
	["draught_seraph", "聖光の霊薬", "ELIXIR", "light", 4, 76, 152, 99, "体が内側から照らされる。"],
	["draught_shade", "陰の霊薬", "ELIXIR", "dark", 2, 48, 96, 99, "気配が薄れ、目立たなくなる。"],
	["draught_gloom", "幽闇の霊薬", "ELIXIR", "dark", 3, 62, 124, 99, "影に溶けるような感覚。"],
	["draught_eclipse", "蝕の霊薬", "ELIXIR", "dark", 4, 76, 152, 99, "己の輪郭があいまいになる。"],
	["wand_ember", "燠の杖", "MAGIC", "fire", 3, 90, 180, 1, "先端がとろ火で灯る杖。"],
	["charm_salamander", "火竜の護符", "MAGIC", "fire", 4, 110, 220, 1, "熱を退ける護符。"],
	["wand_tide", "潮の杖", "MAGIC", "water", 3, 90, 180, 1, "振ると細かな飛沫が舞う杖。"],
	["charm_undine", "水霊の護符", "MAGIC", "water", 4, 110, 220, 1, "渇きを忘れさせる護符。"],
	["wand_gale", "疾風の杖", "MAGIC", "wind", 3, 90, 180, 1, "振るたび風切り音がする杖。"],
	["charm_sylph", "風霊の護符", "MAGIC", "wind", 4, 110, 220, 1, "足音を消す護符。"],
	["wand_stone", "岩の杖", "MAGIC", "earth", 3, 90, 180, 1, "見た目より遥かに重い杖。"],
	["charm_golem", "土霊の護符", "MAGIC", "earth", 4, 110, 220, 1, "転倒を防ぐ護符。"],
	["wand_dawn", "暁の杖", "MAGIC", "light", 3, 90, 180, 1, "暗がりを払う灯りの杖。"],
	["charm_seraph", "光霊の護符", "MAGIC", "light", 4, 110, 220, 1, "闇を寄せつけぬ護符。"],
	["wand_shade", "陰の杖", "MAGIC", "dark", 3, 90, 180, 1, "影を伸ばす杖。"],
	["charm_nether", "闇霊の護符", "MAGIC", "dark", 4, 110, 220, 1, "気配を消す護符。"],
	["catalyst_salt", "錬成塩", "CATALYST", "none", 1, 40, 80, 99, "反応を穏やかにする塩。失敗が減る。"],
	["catalyst_quick", "賢者の水銀", "CATALYST", "none", 3, 70, 140, 99, "反応を加速させる銀色の液。"],
	["catalyst_prima", "第一質料", "CATALYST", "none", 5, 100, 200, 99, "あらゆる物に宿るという原初の粉。"],
	["axe", "斧", "TOOL", "earth", 2, 15, 30, 1, "木を伐るための斧。装備すると木からの採集量が増える。"],
	["pickaxe", "ツルハシ", "TOOL", "earth", 2, 15, 30, 1, "岩や鉱脈を砕くツルハシ。鉄鉱脈の採掘には装備が必須。"],
	["basket", "採集かご", "TOOL", "wind", 2, 12, 24, 1, "背負って使う採集かご。装備するとどの採集でも取れ高が増える。"],
	["stall_kit", "露店キット", "TOOL", "none", 1, 25, 50, 1, "露店を開くための道具一式。持っていると町の広場で商売ができる。"],
	["herb_bag", "薬草袋", "TOOL", "wind", 3, 30, 60, 1, "薬草を潰さず運べる袋。採集量がさらに増える。"],
	["miners_lamp", "坑夫のランプ", "TOOL", "light", 3, 30, 60, 1, "暗がりを照らすランプ。鉱石の目利きが利く。"],
	["bread", "黒パン", "FOOD", "earth", 2, 10, 20, 99, "素朴で腹持ちのよいパン。"],
	["herb_soup", "薬草スープ", "FOOD", "water", 2, 10, 20, 99, "青い香りのするスープ。体が温まる。"],
	["honey_cake", "蜜菓子", "FOOD", "light", 2, 10, 20, 99, "甘く軽い焼き菓子。気分が晴れる。"],
]

## 装備できるものだけ: id -> [スロット, 採集ボーナス]
const EQUIP_TABLE := {
	"axe": ["tool", 1],
	"basket": ["accessory", 1],
	"charm_golem": ["accessory", 2],
	"charm_nether": ["accessory", 2],
	"charm_salamander": ["accessory", 2],
	"charm_seraph": ["accessory", 2],
	"charm_sylph": ["accessory", 2],
	"charm_undine": ["accessory", 2],
	"herb_bag": ["accessory", 2],
	"miners_lamp": ["accessory", 1],
	"pickaxe": ["tool", 1],
	"wand_dawn": ["tool", 2],
	"wand_ember": ["tool", 2],
	"wand_gale": ["tool", 2],
	"wand_shade": ["tool", 2],
	"wand_stone": ["tool", 2],
	"wand_tide": ["tool", 2],
}

var items: Dictionary = {}
var _icon_cache: Dictionary = {}

func _ready() -> void:
	var type_by_name := {
		"MATERIAL": ItemType.MATERIAL, "HERB": ItemType.HERB, "ORE": ItemType.ORE,
		"ELIXIR": ItemType.ELIXIR, "MAGIC": ItemType.MAGIC, "CATALYST": ItemType.CATALYST,
		"TOOL": ItemType.TOOL, "FOOD": ItemType.FOOD,
	}
	for row in ITEM_TABLE:
		var id: String = row[0]
		var equip: Array = EQUIP_TABLE.get(id, ["", 0])
		items[id] = {
			"id": id,
			"name": row[1],
			"type": type_by_name[row[2]],
			"element": row[3],
			"potency": int(row[4]),
			"sell_price": int(row[5]),
			"buy_price": int(row[6]),
			"stack_max": int(row[7]),
			"description": row[8],
			"equip_slot": equip[0],
			"gather_bonus": int(equip[1]),
			"color": ELEMENT_COLORS.get(row[3], Color.WHITE),
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

func get_element(id: String) -> String:
	return get_item(id).get("element", "none")

func get_element_label(id: String) -> String:
	return ELEMENT_LABELS.get(get_element(id), "無")

func get_potency(id: String) -> int:
	return get_item(id).get("potency", 0)

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
	return TYPE_LABELS.get(get_type(id), "その他")

## 錬成の入力になりうるもの(素材・薬草・鉱石・触媒)
func is_ingredient(id: String) -> bool:
	var t := get_type(id)
	return t == ItemType.HERB or t == ItemType.ORE \
		or t == ItemType.MATERIAL or t == ItemType.CATALYST

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

func ids_of_type(type: int) -> Array:
	var out: Array = []
	for id in items.keys():
		if items[id]["type"] == type:
			out.append(id)
	out.sort()
	return out
