extends Control

@onready var player_list: VBoxContainer = $Center/Window/Margin/Content/Columns/PlayerColumn/Scroll/List
@onready var chest_list: VBoxContainer = $Center/Window/Margin/Content/Columns/ChestColumn/Scroll/List

func _ready() -> void:
	$Center/Window/Margin/Content/CloseButton.pressed.connect(_on_close)
	Inventory.changed.connect(refresh)

func refresh() -> void:
	for c in player_list.get_children():
		c.queue_free()
	for slot in Inventory.slots:
		if slot == null:
			continue
		var item: Dictionary = ItemDB.get_item(slot["id"])
		var id: String = slot["id"]
		var row := UIRowFactory.make_item_row(
			item.get("color", Color.WHITE), "%s x%d" % [item.get("name", id), slot["count"]],
			"預ける", func(): _deposit(id)
		)
		player_list.add_child(row)
	if player_list.get_child_count() == 0:
		var l := Label.new()
		l.text = "持ち物はありません"
		player_list.add_child(l)

	for c in chest_list.get_children():
		c.queue_free()
	for entry in GameState.chest_items:
		var item: Dictionary = ItemDB.get_item(entry["id"])
		var id: String = entry["id"]
		var row := UIRowFactory.make_item_row(
			item.get("color", Color.WHITE), "%s x%d" % [item.get("name", id), entry["count"]],
			"取り出す", func(): _withdraw(id)
		)
		chest_list.add_child(row)
	if chest_list.get_child_count() == 0:
		var l2 := Label.new()
		l2.text = "収納箱は空です"
		chest_list.add_child(l2)

func _deposit(id: String) -> void:
	if Inventory.remove_item(id, 1):
		GameState.chest_add(id, 1)
	refresh()

func _withdraw(id: String) -> void:
	if GameState.chest_remove(id, 1):
		Inventory.add_item(id, 1)
	refresh()

func _on_close() -> void:
	EventBus.request_close_menus.emit()
