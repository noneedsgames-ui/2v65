extends Node
## 全アイテムの定義データベース。
##
## アイテムは種別(薬草・鉱石・霊薬・魔道具・触媒・素材・道具・食べ物)と、
## 売買値・重ねられる数・説明を持つ。錬成(AlchemyDB)は決まった組み合わせで作るので、
## アイテム側に錬成用の数値は持たせていない。
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

## 表の並び: id, 名前, 種別, 売値, 買値, 最大重ね, 色R, 色G, 色B, 説明
const ITEM_TABLE := [
	["sludge", "澱", "MATERIAL", 1, 2, 99, 0.70, 0.70, 0.72, "錬成に失敗してできた濁り。売り払うくらいしか使い道がない。"],
	["wood", "木材", "MATERIAL", 2, 4, 99, 0.72, 0.56, 0.32, "木を伐って手に入る素材。建材やクラフトの基本になる。"],
	["stone", "石", "MATERIAL", 2, 4, 99, 0.72, 0.56, 0.32, "岩を採掘して手に入る素材。加工すると石レンガになる。"],
	["berry", "木の実", "HERB", 3, 6, 99, 0.30, 0.58, 0.85, "茂みから採れる甘い木の実。焼き菓子の材料。"],
	["iron_ore", "鉄鉱石", "ORE", 6, 12, 99, 0.72, 0.56, 0.32, "硬い鉱脈から採れる鉄鉱石。精錬にはツルハシが要る。"],
	["fiber", "繊維", "HERB", 2, 4, 99, 0.45, 0.80, 0.60, "草むらから採れる繊維。編むとロープになる。"],
	["plank", "木の板", "MATERIAL", 5, 10, 99, 0.72, 0.56, 0.32, "木材を加工した板材。道具作りに使う。"],
	["stone_brick", "石レンガ", "MATERIAL", 6, 12, 99, 0.72, 0.56, 0.32, "石を四角く整えたレンガ。しっかりした造りの材料。"],
	["iron_ingot", "鉄インゴット", "MATERIAL", 14, 28, 99, 0.72, 0.56, 0.32, "鉄鉱石を精錬したインゴット。上質な道具の材料。"],
	["rope", "ロープ", "MATERIAL", 5, 10, 99, 0.45, 0.80, 0.60, "繊維を編んだ丈夫なロープ。"],
	["berry_pie", "木の実パイ", "FOOD", 6, 12, 99, 0.30, 0.58, 0.85, "木の実を使った焼き菓子。食べると元気が出る。"],
	["seed_wheat", "麦の種", "HERB", 2, 4, 99, 0.72, 0.56, 0.32, "畑に植えられる麦の種。"],
	["emberleaf", "燃え葉", "HERB", 8, 16, 99, 0.88, 0.35, 0.25, "触れるとほのかに熱い葉。火の気を溜め込む。"],
	["scorchroot", "焦げ根", "HERB", 12, 24, 99, 0.88, 0.35, 0.25, "地熱で焼けた根。噛むと舌が痺れる。"],
	["flamecap", "火傘茸", "HERB", 16, 32, 99, 0.88, 0.35, 0.25, "傘の裏が赤く光る茸。乾かすと粉が舞う。"],
	["cinderbloom", "燠花", "HERB", 20, 40, 99, 0.88, 0.35, 0.25, "散り際に火の粉を散らす花。"],
	["phoenix_moss", "不死鳥苔", "HERB", 24, 48, 99, 0.88, 0.35, 0.25, "焼いても翌朝には生えている苔。"],
	["dewgrass", "露草", "HERB", 8, 16, 99, 0.30, 0.58, 0.85, "朝露をよく含む草。搾ると澄んだ雫が出る。"],
	["tidefern", "潮しだ", "HERB", 12, 24, 99, 0.30, 0.58, 0.85, "海辺に育つしだ。塩気と水気を併せ持つ。"],
	["mirror_lily", "鏡百合", "HERB", 16, 32, 99, 0.30, 0.58, 0.85, "花弁が水面のように景色を映す。"],
	["deepkelp", "深海藻", "HERB", 20, 40, 99, 0.30, 0.58, 0.85, "日の届かぬ淵に育つ藻。ひやりと重い。"],
	["tearvine", "涙蔓", "HERB", 24, 48, 99, 0.30, 0.58, 0.85, "切ると止めどなく雫を垂らす蔓。"],
	["whistlereed", "笛葦", "HERB", 8, 16, 99, 0.45, 0.80, 0.60, "風が抜けると鳴る葦。軽くしなやか。"],
	["driftcotton", "流れ綿", "HERB", 12, 24, 99, 0.45, 0.80, 0.60, "風に乗ってどこまでも飛ぶ綿毛。"],
	["galeleaf", "疾風葉", "HERB", 16, 32, 99, 0.45, 0.80, 0.60, "手を離すと勝手に飛んでいく葉。"],
	["skyroot", "天翔根", "HERB", 20, 40, 99, 0.45, 0.80, 0.60, "根なのに地面から浮いている。"],
	["stormpetal", "嵐花弁", "HERB", 24, 48, 99, 0.45, 0.80, 0.60, "近づけると小さな旋風が起きる。"],
	["clayleaf", "土くれ葉", "HERB", 8, 16, 99, 0.72, 0.56, 0.32, "泥をまとった厚い葉。ずっしり重い。"],
	["ironbark", "鉄樹皮", "HERB", 12, 24, 99, 0.72, 0.56, 0.32, "刃が欠けるほど硬い樹皮。"],
	["stonefungus", "石茸", "HERB", 16, 32, 99, 0.72, 0.56, 0.32, "岩そっくりの茸。叩くと硬い音がする。"],
	["deeproot", "地脈根", "HERB", 20, 40, 99, 0.72, 0.56, 0.32, "地下深くまで伸びる根。土の力を吸う。"],
	["titan_seed", "巨人の種", "HERB", 24, 48, 99, 0.72, 0.56, 0.32, "抱えるほど大きな種。芽吹く気配はない。"],
	["sunpetal", "陽花弁", "HERB", 8, 16, 99, 0.95, 0.88, 0.55, "日向でだけ開く花弁。ほのかに温かい。"],
	["glowmoss", "灯り苔", "HERB", 12, 24, 99, 0.95, 0.88, 0.55, "夜になると柔らかく光る苔。"],
	["dawnthistle", "暁あざみ", "HERB", 16, 32, 99, 0.95, 0.88, 0.55, "朝日を浴びると棘が透ける。"],
	["halo_bloom", "光輪花", "HERB", 20, 40, 99, 0.95, 0.88, 0.55, "花の周りに淡い輪が浮かぶ。"],
	["star_lotus", "星蓮", "HERB", 24, 48, 99, 0.95, 0.88, 0.55, "夜空を写したような花。芯が瞬く。"],
	["shadeleaf", "陰葉", "HERB", 8, 16, 99, 0.45, 0.38, 0.60, "日陰でしか育たない黒い葉。"],
	["nightcap", "夜傘茸", "HERB", 12, 24, 99, 0.45, 0.38, 0.60, "月の出た晩にだけ傘を開く茸。"],
	["gloomvine", "幽蔓", "HERB", 16, 32, 99, 0.45, 0.38, 0.60, "触れた場所が少し冷たくなる蔓。"],
	["voidbloom", "虚ろ花", "HERB", 20, 40, 99, 0.45, 0.38, 0.60, "見つめると視線が吸い込まれる花。"],
	["eclipse_herb", "蝕草", "HERB", 24, 48, 99, 0.45, 0.38, 0.60, "影が本体より濃い、不思議な草。"],
	["ruby_shard", "紅玉のかけら", "ORE", 20, 40, 99, 0.88, 0.35, 0.25, "欠片でも掌が熱くなる紅い石。"],
	["magma_stone", "溶岩石", "ORE", 26, 52, 99, 0.88, 0.35, 0.25, "内側がまだ赤い岩。"],
	["sunsteel_ore", "陽鋼鉱", "ORE", 32, 64, 99, 0.88, 0.35, 0.25, "打つと火花が長く尾を引く。"],
	["ifrit_core", "炎核", "ORE", 38, 76, 99, 0.88, 0.35, 0.25, "手に取ると脈打つように熱い核。"],
	["aqua_shard", "蒼玉のかけら", "ORE", 20, 40, 99, 0.30, 0.58, 0.85, "内に水が閉じ込められた石。"],
	["frost_stone", "氷結石", "ORE", 26, 52, 99, 0.30, 0.58, 0.85, "常に霜をまとう石。"],
	["abyss_ore", "深淵鉱", "ORE", 32, 64, 99, 0.30, 0.58, 0.85, "底の見えない青をたたえた鉱石。"],
	["leviath_core", "海核", "ORE", 38, 76, 99, 0.30, 0.58, 0.85, "耳を寄せると波の音がする。"],
	["gale_shard", "翠玉のかけら", "ORE", 20, 40, 99, 0.45, 0.80, 0.60, "軽く、風で転がる石。"],
	["cloud_stone", "雲母石", "ORE", 26, 52, 99, 0.45, 0.80, 0.60, "層がめくれるたび風が抜ける。"],
	["tempest_ore", "嵐鉱", "ORE", 32, 64, 99, 0.45, 0.80, 0.60, "帯電していて髪が逆立つ。"],
	["sylph_core", "風核", "ORE", 38, 76, 99, 0.45, 0.80, 0.60, "手放すと浮かびそうになる核。"],
	["granite_shard", "花崗のかけら", "ORE", 20, 40, 99, 0.72, 0.56, 0.32, "ありふれた硬い石。"],
	["crystal_stone", "水晶石", "ORE", 26, 52, 99, 0.72, 0.56, 0.32, "透きとおった六角の柱。"],
	["adaman_ore", "堅牢鉱", "ORE", 32, 64, 99, 0.72, 0.56, 0.32, "槌を跳ね返すほど硬い。"],
	["golem_core", "土核", "ORE", 38, 76, 99, 0.72, 0.56, 0.32, "抱えると地に足がつく感じがする。"],
	["opal_shard", "乳白のかけら", "ORE", 20, 40, 99, 0.95, 0.88, 0.55, "角度で色を変える石。"],
	["prism_stone", "稜光石", "ORE", 26, 52, 99, 0.95, 0.88, 0.55, "光を虹に分ける石。"],
	["radiant_ore", "輝鉱", "ORE", 32, 64, 99, 0.95, 0.88, 0.55, "暗がりでも自ら光る。"],
	["seraph_core", "光核", "ORE", 38, 76, 99, 0.95, 0.88, 0.55, "見つめると目の奥が温かい。"],
	["onyx_shard", "黒瑪瑙のかけら", "ORE", 20, 40, 99, 0.45, 0.38, 0.60, "光を吸う黒い石。"],
	["umbra_stone", "影石", "ORE", 26, 52, 99, 0.45, 0.38, 0.60, "置くと影が二重になる。"],
	["abyssal_ore", "冥鉱", "ORE", 32, 64, 99, 0.45, 0.38, 0.60, "重さの割に持つと軽い。"],
	["nether_core", "闇核", "ORE", 38, 76, 99, 0.45, 0.38, 0.60, "周りの音が少し遠くなる。"],
	["draught_ember", "燠の霊薬", "ELIXIR", 48, 96, 99, 0.88, 0.35, 0.25, "飲むと芯から温まる。寒さを忘れる。"],
	["draught_blaze", "烈火の霊薬", "ELIXIR", 62, 124, 99, 0.88, 0.35, 0.25, "血が沸くような高揚。力が湧く。"],
	["draught_inferno", "業火の霊薬", "ELIXIR", 76, 152, 99, 0.88, 0.35, 0.25, "扱いを誤れば身を焼く、危うい薬。"],
	["draught_dew", "露の霊薬", "ELIXIR", 48, 96, 99, 0.30, 0.58, 0.85, "喉の渇きが嘘のように引く。"],
	["draught_tide", "潮の霊薬", "ELIXIR", 62, 124, 99, 0.30, 0.58, 0.85, "体の澱みが流れ落ちる心地。"],
	["draught_abyss", "深淵の霊薬", "ELIXIR", 76, 152, 99, 0.30, 0.58, 0.85, "静けさが体の芯まで満ちる。"],
	["draught_breeze", "微風の霊薬", "ELIXIR", 48, 96, 99, 0.45, 0.80, 0.60, "足取りが軽くなる。"],
	["draught_gale", "疾風の霊薬", "ELIXIR", 62, 124, 99, 0.45, 0.80, 0.60, "風になったように駆けられる。"],
	["draught_storm", "嵐の霊薬", "ELIXIR", 76, 152, 99, 0.45, 0.80, 0.60, "抑えが利かないほど体が急く。"],
	["draught_clay", "土の霊薬", "ELIXIR", 48, 96, 99, 0.72, 0.56, 0.32, "体が芯から据わる。"],
	["draught_stone", "岩の霊薬", "ELIXIR", 62, 124, 99, 0.72, 0.56, 0.32, "打たれても揺るがない硬さ。"],
	["draught_titan", "巨人の霊薬", "ELIXIR", 76, 152, 99, 0.72, 0.56, 0.32, "腕に山を持てそうな錯覚。"],
	["draught_dawn", "暁の霊薬", "ELIXIR", 48, 96, 99, 0.95, 0.88, 0.55, "目の前が明るく晴れる。"],
	["draught_radiance", "光輝の霊薬", "ELIXIR", 62, 124, 99, 0.95, 0.88, 0.55, "傷の痛みが遠のく。"],
	["draught_seraph", "聖光の霊薬", "ELIXIR", 76, 152, 99, 0.95, 0.88, 0.55, "体が内側から照らされる。"],
	["draught_shade", "陰の霊薬", "ELIXIR", 48, 96, 99, 0.45, 0.38, 0.60, "気配が薄れ、目立たなくなる。"],
	["draught_gloom", "幽闇の霊薬", "ELIXIR", 62, 124, 99, 0.45, 0.38, 0.60, "影に溶けるような感覚。"],
	["draught_eclipse", "蝕の霊薬", "ELIXIR", 76, 152, 99, 0.45, 0.38, 0.60, "己の輪郭があいまいになる。"],
	["wand_ember", "燠の杖", "MAGIC", 90, 180, 1, 0.88, 0.35, 0.25, "先端がとろ火で灯る杖。"],
	["charm_salamander", "火竜の護符", "MAGIC", 110, 220, 1, 0.88, 0.35, 0.25, "熱を退ける護符。"],
	["wand_tide", "潮の杖", "MAGIC", 90, 180, 1, 0.30, 0.58, 0.85, "振ると細かな飛沫が舞う杖。"],
	["charm_undine", "水霊の護符", "MAGIC", 110, 220, 1, 0.30, 0.58, 0.85, "渇きを忘れさせる護符。"],
	["wand_gale", "疾風の杖", "MAGIC", 90, 180, 1, 0.45, 0.80, 0.60, "振るたび風切り音がする杖。"],
	["charm_sylph", "風霊の護符", "MAGIC", 110, 220, 1, 0.45, 0.80, 0.60, "足音を消す護符。"],
	["wand_stone", "岩の杖", "MAGIC", 90, 180, 1, 0.72, 0.56, 0.32, "見た目より遥かに重い杖。"],
	["charm_golem", "土霊の護符", "MAGIC", 110, 220, 1, 0.72, 0.56, 0.32, "転倒を防ぐ護符。"],
	["wand_dawn", "暁の杖", "MAGIC", 90, 180, 1, 0.95, 0.88, 0.55, "暗がりを払う灯りの杖。"],
	["charm_seraph", "光霊の護符", "MAGIC", 110, 220, 1, 0.95, 0.88, 0.55, "闇を寄せつけぬ護符。"],
	["wand_shade", "陰の杖", "MAGIC", 90, 180, 1, 0.45, 0.38, 0.60, "影を伸ばす杖。"],
	["charm_nether", "闇霊の護符", "MAGIC", 110, 220, 1, 0.45, 0.38, 0.60, "気配を消す護符。"],
	["catalyst_salt", "錬成塩", "CATALYST", 40, 80, 99, 0.70, 0.70, 0.72, "反応を穏やかにする塩。失敗が減る。"],
	["catalyst_quick", "賢者の水銀", "CATALYST", 70, 140, 99, 0.70, 0.70, 0.72, "反応を加速させる銀色の液。"],
	["catalyst_prima", "第一質料", "CATALYST", 100, 200, 99, 0.70, 0.70, 0.72, "あらゆる物に宿るという原初の粉。"],
	["axe", "斧", "TOOL", 15, 30, 1, 0.72, 0.56, 0.32, "木を伐るための斧。装備すると木からの採集量が増える。"],
	["pickaxe", "ツルハシ", "TOOL", 15, 30, 1, 0.72, 0.56, 0.32, "岩や鉱脈を砕くツルハシ。鉄鉱脈の採掘には装備が必須。"],
	["basket", "採集かご", "TOOL", 12, 24, 1, 0.45, 0.80, 0.60, "背負って使う採集かご。装備するとどの採集でも取れ高が増える。"],
	["stall_kit", "露店キット", "TOOL", 25, 50, 1, 0.70, 0.70, 0.72, "露店を開くための道具一式。持っていると町の広場で商売ができる。"],
	["herb_bag", "薬草袋", "TOOL", 30, 60, 1, 0.45, 0.80, 0.60, "薬草を潰さず運べる袋。採集量がさらに増える。"],
	["miners_lamp", "坑夫のランプ", "TOOL", 30, 60, 1, 0.95, 0.88, 0.55, "暗がりを照らすランプ。鉱石の目利きが利く。"],
	["bread", "黒パン", "FOOD", 10, 20, 99, 0.72, 0.56, 0.32, "素朴で腹持ちのよいパン。"],
	["herb_soup", "薬草スープ", "FOOD", 10, 20, 99, 0.30, 0.58, 0.85, "青い香りのするスープ。体が温まる。"],
	["honey_cake", "蜜菓子", "FOOD", 10, 20, 99, 0.95, 0.88, 0.55, "甘く軽い焼き菓子。気分が晴れる。"],
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
			"sell_price": int(row[3]),
			"buy_price": int(row[4]),
			"stack_max": int(row[5]),
			"color": Color(row[6], row[7], row[8]),
			"description": row[9],
			"equip_slot": equip[0],
			"gather_bonus": int(equip[1]),
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
	return TYPE_LABELS.get(get_type(id), "その他")

## 錬成の釜に入れられるもの(素材・薬草・鉱石・触媒・霊薬)。
## 霊薬を含むのは、下位の霊薬を材料に上位を作るため。
func is_ingredient(id: String) -> bool:
	var t := get_type(id)
	return t == ItemType.HERB or t == ItemType.ORE or t == ItemType.MATERIAL \
		or t == ItemType.CATALYST or t == ItemType.ELIXIR

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
