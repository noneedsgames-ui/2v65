extends Control
## クラフト画面。カテゴリで絞り込み、未発見のレシピは伏せて表示する。
## 「作る」を押すと手さばきのミニゲームが始まり、止めた位置で品質が決まる。

const BAR_WIDTH := 460.0
## 針の速さ(px/秒)。作るものが高度なほど速くなる。
const BASE_SPEED := 300.0

var current_category: int = 0
var selected_id: String = ""

## ミニゲームの状態
var playing: bool = false
var marker_x: float = 0.0
var marker_dir: float = 1.0
var marker_speed: float = BASE_SPEED

@onready var tabs: HBoxContainer = $Center/Window/Margin/Content/Tabs
@onready var list: VBoxContainer = $Center/Window/Margin/Content/Scroll/List
@onready var game_box: VBoxContainer = $Center/Window/Margin/Content/GameBox
@onready var game_label: Label = $Center/Window/Margin/Content/GameBox/GameLabel
@onready var marker: ColorRect = $Center/Window/Margin/Content/GameBox/Bar/Marker
@onready var zone_good: ColorRect = $Center/Window/Margin/Content/GameBox/Bar/Good
@onready var zone_perfect: ColorRect = $Center/Window/Margin/Content/GameBox/Bar/Perfect
@onready var stop_button: Button = $Center/Window/Margin/Content/GameBox/StopButton

func _ready() -> void:
	$Center/Window/Margin/Content/CloseButton.pressed.connect(_on_close)
	stop_button.pressed.connect(_stop_game)
	Inventory.changed.connect(_on_inventory_changed)
	_build_tabs()
	game_box.visible = false

func _on_inventory_changed() -> void:
	RecipeDB.discover_from_inventory()
	refresh()

func _build_tabs() -> void:
	for c in tabs.get_children():
		c.queue_free()
	for category in RecipeDB.categories_in_order():
		var b := Button.new()
		b.text = RecipeDB.CATEGORY_LABELS[category]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(110, 32)
		var cat: int = category
		b.pressed.connect(func(): _set_category(cat))
		tabs.add_child(b)

func _set_category(category: int) -> void:
	current_category = category
	refresh()

func refresh() -> void:
	# 開いた時点の手持ちで新しいレシピに気づくことがある
	RecipeDB.discover_from_inventory()

	var order := RecipeDB.categories_in_order()
	for i in range(tabs.get_child_count()):
		var b := tabs.get_child(i) as Button
		if b != null and i < order.size():
			b.button_pressed = order[i] == current_category

	for c in list.get_children():
		c.queue_free()

	for recipe in RecipeDB.recipes_in_category(current_category):
		var rid: String = recipe["id"]
		if not RecipeDB.is_discovered(rid):
			var row := UIRowFactory.make_item_row(
				Color(0.3, 0.3, 0.34), "？？？  (材料を手に入れると分かる)", "", func(): pass, true)
			list.add_child(row)
			continue

		var parts: Array = []
		for item_id in recipe["inputs"].keys():
			var need := int(recipe["inputs"][item_id])
			var have := Inventory.get_count(item_id)
			parts.append("%s %d/%d" % [ItemDB.get_display_name(item_id), have, need])
		var label_text := "%s ← %s" % [recipe["name"], "、".join(parts)]
		var can: bool = RecipeDB.can_craft(rid)
		var row2 := UIRowFactory.make_item_row(
			ItemDB.get_color(recipe["output_id"]), label_text,
			"作る" if can else "材料不足", func(): _start_game(rid), not can)
		list.add_child(row2)

func _start_game(id: String) -> void:
	selected_id = id
	playing = true
	marker_x = 0.0
	marker_dir = 1.0
	# 材料の種類が多いレシピほど針が速く、狙いにくい
	var complexity: int = RecipeDB.get_recipe(id)["inputs"].size()
	marker_speed = BASE_SPEED + 90.0 * float(complexity - 1)
	_place_zones()
	game_box.visible = true
	game_label.text = "%s を作る — 止めろ！" % RecipeDB.get_recipe(id)["name"]
	stop_button.disabled = false

## 当たり判定の帯をランダムな位置に置く。
func _place_zones() -> void:
	var good_w := 150.0
	var good_x: float = randf_range(20.0, BAR_WIDTH - good_w - 20.0)
	zone_good.position.x = good_x
	zone_good.size.x = good_w
	var perfect_w := 46.0
	zone_perfect.position.x = good_x + (good_w - perfect_w) * 0.5
	zone_perfect.size.x = perfect_w

func _process(delta: float) -> void:
	if not playing:
		return
	marker_x += marker_dir * marker_speed * delta
	if marker_x >= BAR_WIDTH:
		marker_x = BAR_WIDTH
		marker_dir = -1.0
	elif marker_x <= 0.0:
		marker_x = 0.0
		marker_dir = 1.0
	marker.position.x = marker_x

func _unhandled_input(event: InputEvent) -> void:
	if playing and (event.is_action_pressed("jump") or event.is_action_pressed("interact")):
		_stop_game()
		get_viewport().set_input_as_handled()

func _stop_game() -> void:
	if not playing:
		return
	playing = false
	stop_button.disabled = true

	var quality := RecipeDB.Quality.NORMAL
	var center := marker_x + marker.size.x * 0.5
	if center >= zone_perfect.position.x and center <= zone_perfect.position.x + zone_perfect.size.x:
		quality = RecipeDB.Quality.PERFECT
	elif center >= zone_good.position.x and center <= zone_good.position.x + zone_good.size.x:
		quality = RecipeDB.Quality.GOOD
	elif center < 40.0 or center > BAR_WIDTH - 40.0:
		quality = RecipeDB.Quality.POOR

	var recipe := RecipeDB.get_recipe(selected_id)
	var amount := RecipeDB.craft_amount(selected_id, quality)
	if RecipeDB.craft(selected_id, quality):
		EventBus.notify.emit("%s: %s x%d" % \
			[RecipeDB.QUALITY_LABELS[quality], recipe["name"], amount])
		if quality == RecipeDB.Quality.PERFECT:
			EventBus.companion_say.emit("見事！ ひとつ多く取れたよ。")
		elif quality == RecipeDB.Quality.POOR:
			EventBus.companion_say.emit("うーん、ちょっと惜しかったね。")
	else:
		EventBus.notify.emit("材料が足りません")

	game_box.visible = false
	refresh()

func _on_close() -> void:
	playing = false
	game_box.visible = false
	EventBus.request_close_menus.emit()
