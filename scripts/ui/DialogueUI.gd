extends Control
## 村人との会話。クエストの受注・進捗確認・報告をここで行う。

var resident_id: String = ""
var idle_lines: PackedStringArray = PackedStringArray()

@onready var name_label: Label = $Center/Window/Margin/Content/NameLabel
@onready var role_label: Label = $Center/Window/Margin/Content/RoleLabel
@onready var say_label: Label = $Center/Window/Margin/Content/SayLabel
@onready var choices: VBoxContainer = $Center/Window/Margin/Content/Choices

func set_resident(id: String, lines: PackedStringArray) -> void:
	resident_id = id
	idle_lines = lines

func refresh() -> void:
	var resident := Journal.get_resident(resident_id)
	if resident.is_empty():
		return
	name_label.text = resident["name"]
	role_label.text = resident["role"]

	var quest: Dictionary = resident["quest"]
	var state := Journal.get_state(quest["id"])

	for c in choices.get_children():
		c.queue_free()

	match state:
		Journal.QuestState.UNKNOWN:
			say_label.text = "「%s」" % quest["summary"]
			_add_choice("引き受ける", func(): _accept(quest["id"]))
			_add_choice("今はやめておく", _close)
		Journal.QuestState.ACTIVE:
			say_label.text = "「%s」\n\n%s" % [_idle_line(), _progress_text(quest)]
			_add_choice("わかった", _close)
		Journal.QuestState.READY:
			say_label.text = "「おお、そろってる！ 助かるよ」\n\n%s" % _progress_text(quest)
			_add_choice("納品する", func(): _report(quest["id"]))
			_add_choice("まだ渡さない", _close)
		Journal.QuestState.DONE:
			say_label.text = "「%s」" % _idle_line()
			_add_choice("またね", _close)

func _idle_line() -> String:
	if idle_lines.is_empty():
		return "今日もいい天気だねえ。"
	return idle_lines[randi() % idle_lines.size()]

func _progress_text(quest: Dictionary) -> String:
	var parts: Array = []
	for item_id in quest["needs"].keys():
		var need := int(quest["needs"][item_id])
		parts.append("%s %d/%d" % [ItemDB.get_display_name(item_id), Inventory.get_count(item_id), need])
	return "必要: " + "、".join(parts)

func _add_choice(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 38)
	b.pressed.connect(cb)
	choices.add_child(b)

func _accept(quest_id: String) -> void:
	Journal.accept(quest_id)
	refresh()

func _report(quest_id: String) -> void:
	Journal.report(quest_id)
	refresh()

func _close() -> void:
	EventBus.request_close_menus.emit()
