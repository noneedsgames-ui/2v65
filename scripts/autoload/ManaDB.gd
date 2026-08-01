extends Node
## 魔力の性質と強さ。調合(AlchemyDB)と道具設計(ToolDB)の土台になる。
##
## 素材はそれぞれ「魔力の強さ」と「性質」を持つ。ほとんどの素材は性質を一つだけ持つが、
## 一部は**二つの性質**を併せ持つ。この二重の素材が緩衝材になる。
##
## 調合では素材を**順番に**釜へ入れる。隣り合う素材どうしは性質をひとつ以上
## 共有していないと魔力が弾き合う。たとえば〈熱〉と〈潤〉は直接つなげないが、
## あいだに〈熱・潤〉の両方を持つ素材をはさめばつながる。
## これが「相性を考えて、緩衝材を選ぶ」ということ。
##
## 触媒はどの性質にも馴染む万能の緩衝材だが、採集では手に入らず町で買うしかない。

const NATURES := ["heat", "moist", "swift", "solid", "bright", "erode"]

const NATURE_LABELS := {
	"heat": "熱", "moist": "潤", "swift": "疾",
	"solid": "堅", "bright": "輝", "erode": "蝕",
}

const NATURE_COLORS := {
	"heat": Color(0.88, 0.35, 0.25),
	"moist": Color(0.30, 0.58, 0.85),
	"swift": Color(0.45, 0.80, 0.60),
	"solid": Color(0.72, 0.56, 0.32),
	"bright": Color(0.95, 0.88, 0.55),
	"erode": Color(0.55, 0.45, 0.72),
}

## 表の並び: id, 性質(1つまたは2つ、触媒は全部), 魔力の強さ
const MANA_TABLE := [
	["abyss_ore", ["moist"], 4],
	["abyssal_ore", ["erode"], 4],
	["adaman_ore", ["solid"], 4],
	["aqua_shard", ["moist"], 2],
	["berry", ["moist"], 1],
	["catalyst_prima", ["heat", "moist", "swift", "solid", "bright", "erode"], 5],
	["catalyst_quick", ["heat", "moist", "swift", "solid", "bright", "erode"], 3],
	["catalyst_salt", ["heat", "moist", "swift", "solid", "bright", "erode"], 1],
	["cinderbloom", ["heat"], 4],
	["clayleaf", ["solid"], 1],
	["cloud_stone", ["swift", "heat"], 3],
	["crystal_stone", ["solid", "bright"], 3],
	["dawnthistle", ["bright", "heat"], 3],
	["deepkelp", ["moist"], 4],
	["deeproot", ["solid"], 4],
	["dewgrass", ["moist"], 1],
	["driftcotton", ["swift"], 2],
	["eclipse_herb", ["erode"], 5],
	["emberleaf", ["heat"], 1],
	["fiber", ["swift"], 1],
	["flamecap", ["heat", "bright"], 3],
	["frost_stone", ["moist", "solid"], 3],
	["gale_shard", ["swift"], 2],
	["galeleaf", ["swift", "moist"], 3],
	["gloomvine", ["erode", "moist"], 3],
	["glowmoss", ["bright"], 2],
	["golem_core", ["solid"], 5],
	["granite_shard", ["solid"], 2],
	["halo_bloom", ["bright"], 4],
	["ifrit_core", ["heat"], 5],
	["iron_ingot", ["solid"], 3],
	["iron_ore", ["solid"], 2],
	["ironbark", ["solid"], 2],
	["leviath_core", ["moist"], 5],
	["magma_stone", ["heat", "solid"], 3],
	["mirror_lily", ["moist", "bright"], 3],
	["nether_core", ["erode"], 5],
	["nightcap", ["erode"], 2],
	["onyx_shard", ["erode"], 2],
	["opal_shard", ["bright"], 2],
	["phoenix_moss", ["heat"], 5],
	["plank", ["solid"], 1],
	["prism_stone", ["bright", "swift"], 3],
	["radiant_ore", ["bright"], 4],
	["rope", ["swift"], 1],
	["ruby_shard", ["heat"], 2],
	["scorchroot", ["heat"], 2],
	["seed_wheat", ["solid"], 1],
	["seraph_core", ["bright"], 5],
	["shadeleaf", ["erode"], 1],
	["skyroot", ["swift"], 4],
	["star_lotus", ["bright"], 5],
	["stone", ["solid"], 1],
	["stone_brick", ["solid"], 2],
	["stonefungus", ["solid", "erode"], 3],
	["stormpetal", ["swift"], 5],
	["sunpetal", ["bright"], 1],
	["sunsteel_ore", ["heat"], 4],
	["sylph_core", ["swift"], 5],
	["tearvine", ["moist"], 5],
	["tempest_ore", ["swift"], 4],
	["tidefern", ["moist"], 2],
	["titan_seed", ["solid"], 5],
	["umbra_stone", ["erode", "solid"], 3],
	["voidbloom", ["erode"], 4],
	["whistlereed", ["swift"], 1],
	["wood", ["solid"], 1],
]

var _table: Dictionary = {}

func _ready() -> void:
	for row in MANA_TABLE:
		_table[row[0]] = {"natures": row[1], "mana": int(row[2])}

## 魔力を宿しているか(調合・道具設計に使えるか)
func has_mana(id: String) -> bool:
	return _table.has(id)

func get_natures(id: String) -> Array:
	return _table.get(id, {}).get("natures", [])

func get_mana(id: String) -> int:
	return int(_table.get(id, {}).get("mana", 0))

func nature_label(nature: String) -> String:
	return NATURE_LABELS.get(nature, nature)

func nature_color(nature: String) -> Color:
	return NATURE_COLORS.get(nature, Color.WHITE)

## その素材の性質を「熱・輝」のように並べた文字列
func natures_label(id: String) -> String:
	var parts: Array = []
	for n in get_natures(id):
		parts.append(nature_label(n))
	return "・".join(parts) if not parts.is_empty() else "—"

func has_nature(id: String, nature: String) -> bool:
	return get_natures(id).has(nature)

## 二つの性質を持つ素材は緩衝材として使える
func is_buffer(id: String) -> bool:
	return get_natures(id).size() >= 2

## 隣り合わせにできるか。性質をひとつでも共有していればつながる。
func resonates(a: String, b: String) -> bool:
	if a == "" or b == "":
		return true
	for n in get_natures(a):
		if get_natures(b).has(n):
			return true
	return false

## 魔力を持つ素材の id を並べて返す(図鑑用)
func mana_ids() -> Array:
	var out: Array = _table.keys()
	out.sort()
	return out
