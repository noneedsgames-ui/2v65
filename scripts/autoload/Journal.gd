extends Node
## クエストの進行と、出会った住民の記録(名簿)を持つシングルトン。
##
## クエストは「素材を集めて村人に届ける」納品型。受注すると進行中に入り、
## 必要数がそろうと報告できるようになる。

signal quests_changed()
signal residents_changed()

enum QuestState { UNKNOWN, ACTIVE, READY, DONE }

# 村人の定義。id -> { name, role, likes, about, quest }
var residents: Dictionary = {}
# 出会った村人の id
var met: Dictionary = {}
# クエストの状態。quest_id -> QuestState
var quest_state: Dictionary = {}

func _ready() -> void:
	_register_resident("mira", "ミラ", "パン屋",
		"木の実", "朝いちばんに窯を開ける人。焼きたてのにおいで町の朝がはじまる。",
		{
			"id": "mira_berries",
			"title": "ミラの木の実あつめ",
			"summary": "パイを焼きたいから木の実を分けてほしい、とミラに頼まれた。",
			"needs": {"berry": 8},
			"reward_gold": 70,
			"reward_items": {"berry_pie": 2},
		})
	_register_resident("gordo", "ゴルドー", "鍛冶屋",
		"鉄鉱石", "無口だが仕事は速い。奥の森の鉱脈をいつも気にしている。",
		{
			"id": "gordo_ore",
			"title": "ゴルドーの鉄集め",
			"summary": "炉に入れる鉄鉱石が足りないらしい。奥の森で掘って持ち帰ろう。",
			"needs": {"iron_ore": 6},
			"reward_gold": 140,
			"reward_items": {"iron_ingot": 2},
		})
	_register_resident("lupe", "ルーペ", "大工",
		"木の板", "町の看板をぜんぶ手がけた職人。板の反りにうるさい。",
		{
			"id": "lupe_planks",
			"title": "ルーペの板ぶそく",
			"summary": "橋の修理に木の板が要るという。作業台で加工して届けよう。",
			"needs": {"plank": 10, "rope": 2},
			"reward_gold": 160,
			"reward_items": {"stall_kit": 1},
		})
	_register_resident("nona", "ノナ", "薬草売り",
		"繊維", "草のことなら何でも知っている。よく道端にしゃがんでいる。",
		{
			"id": "nona_fiber",
			"title": "ノナの薬草づくり",
			"summary": "薬を編むのに繊維がたくさん要るそうだ。草むらを刈って集めよう。",
			"needs": {"fiber": 12},
			"reward_gold": 90,
			"reward_items": {"berry_pie": 1},
		})
	_register_resident("vespa", "ヴェスパ", "司書",
		"焦げた頁", "灯の記録を追って町に来た。荷物のほとんどが本で、椅子がいつも足りない。",
		{
			"id": "vespa_notes",
			"title": "ヴェスパの写本",
			"summary": "記録を書き写すのに澱と輝く石が要るという。灯の話のついでに集めよう。",
			"needs": {"sludge": 4, "opal_shard": 3},
			"reward_gold": 200,
			"reward_items": {"catalyst_quick": 2},
		})

func _register_resident(id: String, display_name: String, role: String,
		likes: String, about: String, quest: Dictionary) -> void:
	residents[id] = {
		"id": id,
		"name": display_name,
		"role": role,
		"likes": likes,
		"about": about,
		"quest": quest,
	}
	quest_state[quest["id"]] = QuestState.UNKNOWN

## 新規開始用。出会いとクエストの記録を消す。
func reset() -> void:
	met.clear()
	for key in quest_state.keys():
		quest_state[key] = QuestState.UNKNOWN
	residents_changed.emit()
	quests_changed.emit()

# ---- 住民 ----

func meet(resident_id: String) -> void:
	if met.has(resident_id):
		return
	met[resident_id] = true
	residents_changed.emit()
	EventBus.notify.emit("%sと知り合った(名簿に追加)" % get_resident_name(resident_id))

func has_met(resident_id: String) -> bool:
	return met.has(resident_id)

func get_resident(resident_id: String) -> Dictionary:
	return residents.get(resident_id, {})

func get_resident_name(resident_id: String) -> String:
	return get_resident(resident_id).get("name", resident_id)

func met_resident_ids() -> Array:
	var ids: Array = []
	for id in residents.keys():
		if met.has(id):
			ids.append(id)
	return ids

# ---- クエスト ----

func get_quest_of(resident_id: String) -> Dictionary:
	return get_resident(resident_id).get("quest", {})

func get_state(quest_id: String) -> int:
	return quest_state.get(quest_id, QuestState.UNKNOWN)

func accept(quest_id: String) -> void:
	if get_state(quest_id) != QuestState.UNKNOWN:
		return
	quest_state[quest_id] = QuestState.ACTIVE
	quests_changed.emit()
	EventBus.notify.emit("クエストを受けた: %s" % get_quest(quest_id).get("title", quest_id))
	EventBus.companion_say.emit("メモしておいたよ。持ち物のメモ帳から見られる。")
	refresh_progress()

func get_quest(quest_id: String) -> Dictionary:
	for r in residents.values():
		var q: Dictionary = r.get("quest", {})
		if q.get("id", "") == quest_id:
			return q
	return {}

## 必要数がそろっているクエストを READY に、足りなくなったら ACTIVE に戻す。
func refresh_progress() -> void:
	var changed := false
	for r in residents.values():
		var q: Dictionary = r.get("quest", {})
		var qid: String = q.get("id", "")
		var state := get_state(qid)
		if state != QuestState.ACTIVE and state != QuestState.READY:
			continue
		var complete := true
		for item_id in q["needs"].keys():
			if Inventory.get_count(item_id) < int(q["needs"][item_id]):
				complete = false
				break
		var wanted := QuestState.READY if complete else QuestState.ACTIVE
		if wanted != state:
			quest_state[qid] = wanted
			changed = true
			if wanted == QuestState.READY:
				EventBus.notify.emit("「%s」の品がそろった！" % q.get("title", qid))
	if changed:
		quests_changed.emit()

func can_report(quest_id: String) -> bool:
	return get_state(quest_id) == QuestState.READY

## 納品して報酬を受け取る。
func report(quest_id: String) -> bool:
	if not can_report(quest_id):
		return false
	var q := get_quest(quest_id)
	for item_id in q["needs"].keys():
		if not Inventory.remove_item(item_id, int(q["needs"][item_id])):
			return false
	quest_state[quest_id] = QuestState.DONE

	var gold := int(q.get("reward_gold", 0))
	if gold > 0:
		Inventory.add_gold(gold)
	var rewards: Dictionary = q.get("reward_items", {})
	for item_id in rewards.keys():
		Inventory.add_item(item_id, int(rewards[item_id]))

	quests_changed.emit()
	EventBus.notify.emit("クエスト達成: %s (+%dG)" % [q.get("title", quest_id), gold])
	EventBus.companion_say.emit("やったね！ 頼りにされてるじゃない。")
	return true

func active_quests() -> Array:
	var out: Array = []
	for r in residents.values():
		var q: Dictionary = r.get("quest", {})
		var st := get_state(q.get("id", ""))
		if st == QuestState.ACTIVE or st == QuestState.READY:
			out.append(q)
	return out

func done_quests() -> Array:
	var out: Array = []
	for r in residents.values():
		var q: Dictionary = r.get("quest", {})
		if get_state(q.get("id", "")) == QuestState.DONE:
			out.append(q)
	return out

# ---- セーブ ----

func to_save_data() -> Dictionary:
	return {"met": met.keys(), "quests": quest_state.duplicate()}

func load_save_data(data: Dictionary) -> void:
	met.clear()
	for id in data.get("met", []):
		met[str(id)] = true
	var saved: Dictionary = data.get("quests", {})
	for qid in saved.keys():
		quest_state[str(qid)] = int(saved[qid])
	residents_changed.emit()
	quests_changed.emit()
	refresh_progress()
