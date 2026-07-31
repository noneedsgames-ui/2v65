extends CanvasLayer
## HUD と各メニューパネルの表示切り替え・排他制御・一時停止を統括する。

@onready var hud: Control = $HUD
@onready var inventory_panel: Control = $InventoryUI
@onready var house_panel: Control = $HouseUI
@onready var shop_panel: Control = $ShopUI
@onready var stall_panel: Control = $StallUI
@onready var crafting_panel: Control = $CraftingUI

var panels: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panels = [inventory_panel, house_panel, shop_panel, stall_panel, crafting_panel]
	for p in panels:
		p.visible = false
		p.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.process_mode = Node.PROCESS_MODE_ALWAYS

	EventBus.request_open_house.connect(func(): _open(house_panel))
	EventBus.request_open_shop.connect(func(): _open(shop_panel))
	EventBus.request_open_stall.connect(func(): _open(stall_panel))
	EventBus.request_close_menus.connect(_close_all)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_toggle(inventory_panel)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_crafting"):
		_toggle(crafting_panel)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and _any_open():
		_close_all()
		get_viewport().set_input_as_handled()

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
	get_tree().paused = true

func _close_all() -> void:
	for p in panels:
		p.visible = false
	get_tree().paused = false
