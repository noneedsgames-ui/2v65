extends Control

const BUYABLE_IDS := ["axe", "pickaxe", "basket", "stall_kit", "seed_wheat", "berry_pie"]

@onready var buy_list: VBoxContainer = $Center/Window/Margin/Content/Columns/BuyColumn/Scroll/List
@onready var sell_list: VBoxContainer = $Center/Window/Margin/Content/Columns/SellColumn/Scroll/List
@onready var gold_label: Label = $Center/Window/Margin/Content/GoldLabel

func _ready() -> void:
	$Center/Window/Margin/Content/CloseButton.pressed.connect(_on_close)
	Inventory.changed.connect(refresh)
	Inventory.gold_changed.connect(func(_g): refresh())

func refresh() -> void:
	gold_label.text = "所持金: %dG" % Inventory.gold

	for c in buy_list.get_children():
		c.queue_free()
	for id in BUYABLE_IDS:
		var item: Dictionary = ItemDB.get_item(id)
		var price: int = item.get("buy_price", 0)
		var row := UIRowFactory.make_item_row(
			item.get("color", Color.WHITE), "%s (%dG)" % [item.get("name", id), price],
			"購入", func(): _buy(id, price), Inventory.gold < price
		)
		buy_list.add_child(row)

	for c in sell_list.get_children():
		c.queue_free()
	for slot in Inventory.slots:
		if slot == null:
			continue
		var item: Dictionary = ItemDB.get_item(slot["id"])
		var id: String = slot["id"]
		var price: int = item.get("sell_price", 0)
		var row := UIRowFactory.make_item_row(
			item.get("color", Color.WHITE), "%s x%d (%dG)" % [item.get("name", id), slot["count"], price],
			"売却", func(): _sell(id, price)
		)
		sell_list.add_child(row)
	if sell_list.get_child_count() == 0:
		var l := Label.new()
		l.text = "売れるものがありません"
		sell_list.add_child(l)

func _buy(id: String, price: int) -> void:
	if Inventory.spend_gold(price):
		Inventory.add_item(id, 1)
		EventBus.notify.emit("%sを購入した" % ItemDB.get_display_name(id))
	else:
		EventBus.notify.emit("お金が足りません")
	refresh()

func _sell(id: String, price: int) -> void:
	if Inventory.remove_item(id, 1):
		Inventory.add_gold(price)
		EventBus.notify.emit("%sを売却した (+%dG)" % [ItemDB.get_display_name(id), price])
	refresh()

func _on_close() -> void:
	EventBus.request_close_menus.emit()
