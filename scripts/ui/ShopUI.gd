extends Control
## 店の売買画面。品揃えは開いた店(Shop.gd)から受け取る。

var shop_name: String = "お店"
var stock: PackedStringArray = PackedStringArray()

@onready var title_label: Label = $Center/Window/Margin/Content/TitleLabel
@onready var buy_list: VBoxContainer = $Center/Window/Margin/Content/Columns/BuyColumn/Scroll/List
@onready var sell_list: VBoxContainer = $Center/Window/Margin/Content/Columns/SellColumn/Scroll/List
@onready var gold_label: Label = $Center/Window/Margin/Content/GoldLabel

func _ready() -> void:
	$Center/Window/Margin/Content/CloseButton.pressed.connect(_on_close)
	Inventory.changed.connect(refresh)
	Inventory.gold_changed.connect(func(_g): refresh())

func set_shop(new_name: String, new_stock: PackedStringArray) -> void:
	shop_name = new_name
	stock = new_stock

func refresh() -> void:
	title_label.text = shop_name
	gold_label.text = "所持金: %dG" % Inventory.gold

	for c in buy_list.get_children():
		c.queue_free()
	for id in stock:
		var price: int = ItemDB.get_buy_price(id)
		var row := UIRowFactory.make_item_row(
			ItemDB.get_color(id), "%s (%dG)" % [ItemDB.get_display_name(id), price],
			"購入", func(): _buy(id, price), Inventory.gold < price
		)
		buy_list.add_child(row)
	if buy_list.get_child_count() == 0:
		var l := Label.new()
		l.text = "品切れです"
		buy_list.add_child(l)

	for c in sell_list.get_children():
		c.queue_free()
	for slot in Inventory.slots:
		if slot == null:
			continue
		var id: String = slot["id"]
		var price: int = ItemDB.get_sell_price(id)
		var row := UIRowFactory.make_item_row(
			ItemDB.get_color(id), "%s x%d (%dG)" % [ItemDB.get_display_name(id), slot["count"], price],
			"売却", func(): _sell(id, price)
		)
		sell_list.add_child(row)
	if sell_list.get_child_count() == 0:
		var l := Label.new()
		l.text = "売れるものがありません"
		sell_list.add_child(l)

func _buy(id: String, price: int) -> void:
	if Inventory.is_full_for(id):
		EventBus.notify.emit("持ち物がいっぱいです")
		return
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
