extends Control
## 工房。左が図鑑、右が釜の二画面。
##
## 図鑑で素材の属性と力を見比べ、狙った属性を狙った強さまで積んで釜に入れる。
## 釜の実況(主属性・合計・純度・出来上がりそうなもの)は入れるたびに更新されるので、
## 「あと火をいくつ足せば次の段に届くか」を考えながら調合できる。
##
## 「細工」タブは従来どおりの決まったレシピ(板・道具など)。

const TAB_ALCHEMY := "alchemy"
const TAB_CRAFT := "craft"

## 図鑑の絞り込み
const FILTER_ALL := -1

var current_tab: String = TAB_ALCHEMY
var filter_type: int = FILTER_ALL
var selected_id: String = ""
## 釜の中身。空きは ""
var cauldron: Array = []

@onready var tab_alchemy: Button = $Center/Window/Margin/Content/Tabs/AlchemyTab
@onready var tab_craft: Button = $Center/Window/Margin/Content/Tabs/CraftTab

@onready var alchemy_box: HBoxContainer = $Center/Window/Margin/Content/AlchemyBox
@onready var filter_row: HBoxContainer = $Center/Window/Margin/Content/AlchemyBox/Codex/FilterRow
@onready var codex_list: VBoxContainer = $Center/Window/Margin/Content/AlchemyBox/Codex/Scroll/List
@onready var detail_label: Label = $Center/Window/Margin/Content/AlchemyBox/Bench/DetailLabel
@onready var slot_row: HBoxContainer = $Center/Window/Margin/Content/AlchemyBox/Bench/SlotRow
@onready var readout_label: Label = $Center/Window/Margin/Content/AlchemyBox/Bench/ReadoutLabel
@onready var brew_button: Button = $Center/Window/Margin/Content/AlchemyBox/Bench/BrewButton
@onready var clear_button: Button = $Center/Window/Margin/Content/AlchemyBox/Bench/ClearButton
@onready var progress_label: Label = $Center/Window/Margin/Content/AlchemyBox/Bench/ProgressLabel

@onready var craft_box: VBoxContainer = $Center/Window/Margin/Content/CraftBox
@onready var craft_list: VBoxContainer = $Center/Window/Margin/Content/CraftBox/Scroll/List

func _ready() -> void:
	cauldron.resize(AlchemyDB.SLOT_COUNT)
	for i in range(cauldron.size()):
		cauldron[i] = ""

	$Center/Window/Margin/Content/CloseButton.pressed.connect(_on_close)
	tab_alchemy.pressed.connect(func(): _set_tab(TAB_ALCHEMY))
	tab_craft.pressed.connect(func(): _set_tab(TAB_CRAFT))
	brew_button.pressed.connect(_brew)
	clear_button.pressed.connect(_clear_cauldron)
	Inventory.changed.connect(_on_inventory_changed)

	_build_filters()
	_build_slots()
	_set_tab(TAB_ALCHEMY)

func _on_inventory_changed() -> void:
	RecipeDB.discover_from_inventory()
	refresh()

# ---- 図鑑の絞り込み ----

func _build_filters() -> void:
	var kinds := [
		[FILTER_ALL, "すべて"],
		[ItemDB.ItemType.HERB, "薬草"],
		[ItemDB.ItemType.ORE, "鉱石"],
		[ItemDB.ItemType.MATERIAL, "素材"],
		[ItemDB.ItemType.CATALYST, "触媒"],
	]
	for entry in kinds:
		var b := Button.new()
		b.text = entry[1]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(74, 28)
		var v: int = entry[0]
		b.pressed.connect(func(): _set_filter(v))
		filter_row.add_child(b)

func _set_filter(value: int) -> void:
	filter_type = value
	refresh()

func _set_tab(tab: String) -> void:
	current_tab = tab
	alchemy_box.visible = tab == TAB_ALCHEMY
	craft_box.visible = tab == TAB_CRAFT
	tab_alchemy.button_pressed = tab == TAB_ALCHEMY
	tab_craft.button_pressed = tab == TAB_CRAFT
	refresh()

# ---- 釜のスロット ----

func _build_slots() -> void:
	for i in range(AlchemyDB.SLOT_COUNT):
		var b := Button.new()
		b.custom_minimum_size = Vector2(88, 44)
		var idx := i
		b.pressed.connect(func(): _remove_from_cauldron(idx))
		slot_row.add_child(b)

func _add_to_cauldron(id: String) -> void:
	# 手持ちの数を超えて同じ素材は入れられない
	var already := 0
	for entry in cauldron:
		if entry == id:
			already += 1
	if Inventory.get_count(id) <= already:
		EventBus.notify.emit("%sの持ち合わせが足りない" % ItemDB.get_display_name(id))
		return
	for i in range(cauldron.size()):
		if cauldron[i] == "":
			cauldron[i] = id
			refresh()
			return
	EventBus.notify.emit("釜がいっぱいだ")

func _remove_from_cauldron(index: int) -> void:
	if index >= 0 and index < cauldron.size() and cauldron[index] != "":
		cauldron[index] = ""
		refresh()

func _clear_cauldron() -> void:
	for i in range(cauldron.size()):
		cauldron[i] = ""
	refresh()

func _brew() -> void:
	var used: Array = []
	for entry in cauldron:
		if entry != "":
			used.append(entry)
	if used.is_empty():
		return
	AlchemyDB.brew(cauldron)
	_clear_cauldron()

# ---- 描画 ----

func refresh() -> void:
	if current_tab == TAB_ALCHEMY:
		_refresh_codex()
		_refresh_bench()
	else:
		_refresh_craft()

func _refresh_codex() -> void:
	for i in range(filter_row.get_child_count()):
		var b := filter_row.get_child(i) as Button
		if b == null:
			continue
		var kinds := [FILTER_ALL, ItemDB.ItemType.HERB, ItemDB.ItemType.ORE,
			ItemDB.ItemType.MATERIAL, ItemDB.ItemType.CATALYST]
		if i < kinds.size():
			b.button_pressed = kinds[i] == filter_type

	for c in codex_list.get_children():
		c.queue_free()

	var shown := 0
	for id in ItemDB.all_ids():
		if not ItemDB.is_ingredient(id):
			continue
		if filter_type != FILTER_ALL and ItemDB.get_type(id) != filter_type:
			continue
		var have := Inventory.get_count(id)
		if have <= 0:
			continue
		shown += 1
		var iid: String = id
		var label_text := "%s  〈%s〉力%d  x%d" % [
			ItemDB.get_display_name(id), ItemDB.get_element_label(id),
			ItemDB.get_potency(id), have]
		var row := UIRowFactory.make_item_row(
			ItemDB.get_color(id), label_text, "釜へ", func(): _add_to_cauldron(iid))
		# 行を押すと説明を出す(ボタンは釜へ入れる)
		codex_list.add_child(row)

	if shown == 0:
		var l := Label.new()
		l.text = "手持ちに素材がない。採集してこよう。"
		codex_list.add_child(l)

func _refresh_bench() -> void:
	for i in range(slot_row.get_child_count()):
		var b := slot_row.get_child(i) as Button
		if b == null:
			continue
		var id: String = cauldron[i] if i < cauldron.size() else ""
		if id == "":
			b.text = "(空)"
			b.tooltip_text = ""
		else:
			b.text = "%s\n〈%s〉%d" % [
				ItemDB.get_display_name(id), ItemDB.get_element_label(id), ItemDB.get_potency(id)]
			b.tooltip_text = "押すと釜から戻す"

	var result := AlchemyDB.preview(cauldron)
	var lines: Array = []
	if int(result["tier"]) < 0 and String(result["output_id"]) == "":
		lines.append(String(result["note"]))
	else:
		lines.append("主属性: 〈%s〉  合計の力: %d" % [
			ItemDB.ELEMENT_LABELS.get(result["element"], "無"), int(result["total"])])
		lines.append("純度: %d%%" % int(float(result["purity"]) * 100.0))
		var out: String = result["output_id"]
		if out == AlchemyDB.FAILURE_ID:
			lines.append("→ このままでは澱む(%s)" % String(result["note"]))
		elif out != "":
			lines.append("→ %s x%d ができそうだ" % [ItemDB.get_display_name(out), int(result["amount"])])
	readout_label.text = "\n".join(lines)
	brew_button.disabled = String(result["output_id"]) == ""

	if selected_id != "":
		detail_label.text = "%s 〈%s〉力%d\n%s" % [
			ItemDB.get_display_name(selected_id), ItemDB.get_element_label(selected_id),
			ItemDB.get_potency(selected_id), ItemDB.get_description(selected_id)]
	else:
		detail_label.text = "図鑑から素材を釜に入れよう。\n同じ属性を積むほど強い霊薬になる。"

	progress_label.text = "調合の記録: %d / %d" % [
		AlchemyDB.discovered_count(), AlchemyDB.total_outputs()]

func _refresh_craft() -> void:
	RecipeDB.discover_from_inventory()
	for c in craft_list.get_children():
		c.queue_free()
	for recipe in RecipeDB.recipes:
		var rid: String = recipe["id"]
		if not RecipeDB.is_discovered(rid):
			craft_list.add_child(UIRowFactory.make_item_row(
				Color(0.3, 0.3, 0.34), "？？？  (材料を手に入れると分かる)", "", func(): pass, true))
			continue
		var parts: Array = []
		for item_id in recipe["inputs"].keys():
			parts.append("%s %d/%d" % [ItemDB.get_display_name(item_id),
				Inventory.get_count(item_id), int(recipe["inputs"][item_id])])
		var can: bool = RecipeDB.can_craft(rid)
		craft_list.add_child(UIRowFactory.make_item_row(
			ItemDB.get_color(recipe["output_id"]),
			"%s ← %s" % [recipe["name"], "、".join(parts)],
			"作る" if can else "材料不足", func(): _craft(rid), not can))

func _craft(id: String) -> void:
	var recipe := RecipeDB.get_recipe(id)
	if RecipeDB.craft(id, RecipeDB.Quality.NORMAL):
		EventBus.notify.emit("%sを作った" % recipe["name"])
	else:
		EventBus.notify.emit("材料が足りません")
	refresh()

func _on_close() -> void:
	_clear_cauldron()
	EventBus.request_close_menus.emit()
