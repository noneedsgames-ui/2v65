extends Node
## 探索地の定義。町の外れから行き先を選ぶ。
##
## どの探索地も同じ Wilds.tscn を使い、この定義で見た目・採れる素材・敵の強さを変える。
## そのため地形生成の仕組みは1つで済み、区画のつなぎ方(踏破できる保証)も共通になる。

const AREAS := [
	{
		"id": "forest",
		"name": "囁きの森",
		"blurb": "町のすぐ外に広がる若い森。薬草がよく育つ。",
		"detail": "危険は少ない。風と水の薬草、そして木や石が採れる。",
		"sky": Color(0.42, 0.58, 0.6),
		"ground": Color(0.3, 0.22, 0.14),
		"surface": Color(0.26, 0.5, 0.25),
		"far": Color(0.15, 0.3, 0.21),
		"length": 4400.0,
		"enemy_hp": 60,
		"enemy_damage": 12,
		"enemy_rate": 0.14,
		# 採集ノードの出やすさ(重み)
		"nodes": {"tree": 3, "bush": 3, "fiber": 3, "rock": 1, "vein": 1},
		# この土地で採れる薬草・鉱石(採集ノードの中身を差し替える)
		"herbs": ["whistlereed", "driftcotton", "dewgrass", "tidefern", "sunpetal", "emberleaf"],
		"ores": ["granite_shard", "gale_shard", "aqua_shard"],
	},
	{
		"id": "cavern",
		"name": "響きの岩窟",
		"blurb": "地の底へ続く洞。鉱脈が幾重にも走る。",
		"detail": "けものが多く手強い。土と闇の鉱石、深い場所の薬草が採れる。",
		"sky": Color(0.16, 0.15, 0.2),
		"ground": Color(0.22, 0.19, 0.2),
		"surface": Color(0.34, 0.31, 0.34),
		"far": Color(0.12, 0.11, 0.15),
		"length": 4800.0,
		"enemy_hp": 85,
		"enemy_damage": 16,
		"enemy_rate": 0.2,
		"nodes": {"tree": 1, "bush": 1, "fiber": 1, "rock": 4, "vein": 4},
		"herbs": ["shadeleaf", "nightcap", "gloomvine", "stonefungus", "clayleaf", "ironbark"],
		"ores": ["crystal_stone", "onyx_shard", "umbra_stone", "adaman_ore", "magma_stone"],
	},
	{
		"id": "peak",
		"name": "陽昇る霊峰",
		"blurb": "雲を越えた高み。光と嵐がせめぎ合う。",
		"detail": "最も危険。光と火の希少な素材、そして核が眠る。",
		"sky": Color(0.62, 0.7, 0.85),
		"ground": Color(0.5, 0.46, 0.42),
		"surface": Color(0.86, 0.88, 0.92),
		"far": Color(0.45, 0.5, 0.62),
		"length": 5200.0,
		"enemy_hp": 110,
		"enemy_damage": 20,
		"enemy_rate": 0.24,
		"nodes": {"tree": 1, "bush": 2, "fiber": 2, "rock": 3, "vein": 4},
		"herbs": ["halo_bloom", "star_lotus", "dawnthistle", "cinderbloom", "stormpetal", "skyroot"],
		"ores": ["radiant_ore", "prism_stone", "sunsteel_ore", "tempest_ore",
			"seraph_core", "ifrit_core", "sylph_core"],
	},
]

func get_area(id: String) -> Dictionary:
	for a in AREAS:
		if a["id"] == id:
			return a
	return AREAS[0]

func area_ids() -> Array:
	var out: Array = []
	for a in AREAS:
		out.append(a["id"])
	return out
