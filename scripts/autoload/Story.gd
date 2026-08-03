extends Node
## 物語の進行状態。章・旗(フラグ)・見た出来事を持ち、条件の判定と効果の適用を受け持つ。
##
## 台本は StoryDB にあり、こちらはそれを解釈するだけ。
## 判定に使う材料は持ち物・魔力・調合の発見数・道具の完成など、
## ゲームのほかの仕組みから素直に引いてくる。

signal story_changed()

## 0 はまだ始まっていない。最終章は StoryDB.CHAPTERS の最後。
var chapter: int = 0
## 立てた旗。真偽値のほか、数(faith)や文字列(ending)も入る。
var flags: Dictionary = {}
## once の出来事のうち、もう起きたもの
var seen_events: Dictionary = {}
## 一度きりの世間話のうち、もう見たもの
var seen_talks: Dictionary = {}

func reset() -> void:
	chapter = 0
	flags.clear()
	seen_events.clear()
	seen_talks.clear()
	story_changed.emit()

# ---- 旗 ----

func get_flag(name: String):
	return flags.get(name, null)

func has_flag(name: String) -> bool:
	var v = flags.get(name, null)
	if v == null:
		return false
	if typeof(v) == TYPE_BOOL:
		return v
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return v != 0
	if typeof(v) == TYPE_STRING:
		return v != ""
	return true

func count_of(name: String) -> int:
	var v = flags.get(name, 0)
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return int(v)
	return 0

func is_finished() -> bool:
	return chapter >= 7

# ---- 持ち物から見る魔力 ----

## その性質を持つ素材を何種類持っているか。
func nature_kinds(nature: String) -> int:
	var n := 0
	for id in ManaDB.mana_ids():
		if ManaDB.has_nature(id, nature) and Inventory.get_count(id) > 0:
			n += 1
	return n

## その性質を持つ素材ぜんぶの魔力の合計。
func nature_mana(nature: String) -> int:
	var total := 0
	for id in ManaDB.mana_ids():
		if not ManaDB.has_nature(id, nature):
			continue
		total += ManaDB.get_mana(id) * Inventory.get_count(id)
	return total

# ---- 条件 ----

## 条件をすべて満たしていれば true。空の条件は常に true。
func check(requires: Dictionary) -> bool:
	if requires.is_empty():
		return true

	if requires.has("chapter_min") and chapter < int(requires["chapter_min"]):
		return false
	if requires.has("chapter_max") and chapter > int(requires["chapter_max"]):
		return false
	if requires.has("flag") and not has_flag(String(requires["flag"])):
		return false
	if requires.has("not_flag") and has_flag(String(requires["not_flag"])):
		return false

	if requires.has("flag_is"):
		var wanted: Dictionary = requires["flag_is"]
		for key in wanted.keys():
			if flags.get(key, null) != wanted[key]:
				return false

	if requires.has("flag_at_least"):
		var mins: Dictionary = requires["flag_at_least"]
		for key in mins.keys():
			if count_of(String(key)) < int(mins[key]):
				return false

	if requires.has("items"):
		var items: Dictionary = requires["items"]
		for id in items.keys():
			if Inventory.get_count(String(id)) < int(items[id]):
				return false

	if requires.has("natures"):
		var spec: Dictionary = requires["natures"]
		if nature_kinds(String(spec["nature"])) < int(spec["kinds"]):
			return false

	if requires.has("mana"):
		var spec2: Dictionary = requires["mana"]
		if nature_mana(String(spec2["nature"])) < int(spec2["total"]):
			return false

	if requires.has("brews_at_least") and AlchemyDB.discovered_count() < int(requires["brews_at_least"]):
		return false
	if requires.has("tool_built") and not ToolDB.has_built(String(requires["tool_built"])):
		return false
	if requires.has("area") and GameState.selected_area != String(requires["area"]):
		return false

	return true

# ---- 効果 ----

func apply(effects: Dictionary) -> void:
	if effects.is_empty():
		return

	if effects.has("set"):
		var sets: Dictionary = effects["set"]
		for key in sets.keys():
			flags[String(key)] = sets[key]

	if effects.has("add"):
		var adds: Dictionary = effects["add"]
		for key in adds.keys():
			flags[String(key)] = count_of(String(key)) + int(adds[key])

	if effects.has("take"):
		var takes: Dictionary = effects["take"]
		for id in takes.keys():
			Inventory.remove_item(String(id), int(takes[id]))

	if effects.has("take_natures"):
		var spec: Dictionary = effects["take_natures"]
		_take_kinds(String(spec["nature"]), int(spec["kinds"]))

	if effects.has("take_mana"):
		var spec2: Dictionary = effects["take_mana"]
		_take_mana(String(spec2["nature"]), int(spec2["total"]))

	if effects.has("give"):
		var gives: Dictionary = effects["give"]
		for id in gives.keys():
			Inventory.add_item(String(id), int(gives[id]))

	if effects.has("gold"):
		Inventory.add_gold(int(effects["gold"]))

	if effects.has("chapter"):
		var next_chapter := int(effects["chapter"])
		if next_chapter > chapter:
			chapter = next_chapter
			var title := StoryDB.chapter_title(chapter)
			if title != "":
				EventBus.notify.emit("物語がすすんだ: %s" % title)

	if effects.has("notify"):
		EventBus.notify.emit(String(effects["notify"]))
	if effects.has("say"):
		EventBus.companion_say.emit(String(effects["say"]))

	story_changed.emit()

## その性質の素材を、種類ちがいで指定数だけ1個ずつ渡す。安いものから出す。
func _take_kinds(nature: String, kinds: int) -> void:
	var owned: Array = []
	for id in ManaDB.mana_ids():
		if ManaDB.has_nature(id, nature) and Inventory.get_count(id) > 0:
			owned.append(id)
	owned.sort_custom(func(a, b): return ItemDB.get_sell_price(a) < ItemDB.get_sell_price(b))
	var taken := 0
	for id in owned:
		if taken >= kinds:
			break
		if Inventory.remove_item(String(id), 1):
			taken += 1

## その性質の素材を、魔力の合計が指定量に届くまで渡す。
## 安いものから出す(触媒のような高い緩衝材を勝手に持っていかれると惜しいので)。
func _take_mana(nature: String, total: int) -> void:
	var owned: Array = []
	for id in ManaDB.mana_ids():
		if ManaDB.has_nature(id, nature) and Inventory.get_count(id) > 0:
			owned.append(id)
	owned.sort_custom(func(a, b): return ItemDB.get_sell_price(a) < ItemDB.get_sell_price(b))
	var paid := 0
	for id in owned:
		while paid < total and Inventory.get_count(String(id)) > 0:
			if not Inventory.remove_item(String(id), 1):
				break
			paid += ManaDB.get_mana(String(id))
		if paid >= total:
			return

# ---- 出来事 ----

## その場所の出来事が起こせるか。
func can_fire(event_id: String) -> bool:
	var ev := StoryDB.get_event(event_id)
	if ev.is_empty():
		return false
	if bool(ev.get("once", false)) and seen_events.has(event_id):
		return false
	return check(ev.get("requires", {}))

## 出来事を起こす。once のものはここで記録する。
func fire(event_id: String) -> void:
	if not can_fire(event_id):
		return
	var ev := StoryDB.get_event(event_id)
	if bool(ev.get("once", false)):
		seen_events[event_id] = true
	EventBus.request_open_story.emit(String(ev["node"]))

# ---- 村人 ----

## その村人にいま話すべき物語の節。無ければ空文字(従来の依頼画面になる)。
## 一度きりの世間話を見たあとは飛ばすので、依頼画面にちゃんと戻れる。
func node_for_resident(resident_id: String) -> String:
	for entry in StoryDB.resident_entries(resident_id):
		if not check(entry.get("requires", {})):
			continue
		var nid := String(entry["node"])
		if bool(entry.get("once", false)) and seen_talks.has(nid):
			continue
		return nid
	return ""

## 話しかけて開いた節を控えておく(once の節をもう出さないため)。
func mark_talk_seen(node_id: String) -> void:
	if node_id == "" or seen_talks.has(node_id):
		return
	seen_talks[node_id] = true

## 章が来ていない村人は町に出さない。
func resident_available(resident_id: String, from_chapter: int) -> bool:
	return from_chapter <= 0 or chapter >= from_chapter

## route を辿って、実際に表示する節までたどり着く。
## 分岐の合流点を書きやすくするための仕組みで、輪を作らないよう回数を制限する。
func resolve(node_id: String) -> String:
	var id := node_id
	for _i in range(8):
		var data := StoryDB.get_node_data(id)
		if data.is_empty() or not data.has("route"):
			return id
		var next := ""
		for branch in data["route"]:
			if check(branch.get("requires", {})):
				next = String(branch.get("goto", ""))
				break
		if next == "" or next == id:
			return ""
		id = next
	push_warning("Story.resolve: route がめぐっている: %s" % node_id)
	return ""

# ---- セーブ ----

func to_save_data() -> Dictionary:
	return {"chapter": chapter, "flags": flags.duplicate(),
		"seen": seen_events.keys(), "talks": seen_talks.keys()}

func load_save_data(data: Dictionary) -> void:
	flags.clear()
	seen_events.clear()
	seen_talks.clear()
	chapter = int(data.get("chapter", 0))
	var saved: Dictionary = data.get("flags", {})
	for key in saved.keys():
		var v = saved[key]
		# JSON から戻すと数が float になるので、整数に見えるものは int に直す
		if typeof(v) == TYPE_FLOAT and v == floor(v):
			v = int(v)
		flags[String(key)] = v
	for id in data.get("seen", []):
		seen_events[String(id)] = true
	for id in data.get("talks", []):
		seen_talks[String(id)] = true
	story_changed.emit()
