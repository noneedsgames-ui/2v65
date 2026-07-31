extends Control
## 持ち物と装備をタブで切り替えて表示する。
## 升目にはアイテム画像だけを並べ、選択したアイテムの説明を右側に出す。

const ITEM_SLOT_SCENE := preload("res://scenes/ui/ItemSlot.tscn")
const GRID_COLUMNS := 5

const TAB_BAG := "bag"
const TAB_EQUIP := "equip"

var current_tab: String = TAB_BAG
## 選択中のもの。bag タブでは slots の添字、equip タブでは Equipment のスロット名。
var selected_bag_index: int = -1
var selected_equip_slot: String = ""

var _bag_slots: Array = []    # ItemSlot(bag)
var _equip_slots: Dictionary = {}  # slot 名 -> ItemSlot

@onready var bag_tab_button: Button = $Center/Window/Margin/Content/Tabs/BagTab
@onready var equip_tab_button: Button = $Center/Window/Margin/Content/Tabs/EquipTab
@onready var bag_grid: GridContainer = $Center/Window/Margin/Content/Body/Left/BagGrid
@onready var equip_box: VBoxContainer = $Center/Window/Margin/Content/Body/Left/EquipBox
@onready var gold_label: Label = $Center/Window/Margin/Content/GoldLabel

@onready var detail_name: Label = $Center/Window/Margin/Content/Body/Detail/Margin/VBox/NameLabel
@onready var detail_type: Label = $Center/Window/Margin/Content/Body/Detail/Margin/VBox/TypeLabel
@onready var detail_desc: Label = $Center/Window/Margin/Content/Body/Detail/Margin/VBox/DescLabel
@onready var detail_price: Label = $Center/Window/Margin/Content/Body/Detail/Margin/VBox/PriceLabel
@onready var detail_action: Button = $Center/Window/Margin/Content/Body/Detail/Margin/VBox/ActionButton

func _ready() -> void:
	$Center/Window/Margin/Content/CloseButton.pressed.connect(_on_close)
	bag_tab_button.pressed.connect(func(): _set_tab(TAB_BAG))
	equip_tab_button.pressed.connect(func(): _set_tab(TAB_EQUIP))
	detail_action.pressed.connect(_on_action_pressed)

	Inventory.changed.connect(refresh)
	Inventory.gold_changed.connect(func(_g): refresh())
	Equipment.changed.connect(refresh)

	_build_bag_grid()
	_build_equip_slots()
	_set_tab(TAB_BAG)

func _build_bag_grid() -> void:
	bag_grid.columns = GRID_COLUMNS
	for i in range(Inventory.MAX_SLOTS):
		# instantiate() の戻りは Node 型なので、ItemSlot 固有のメンバーに触れるよう型を付けない
		var slot = ITEM_SLOT_SCENE.instantiate()
		slot.index = i
		bag_grid.add_child(slot)
		slot.slot_pressed.connect(_on_bag_slot_pressed)
		_bag_slots.append(slot)

func _build_equip_slots() -> void:
	for slot_name in Equipment.SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var label := Label.new()
		label.text = Equipment.SLOT_LABELS.get(slot_name, slot_name)
		label.custom_minimum_size = Vector2(110, 0)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)

		var slot = ITEM_SLOT_SCENE.instantiate()
		row.add_child(slot)
		# ラムダで slot_name を値キャプチャする
		slot.slot_pressed.connect(func(_i): _on_equip_slot_pressed(slot_name))
		_equip_slots[slot_name] = slot

		equip_box.add_child(row)

func _set_tab(tab: String) -> void:
	current_tab = tab
	bag_grid.visible = tab == TAB_BAG
	equip_box.visible = tab == TAB_EQUIP
	bag_tab_button.button_pressed = tab == TAB_BAG
	equip_tab_button.button_pressed = tab == TAB_EQUIP
	refresh()

func _on_bag_slot_pressed(index: int) -> void:
	selected_bag_index = index
	refresh()

func _on_equip_slot_pressed(slot_name: String) -> void:
	selected_equip_slot = slot_name
	refresh()

func refresh() -> void:
	gold_label.text = "所持金: %dG" % Inventory.gold

	for i in range(_bag_slots.size()):
		var slot = Inventory.get_slot(i)
		if slot == null:
			_bag_slots[i].set_item("", 0)
		else:
			_bag_slots[i].set_item(slot["id"], slot["count"])
		_bag_slots[i].set_selected(current_tab == TAB_BAG and i == selected_bag_index)

	for slot_name in Equipment.SLOTS:
		var equipped: String = Equipment.get_equipped(slot_name)
		_equip_slots[slot_name].set_item(equipped, 1)
		_equip_slots[slot_name].set_selected(current_tab == TAB_EQUIP and slot_name == selected_equip_slot)

	_refresh_detail()

func _get_selected_id() -> String:
	if current_tab == TAB_BAG:
		var slot = Inventory.get_slot(selected_bag_index)
		return slot["id"] if slot != null else ""
	return Equipment.get_equipped(selected_equip_slot)

func _refresh_detail() -> void:
	var id := _get_selected_id()
	if id == "":
		detail_name.text = "アイテムを選択してください"
		detail_type.text = ""
		detail_desc.text = ""
		detail_price.text = ""
		detail_action.visible = false
		return

	detail_name.text = ItemDB.get_display_name(id)
	detail_type.text = ItemDB.get_type_label(id)
	detail_desc.text = ItemDB.get_description(id)
	detail_price.text = "売値 %dG / 買値 %dG" % [ItemDB.get_sell_price(id), ItemDB.get_buy_price(id)]

	if current_tab == TAB_EQUIP:
		detail_action.text = "外す"
		detail_action.visible = true
	elif ItemDB.get_type(id) == ItemDB.ItemType.FOOD:
		detail_action.text = "食べる"
		detail_action.visible = true
	elif ItemDB.is_equippable(id):
		detail_action.text = "装備する"
		detail_action.visible = true
	else:
		detail_action.visible = false

func _on_action_pressed() -> void:
	var id := _get_selected_id()
	if id == "":
		return
	if current_tab == TAB_EQUIP:
		Equipment.unequip(selected_equip_slot)
	elif ItemDB.get_type(id) == ItemDB.ItemType.FOOD:
		if Inventory.remove_item(id, 1):
			EventBus.notify.emit("%sを食べた。おいしい!" % ItemDB.get_display_name(id))
	elif ItemDB.is_equippable(id):
		Equipment.equip(id)
	refresh()

func _on_close() -> void:
	EventBus.request_close_menus.emit()
