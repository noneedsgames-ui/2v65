extends Control

@onready var list: VBoxContainer = $Center/Window/Margin/Content/Scroll/List
@onready var gold_label: Label = $Center/Window/Margin/Content/GoldLabel

func _ready() -> void:
	$Center/Window/Margin/Content/CloseButton.pressed.connect(_on_close)
	Inventory.changed.connect(refresh)

func refresh() -> void:
	gold_label.text = "所持金: %dG" % Inventory.gold
	for c in list.get_children():
		c.queue_free()

	var any := false
	for slot in Inventory.slots:
		if slot == null:
			continue
		any = true
		var item: Dictionary = ItemDB.get_item(slot["id"])
		var id: String = slot["id"]
		var is_food: bool = item.get("type", -1) == ItemDB.ItemType.FOOD
		var label_text := "%s x%d" % [item.get("name", id), slot["count"]]
		var row := UIRowFactory.make_item_row(
			item.get("color", Color.WHITE), label_text,
			"食べる" if is_food else "",
			func(): _use_item(id)
		)
		list.add_child(row)

	if not any:
		var empty_label := Label.new()
		empty_label.text = "何も持っていません"
		list.add_child(empty_label)

func _use_item(id: String) -> void:
	if Inventory.remove_item(id, 1):
		EventBus.notify.emit("%sを食べた。おいしい!" % ItemDB.get_display_name(id))
	refresh()

func _on_close() -> void:
	EventBus.request_close_menus.emit()
