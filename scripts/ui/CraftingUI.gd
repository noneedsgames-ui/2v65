extends Control

@onready var list: VBoxContainer = $Center/Window/Margin/Content/Scroll/List

func _ready() -> void:
	$Center/Window/Margin/Content/CloseButton.pressed.connect(_on_close)
	Inventory.changed.connect(refresh)

func refresh() -> void:
	for c in list.get_children():
		c.queue_free()

	for recipe in RecipeDB.recipes:
		var parts: Array = []
		for item_id in recipe["inputs"].keys():
			var need: int = int(recipe["inputs"][item_id])
			var have: int = Inventory.get_count(item_id)
			parts.append("%s %d/%d" % [ItemDB.get_display_name(item_id), have, need])
		var out_item: Dictionary = ItemDB.get_item(recipe["output_id"])
		var label_text := "%s ← %s" % [recipe["name"], ", ".join(parts)]
		var can: bool = RecipeDB.can_craft(recipe["id"])
		var rid: String = recipe["id"]
		var row := UIRowFactory.make_item_row(
			out_item.get("color", Color.WHITE), label_text,
			"作成" if can else "不足", func(): _craft(rid), not can
		)
		list.add_child(row)

func _craft(id: String) -> void:
	var recipe_name: String = RecipeDB.get_recipe(id).get("name", id)
	if RecipeDB.craft(id):
		EventBus.notify.emit("%sを作成した" % recipe_name)
	else:
		EventBus.notify.emit("材料が足りません")
	refresh()

func _on_close() -> void:
	EventBus.request_close_menus.emit()
