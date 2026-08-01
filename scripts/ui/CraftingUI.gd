extends Control
## 工房。左が図鑑、右が釜の二画面。
##
## 図鑑には覚えた調合と、まだ知らない調合の手がかりが並ぶ。
## 釜に素材を入れて焚くと、中身とぴったり一致するレシピがあれば成果物になる。
## 焚くあいだは魔力の脈にあわせて拍を打つリズムゲームで、精度が出来高を決める。
##
## 「細工」タブは従来どおりの決まったレシピ(板・道具など)。

const TAB_ALCHEMY := "alchemy"
const TAB_CRAFT := "craft"

## 図鑑の表示切り替え
const VIEW_FORMULA := "formula"
const VIEW_STOCK := "stock"

# --- リズムゲームの設定 ---
## 拍の数。多いほど長いが、そのぶん挽回もできる。
const BEAT_COUNT := 8
## 拍と拍の間隔(秒)
const BEAT_INTERVAL := 0.62
## 最初の拍が来るまでの余裕(構える時間)
const LEAD_IN := 1.4
## この誤差(秒)以内なら「会心」
const WINDOW_PERFECT := 0.09
## この誤差(秒)以内なら「良」
const WINDOW_GOOD := 0.19
## 拍が流れてくる帯の幅(px)
const TRACK_WIDTH := 420.0

var current_tab: String = TAB_ALCHEMY
var codex_view: String = VIEW_FORMULA
## 釜の中身。空きは ""
var cauldron: Array = []

# --- リズムゲームの状態 ---
var playing: bool = false
var _elapsed: float = 0.0
var _next_beat: int = 0
var _hits: int = 0
var _score: float = 0.0
## 各拍の判定マーカー
var _beat_nodes: Array = []

@onready var tab_alchemy: Button = $Center/Window/Margin/Content/Tabs/AlchemyTab
@onready var tab_craft: Button = $Center/Window/Margin/Content/Tabs/CraftTab

@onready var alchemy_box: HBoxContainer = $Center/Window/Margin/Content/AlchemyBox
@onready var view_formula_button: Button = $Center/Window/Margin/Content/AlchemyBox/Codex/ViewRow/FormulaView
@onready var view_stock_button: Button = $Center/Window/Margin/Content/AlchemyBox/Codex/ViewRow/StockView
@onready var codex_list: VBoxContainer = $Center/Window/Margin/Content/AlchemyBox/Codex/Scroll/List

@onready var slot_row: HBoxContainer = $Center/Window/Margin/Content/AlchemyBox/Bench/SlotRow
@onready var readout_label: Label = $Center/Window/Margin/Content/AlchemyBox/Bench/ReadoutLabel
@onready var brew_button: Button = $Center/Window/Margin/Content/AlchemyBox/Bench/BrewButton
@onready var clear_button: Button = $Center/Window/Margin/Content/AlchemyBox/Bench/ClearButton
@onready var progress_label: Label = $Center/Window/Margin/Content/AlchemyBox/Bench/ProgressLabel

@onready var rhythm_box: VBoxContainer = $Center/Window/Margin/Content/AlchemyBox/Bench/RhythmBox
@onready var rhythm_label: Label = $Center/Window/Margin/Content/AlchemyBox/Bench/RhythmBox/RhythmLabel
@onready var track: ColorRect = $Center/Window/Margin/Content/AlchemyBox/Bench/RhythmBox/Track
@onready var beats_holder: Control = $Center/Window/Margin/Content/AlchemyBox/Bench/RhythmBox/Track/Beats
@onready var judge_label: Label = $Center/Window/Margin/Content/AlchemyBox/Bench/RhythmBox/JudgeLabel

@onready var craft_box: VBoxContainer = $Center/Window/Margin/Content/CraftBox
@onready var craft_list: VBoxContainer = $Center/Window/Margin/Content/CraftBox/Scroll/List

func _ready() -> void:
	cauldron.resize(AlchemyDB.SLOT_COUNT)
	for i in range(cauldron.size()):
		cauldron[i] = ""

	$Center/Window/Margin/Content/CloseButton.pressed.connect(_on_close)
	tab_alchemy.pressed.connect(func(): _set_tab(TAB_ALCHEMY))
	tab_craft.pressed.connect(func(): _set_tab(TAB_CRAFT))
	view_formula_button.pressed.connect(func(): _set_view(VIEW_FORMULA))
	view_stock_button.pressed.connect(func(): _set_view(VIEW_STOCK))
	brew_button.pressed.connect(_start_rhythm)
	clear_button.pressed.connect(_clear_cauldron)
	Inventory.changed.connect(_on_inventory_changed)

	_build_slots()
	rhythm_box.visible = false
	_set_tab(TAB_ALCHEMY)

func _on_inventory_changed() -> void:
	RecipeDB.discover_from_inventory()
	if not playing:
		refresh()

func _set_tab(tab: String) -> void:
	current_tab = tab
	alchemy_box.visible = tab == TAB_ALCHEMY
	craft_box.visible = tab == TAB_CRAFT
	tab_alchemy.button_pressed = tab == TAB_ALCHEMY
	tab_craft.button_pressed = tab == TAB_CRAFT
	refresh()

func _set_view(view: String) -> void:
	codex_view = view
	refresh()

# ---- 釜 ----

func _build_slots() -> void:
	for i in range(AlchemyDB.SLOT_COUNT):
		var b := Button.new()
		b.custom_minimum_size = Vector2(96, 46)
		var idx := i
		b.pressed.connect(func(): _remove_from_cauldron(idx))
		slot_row.add_child(b)

func _add_to_cauldron(id: String) -> void:
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
	if playing:
		return
	if index >= 0 and index < cauldron.size() and cauldron[index] != "":
		cauldron[index] = ""
		refresh()

func _clear_cauldron() -> void:
	if playing:
		return
	for i in range(cauldron.size()):
		cauldron[i] = ""
	refresh()

## レシピの材料をそのまま釜に並べる(図鑑からの一発セット)。
func _load_recipe(id: String) -> void:
	if playing:
		return
	var r := AlchemyDB.get_recipe(id)
	if r.is_empty():
		return
	for i in range(cauldron.size()):
		cauldron[i] = ""
	var slot := 0
	for item_id in r["inputs"].keys():
		for _n in range(int(r["inputs"][item_id])):
			if slot < cauldron.size():
				cauldron[slot] = item_id
				slot += 1
	refresh()

# ---- リズムゲーム ----

func _start_rhythm() -> void:
	var filled := false
	for entry in cauldron:
		if entry != "":
			filled = true
	if not filled or playing:
		return

	playing = true
	_elapsed = 0.0
	_next_beat = 0
	_hits = 0
	_score = 0.0
	_build_beats()
	rhythm_box.visible = true
	rhythm_label.text = "魔力の脈にあわせて Space を叩け！"
	judge_label.text = ""
	brew_button.disabled = true
	clear_button.disabled = true

## 拍の印を帯の上に等間隔で並べる。左から右へ「今」を示す線が動く。
func _build_beats() -> void:
	for c in beats_holder.get_children():
		c.queue_free()
	_beat_nodes.clear()
	for i in range(BEAT_COUNT):
		var mark := ColorRect.new()
		mark.color = Color(0.55, 0.6, 0.75)
		mark.size = Vector2(6, 34)
		mark.position = Vector2(_beat_x(i) - 3.0, 3.0)
		beats_holder.add_child(mark)
		_beat_nodes.append(mark)

func _beat_x(index: int) -> float:
	return TRACK_WIDTH * float(index + 1) / float(BEAT_COUNT + 1)

## その拍が鳴る時刻
func _beat_time(index: int) -> float:
	return LEAD_IN + BEAT_INTERVAL * float(index)

func _process(delta: float) -> void:
	if not playing:
		return
	_elapsed += delta

	# 見逃した拍を判定する
	while _next_beat < BEAT_COUNT and _elapsed > _beat_time(_next_beat) + WINDOW_GOOD:
		_mark_beat(_next_beat, Color(0.8, 0.3, 0.3))
		judge_label.text = "見逃し…"
		_next_beat += 1
		_hits += 1

	# 「今」を示す線を動かす
	var head := $Center/Window/Margin/Content/AlchemyBox/Bench/RhythmBox/Track/Head as ColorRect
	if head != null:
		var t := clampf((_elapsed - LEAD_IN + BEAT_INTERVAL) / (BEAT_INTERVAL * float(BEAT_COUNT + 1)), 0.0, 1.0)
		head.position.x = TRACK_WIDTH * t

	if _hits >= BEAT_COUNT:
		_finish_rhythm()

func _unhandled_input(event: InputEvent) -> void:
	if not playing:
		return
	if event.is_action_pressed("jump") or event.is_action_pressed("interact"):
		_tap()
		get_viewport().set_input_as_handled()

func _tap() -> void:
	if _next_beat >= BEAT_COUNT:
		return
	var error: float = absf(_elapsed - _beat_time(_next_beat))
	# まだ拍が遠いなら空打ち。次の拍を潰さずに見送る。
	if error > BEAT_INTERVAL * 0.5:
		judge_label.text = "早すぎる"
		return

	if error <= WINDOW_PERFECT:
		_score += 1.0
		_mark_beat(_next_beat, Color(1.0, 0.85, 0.3))
		judge_label.text = "会心！"
	elif error <= WINDOW_GOOD:
		_score += 0.6
		_mark_beat(_next_beat, Color(0.4, 0.85, 0.5))
		judge_label.text = "good"
	else:
		_mark_beat(_next_beat, Color(0.8, 0.3, 0.3))
		judge_label.text = "外した"
	_next_beat += 1
	_hits += 1

func _mark_beat(index: int, color: Color) -> void:
	if index >= 0 and index < _beat_nodes.size():
		var mark := _beat_nodes[index] as ColorRect
		if mark != null:
			mark.color = color

func _finish_rhythm() -> void:
	playing = false
	var performance := _score / float(BEAT_COUNT)
	rhythm_box.visible = false
	brew_button.disabled = false
	clear_button.disabled = false

	AlchemyDB.brew(cauldron, performance)
	for i in range(cauldron.size()):
		cauldron[i] = ""
	refresh()

# ---- 描画 ----

func refresh() -> void:
	if current_tab == TAB_ALCHEMY:
		_refresh_codex()
		_refresh_bench()
	else:
		_refresh_craft()

func _refresh_codex() -> void:
	view_formula_button.button_pressed = codex_view == VIEW_FORMULA
	view_stock_button.button_pressed = codex_view == VIEW_STOCK
	for c in codex_list.get_children():
		c.queue_free()
	if codex_view == VIEW_FORMULA:
		_build_formula_list()
	else:
		_build_stock_list()

## 覚えた調合と、まだ知らない調合の手がかり。
func _build_formula_list() -> void:
	for recipe in AlchemyDB.recipes:
		var rid: String = recipe["id"]
		if not AlchemyDB.is_discovered(rid):
			codex_list.add_child(UIRowFactory.make_item_row(
				Color(0.3, 0.3, 0.34), "？？？  — %s" % recipe["hint"], "", func(): pass, true))
			continue
		var parts: Array = []
		for item_id in recipe["inputs"].keys():
			parts.append("%s x%d(%d)" % [ItemDB.get_display_name(item_id),
				int(recipe["inputs"][item_id]), Inventory.get_count(item_id)])
		var can: bool = AlchemyDB.can_make(rid)
		codex_list.add_child(UIRowFactory.make_item_row(
			ItemDB.get_color(recipe["output_id"]),
			"%s ← %s" % [recipe["name"], "、".join(parts)],
			"釜へ" if can else "材料不足", func(): _load_recipe(rid), not can))

## 手持ちの素材。ここから1つずつ釜に入れて、未知の組み合わせを試せる。
func _build_stock_list() -> void:
	var shown := 0
	for id in ItemDB.all_ids():
		if not ItemDB.is_ingredient(id):
			continue
		var have := Inventory.get_count(id)
		if have <= 0:
			continue
		shown += 1
		var iid: String = id
		codex_list.add_child(UIRowFactory.make_item_row(
			ItemDB.get_color(id),
			"%s  x%d  (%s)" % [ItemDB.get_display_name(id), have, ItemDB.get_type_label(id)],
			"釜へ", func(): _add_to_cauldron(iid)))
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
		b.text = "(空)" if id == "" else ItemDB.get_display_name(id)
		b.tooltip_text = "" if id == "" else "押すと釜から戻す"
		b.disabled = playing

	var result := AlchemyDB.preview(cauldron)
	readout_label.text = String(result["note"])
	brew_button.disabled = playing or not bool(result["ready"])
	progress_label.text = "覚えた調合: %d / %d" % [
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
	# 調合中に閉じられると素材が宙に浮くので、中身を戻してから閉じる
	playing = false
	rhythm_box.visible = false
	_clear_cauldron()
	EventBus.request_close_menus.emit()
