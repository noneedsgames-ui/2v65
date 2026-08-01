extends CanvasLayer
## HUD・ホットバーと各メニューパネルの表示切り替え・排他制御・一時停止を統括する。

@onready var hud: Control = $HUD
@onready var hotbar: Control = $Hotbar
@onready var bubble: Control = $CompanionBubble
@onready var inventory_panel: Control = $InventoryUI
@onready var house_panel: Control = $HouseUI
@onready var shop_panel = $ShopUI  # set_shop() を呼ぶため型は付けない
@onready var stall_panel: Control = $StallUI
@onready var crafting_panel: Control = $CraftingUI
@onready var negotiation_panel = $NegotiationUI  # set_request() を呼ぶため型は付けない
@onready var dialogue_panel = $DialogueUI        # set_resident() を呼ぶため型は付けない
@onready var journal_panel: Control = $JournalUI

var panels: Array = []
## 店番中はホットバーを隠し、F(use_item)を露店の呼び込みに譲る
var tending: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panels = [inventory_panel, house_panel, shop_panel, stall_panel, crafting_panel,
		negotiation_panel, dialogue_panel, journal_panel]
	for p in panels:
		p.visible = false
		p.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	bubble.process_mode = Node.PROCESS_MODE_ALWAYS
	# ホットバーはメニューを開いている間は反応させない
	hotbar.process_mode = Node.PROCESS_MODE_PAUSABLE

	EventBus.request_open_chest.connect(func(): _open(house_panel))
	EventBus.request_open_shop.connect(_on_request_open_shop)
	EventBus.request_open_stall.connect(func(): _open(stall_panel))
	EventBus.request_open_crafting.connect(func(): _open(crafting_panel))
	EventBus.request_close_menus.connect(_close_all)
	EventBus.request_open_negotiation.connect(_on_open_negotiation)
	EventBus.request_open_dialogue.connect(_on_open_dialogue)
	EventBus.request_open_journal.connect(func(): _open(journal_panel))
	EventBus.tending_started.connect(_on_tending_started)
	EventBus.tending_ended.connect(_on_tending_ended)

func _on_open_negotiation(request: Dictionary) -> void:
	negotiation_panel.set_request(request)
	_open(negotiation_panel)

func _on_open_dialogue(resident_id: String, idle_lines: PackedStringArray) -> void:
	dialogue_panel.set_resident(resident_id, idle_lines)
	_open(dialogue_panel)

func _on_tending_started() -> void:
	tending = true
	hotbar.visible = false
	hotbar.set_process_unhandled_input(false)

func _on_tending_ended() -> void:
	tending = false
	hotbar.visible = true
	hotbar.set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_toggle(inventory_panel)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_crafting"):
		_toggle(crafting_panel)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_journal"):
		_toggle(journal_panel)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and _any_open():
		_close_all()
		get_viewport().set_input_as_handled()

func _on_request_open_shop(shop_name: String, stock: PackedStringArray) -> void:
	shop_panel.set_shop(shop_name, stock)
	_open(shop_panel)

func _toggle(panel: Control) -> void:
	if panel.visible:
		_close_all()
	else:
		_open(panel)

func _any_open() -> bool:
	for p in panels:
		if p.visible:
			return true
	return false

func _open(panel: Control) -> void:
	for p in panels:
		p.visible = (p == panel)
	if panel.has_method("refresh"):
		panel.refresh()
	hotbar.visible = false
	get_tree().paused = true

func _close_all() -> void:
	for p in panels:
		p.visible = false
	# 店番中にメニューを開閉してもホットバーを復活させない
	hotbar.visible = not tending
	get_tree().paused = false
