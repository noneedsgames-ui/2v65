extends Control
## メモ帳。受けたクエストの進捗と、出会った住民の情報を見る。

const TAB_QUEST := "quest"
const TAB_PEOPLE := "people"

var current_tab: String = TAB_QUEST

@onready var quest_tab: Button = $Center/Window/Margin/Content/Tabs/QuestTab
@onready var people_tab: Button = $Center/Window/Margin/Content/Tabs/PeopleTab
@onready var list: VBoxContainer = $Center/Window/Margin/Content/Scroll/List

func _ready() -> void:
	$Center/Window/Margin/Content/CloseButton.pressed.connect(_on_close)
	quest_tab.pressed.connect(func(): _set_tab(TAB_QUEST))
	people_tab.pressed.connect(func(): _set_tab(TAB_PEOPLE))
	Journal.quests_changed.connect(refresh)
	Journal.residents_changed.connect(refresh)

func _on_close() -> void:
	EventBus.request_close_menus.emit()

func _set_tab(tab: String) -> void:
	current_tab = tab
	quest_tab.button_pressed = tab == TAB_QUEST
	people_tab.button_pressed = tab == TAB_PEOPLE
	refresh()

func refresh() -> void:
	for c in list.get_children():
		c.queue_free()
	if current_tab == TAB_QUEST:
		_build_quests()
	else:
		_build_people()

func _add_heading(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	list.add_child(l)

func _add_body(text: String, color: Color = Color(1, 1, 1)) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(520, 0)
	l.add_theme_color_override("font_color", color)
	list.add_child(l)

func _add_separator() -> void:
	list.add_child(HSeparator.new())

func _build_quests() -> void:
	var active := Journal.active_quests()
	var done := Journal.done_quests()
	if active.is_empty() and done.is_empty():
		_add_body("まだ何も頼まれていない。町の人に話しかけてみよう。")
		return

	if not active.is_empty():
		_add_heading("進行中")
		for q in active:
			var ready_mark := "  【達成! 報告できる】" if Journal.get_state(q["id"]) == Journal.QuestState.READY else ""
			_add_body("● %s%s" % [q["title"], ready_mark],
				Color(0.7, 1, 0.7) if ready_mark != "" else Color(1, 1, 1))
			_add_body("   %s" % q["summary"], Color(0.82, 0.82, 0.86))
			var parts: Array = []
			for item_id in q["needs"].keys():
				var need := int(q["needs"][item_id])
				var have := Inventory.get_count(item_id)
				parts.append("%s %d/%d" % [ItemDB.get_display_name(item_id), have, need])
			_add_body("   必要: " + "、".join(parts), Color(0.75, 0.85, 1))
			_add_body("   報酬: %dG" % int(q.get("reward_gold", 0)), Color(1, 0.9, 0.5))
			_add_separator()

	if not done.is_empty():
		_add_heading("達成済み")
		for q in done:
			_add_body("✓ %s" % q["title"], Color(0.65, 0.75, 0.65))

func _build_people() -> void:
	var ids := Journal.met_resident_ids()
	if ids.is_empty():
		_add_body("まだ誰とも知り合っていない。町を歩いて話しかけてみよう。")
		return
	for id in ids:
		var r := Journal.get_resident(id)
		_add_heading("%s(%s)" % [r["name"], r["role"]])
		_add_body("   %s" % r["about"], Color(0.85, 0.85, 0.9))
		_add_body("   好きなもの: %s" % r["likes"], Color(1, 0.8, 0.85))
		var q: Dictionary = r["quest"]
		var state_text := ""
		match Journal.get_state(q["id"]):
			Journal.QuestState.UNKNOWN: state_text = "まだ頼まれごとはない"
			Journal.QuestState.ACTIVE: state_text = "「%s」を進行中" % q["title"]
			Journal.QuestState.READY: state_text = "「%s」を報告できる" % q["title"]
			Journal.QuestState.DONE: state_text = "「%s」を達成した" % q["title"]
		_add_body("   %s" % state_text, Color(0.75, 0.85, 1))
		_add_separator()
