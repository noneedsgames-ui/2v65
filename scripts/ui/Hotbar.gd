extends Control
## 画面下に常時表示するホットバー。インベントリ先頭 HOTBAR_SIZE 個を映す。
## 数字キー 1-8 / Q / R で選択し、F または升目クリックで使用する。

const ITEM_SLOT_SCENE := preload("res://scenes/ui/ItemSlot.tscn")

var _slots: Array = []

@onready var row: HBoxContainer = $Panel/Margin/Row

func _ready() -> void:
	for i in range(Inventory.HOTBAR_SIZE):
		var slot = ITEM_SLOT_SCENE.instantiate()
		slot.index = i
		row.add_child(slot)
		slot.slot_pressed.connect(_on_slot_pressed)
		_slots.append(slot)

	Inventory.changed.connect(refresh)
	Inventory.hotbar_selection_changed.connect(func(_i): refresh())
	refresh()

func _unhandled_input(event: InputEvent) -> void:
	for i in range(Inventory.HOTBAR_SIZE):
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			Inventory.select_hotbar(i)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("hotbar_prev"):
		Inventory.cycle_hotbar(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hotbar_next"):
		Inventory.cycle_hotbar(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use_item"):
		Inventory.use_selected()
		get_viewport().set_input_as_handled()

## 升目を直接クリックした場合は、選択してからそのまま使う。
func _on_slot_pressed(index: int) -> void:
	if index == Inventory.selected_hotbar:
		Inventory.use_selected()
	else:
		Inventory.select_hotbar(index)

func refresh() -> void:
	for i in range(_slots.size()):
		var slot = Inventory.get_slot(i)
		if slot == null:
			_slots[i].set_item("", 0)
		else:
			_slots[i].set_item(slot["id"], slot["count"])
		_slots[i].set_selected(i == Inventory.selected_hotbar)
