extends Control
## 物語の会話画面。本文をページ送りし、最後に選択肢を出す。
##
## 条件を満たしていない選択肢は消さずに、押せない状態で理由つきで見せる。
## 「いま何が足りないのか」がその場でわかるほうが、探しに行く気になるので。

const LOCKED_COLOR := Color(0.62, 0.6, 0.66)

var node_id: String = ""
var pages: Array = []
var page_index: int = 0

@onready var speaker_label: Label = $Center/Window/Margin/Content/SpeakerLabel
@onready var body_label: Label = $Center/Window/Margin/Content/BodyLabel
@onready var page_label: Label = $Center/Window/Margin/Content/Footer/PageLabel
@onready var next_button: Button = $Center/Window/Margin/Content/Footer/NextButton
@onready var choices: VBoxContainer = $Center/Window/Margin/Content/Choices

func _ready() -> void:
	next_button.pressed.connect(_on_next)

## 表示する節を決める。route の節はここで実際の節まで辿る。
func set_node(id: String) -> void:
	node_id = Story.resolve(id)
	page_index = 0
	pages = []
	if node_id == "":
		return
	var data := StoryDB.get_node_data(node_id)
	pages = data.get("pages", [])

func refresh() -> void:
	if node_id == "":
		_close()
		return
	var data := StoryDB.get_node_data(node_id)
	if data.is_empty():
		_close()
		return

	var speaker := String(data.get("speaker", ""))
	speaker_label.text = speaker
	speaker_label.visible = speaker != ""
	speaker_label.add_theme_color_override("font_color", data.get("color", StoryDB.NARRATION_COLOR))

	body_label.text = String(pages[page_index]) if page_index < pages.size() else ""

	var last_page := page_index >= pages.size() - 1
	page_label.text = "" if pages.size() <= 1 else "%d / %d" % [page_index + 1, pages.size()]
	next_button.visible = not last_page

	for c in choices.get_children():
		c.queue_free()
	if last_page:
		_build_choices(data.get("choices", []))

func _build_choices(list: Array) -> void:
	if list.is_empty():
		_add_button("……", true, "", func(): _close())
		return
	for choice in list:
		var entry: Dictionary = choice
		var ok := Story.check(entry.get("requires", {}))
		var locked := String(entry.get("locked", ""))
		_add_button(String(entry["text"]), ok, locked, func(): _pick(entry))

func _add_button(text: String, enabled: bool, locked_note: String, cb: Callable) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 38)
	b.disabled = not enabled
	b.text = text if enabled or locked_note == "" else "%s ─ %s" % [text, locked_note]
	if not enabled:
		b.add_theme_color_override("font_disabled_color", LOCKED_COLOR)
	b.pressed.connect(cb)
	choices.add_child(b)

func _pick(entry: Dictionary) -> void:
	# 効果を先に適用してから移動する。次の節の条件が効果を見られるようにするため。
	Story.apply(entry.get("effects", {}))
	var next := String(entry.get("goto", ""))
	if next == "":
		_close()
		return
	set_node(next)
	if node_id == "":
		_close()
		return
	refresh()

func _on_next() -> void:
	if page_index < pages.size() - 1:
		page_index += 1
		refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# 本文の途中は決定キーでも読み進められる。選択肢が出たらキーでは進まない。
	if next_button.visible and (event.is_action_pressed("interact") or event.is_action_pressed("jump")):
		_on_next()
		get_viewport().set_input_as_handled()

func _close() -> void:
	node_id = ""
	pages = []
	page_index = 0
	EventBus.request_close_menus.emit()
