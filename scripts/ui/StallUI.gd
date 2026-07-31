extends Control

@onready var inv_list: VBoxContainer = $Center/Window/Margin/Content/Columns/InvColumn/Scroll/List
@onready var stall_list: VBoxContainer = $Center/Window/Margin/Content/Columns/StallColumn/Scroll/List
@onready var log_label: Label = $Center/Window/Margin/Content/LogLabel

func _ready() -> void:
	$Center/Window/Margin/Content/CloseButton.pressed.connect(_on_close)
	Inventory.changed.connect(refresh)

func refresh() -> void:
	for c in inv_list.get_children():
		c.queue_free()
	for slot in Inventory.slots:
		if slot == null:
			continue
		var item: Dictionary = ItemDB.get_item(slot["id"])
		var id: String = slot["id"]
		var price: int = max(1, int(item.get("sell_price", 1)) * 2)
		var row := UIRowFactory.make_item_row(
			item.get("color", Color.WHITE), "%s x%d" % [item.get("name", id), slot["count"]],
			"出品(%dG)" % price, func(): _list_item(id, price)
		)
		inv_list.add_child(row)
	if inv_list.get_child_count() == 0:
		var l := Label.new()
		l.text = "出品できる持ち物がありません"
		inv_list.add_child(l)

	for c in stall_list.get_children():
		c.queue_free()
	for i in range(GameState.stall_items.size()):
		var entry: Dictionary = GameState.stall_items[i]
		var item: Dictionary = ItemDB.get_item(entry["id"])
		var idx := i
		var row := UIRowFactory.make_item_row(
			item.get("color", Color.WHITE),
			"%s x%d (%dG)" % [item.get("name", entry["id"]), entry["count"], entry["price"]],
			"回収", func(): _withdraw(idx)
		)
		stall_list.add_child(row)
	if stall_list.get_child_count() == 0:
		var l2 := Label.new()
		l2.text = "陳列中のアイテムはありません"
		stall_list.add_child(l2)

	if GameState.stall_earnings_log.is_empty():
		log_label.text = "売上ログ: まだ売上はありません"
	else:
		var start_idx: int = max(0, GameState.stall_earnings_log.size() - 6)
		var lines: Array = GameState.stall_earnings_log.slice(start_idx)
		log_label.text = "売上ログ:\n" + "\n".join(lines)

func _list_item(id: String, price: int) -> void:
	if Inventory.remove_item(id, 1):
		GameState.stall_add_item(id, 1, price)
		EventBus.notify.emit("%sを露店に並べた" % ItemDB.get_display_name(id))
	refresh()

func _withdraw(index: int) -> void:
	GameState.stall_withdraw(index)
	refresh()

func _on_close() -> void:
	EventBus.request_close_menus.emit()
