extends Control
## 工房。タブは「調合」「道具設計」「図鑑」の3つ。
##
## 図鑑タブは読むためだけの独立した画面で、そこから材料を釜へ送る導線はない。
## プレイヤーは図鑑で性質や並びを読んで覚え、作業タブに切り替えて
## 自分の持ち物から素材を選び、自分で順番を決める。
##
## 道具設計は家の作業台でしか開けない(bench モードのときだけタブが出る)。

const TAB_BREW := "brew"
const TAB_TOOL := "tool"
const TAB_CODEX := "codex"

# --- リズムゲームの設定 ---
const BEAT_COUNT := 8
const BEAT_INTERVAL := 0.62
const LEAD_IN := 1.4
const WINDOW_PERFECT := 0.09
const WINDOW_GOOD := 0.19
const TRACK_WIDTH := 400.0

var current_tab: String = TAB_BREW
## true なら家の作業台。道具設計が使える。
var bench_mode: bool = false

## 釜の中身(入れた順)。空きは ""
var cauldron: Array = []
## 道具設計で選んでいる道具と部品
var selected_tool: String = ""
var selected_part: int = 0
## 部品づくりの受け皿
var part_slots: Array = []

# --- リズムゲームの状態 ---
var playing: bool = false
var _elapsed: float = 0.0
var _next_beat: int = 0
var _hits: int = 0
var _score: float = 0.0
var _beat_nodes: Array = []

@onready var tab_brew: Button = $Center/Window/Margin/Content/Tabs/BrewTab
@onready var tab_tool: Button = $Center/Window/Margin/Content/Tabs/ToolTab
@onready var tab_codex: Button = $Center/Window/Margin/Content/Tabs/CodexTab

@onready var brew_box: HBoxContainer = $Center/Window/Margin/Content/BrewBox
@onready var stock_list: VBoxContainer = $Center/Window/Margin/Content/BrewBox/Stock/Scroll/List
@onready var slot_row: HBoxContainer = $Center/Window/Margin/Content/BrewBox/Bench/SlotRow
@onready var readout_label: Label = $Center/Window/Margin/Content/BrewBox/Bench/ReadoutLabel
@onready var brew_button: Button = $Center/Window/Margin/Content/BrewBox/Bench/BrewButton
@onready var clear_button: Button = $Center/Window/Margin/Content/BrewBox/Bench/ClearButton
@onready var rhythm_box: VBoxContainer = $Center/Window/Margin/Content/BrewBox/Bench/RhythmBox
@onready var track_head: ColorRect = $Center/Window/Margin/Content/BrewBox/Bench/RhythmBox/Track/Head
@onready var beats_holder: Control = $Center/Window/Margin/Content/BrewBox/Bench/RhythmBox/Track/Beats
@onready var judge_label: Label = $Center/Window/Margin/Content/BrewBox/Bench/RhythmBox/JudgeLabel

@onready var tool_box: HBoxContainer = $Center/Window/Margin/Content/ToolBox
@onready var tool_list: VBoxContainer = $Center/Window/Margin/Content/ToolBox/Left/Scroll/List
@onready var part_title: Label = $Center/Window/Margin/Content/ToolBox/Right/PartTitle
@onready var part_note: Label = $Center/Window/Margin/Content/ToolBox/Right/PartNote
@onready var part_slot_row: HBoxContainer = $Center/Window/Margin/Content/ToolBox/Right/PartSlots
@onready var part_stock: VBoxContainer = $Center/Window/Margin/Content/ToolBox/Right/Scroll/List
@onready var part_readout: Label = $Center/Window/Margin/Content/ToolBox/Right/PartReadout
@onready var part_button: Button = $Center/Window/Margin/Content/ToolBox/Right/BuildButton
@onready var assemble_button: Button = $Center/Window/Margin/Content/ToolBox/Right/AssembleButton

@onready var codex_box: VBoxContainer = $Center/Window/Margin/Content/CodexBox
@onready var search_edit: LineEdit = $Center/Window/Margin/Content/CodexBox/SearchRow/SearchEdit
@onready var codex_list: VBoxContainer = $Center/Window/Margin/Content/CodexBox/Scroll/List

## start() / solved / cancelled はスクリプト側の定義なので、Control 型を付けると
## 静的解析で見つからない扱いになる。ここは型を付けない。
@onready var circuit = $CircuitGame

func _ready() -> void:
	cauldron.resize(AlchemyDB.SLOT_COUNT)
	for i in range(cauldron.size()):
		cauldron[i] = ""
	part_slots.resize(ToolDB.PART_SLOTS)
	for i in range(part_slots.size()):
		part_slots[i] = ""

	$Center/Window/Margin/Content/CloseButton.pressed.connect(_on_close)
	tab_brew.pressed.connect(func(): _set_tab(TAB_BREW))
	tab_tool.pressed.connect(func(): _set_tab(TAB_TOOL))
	tab_codex.pressed.connect(func(): _set_tab(TAB_CODEX))
	brew_button.pressed.connect(_start_rhythm)
	clear_button.pressed.connect(_clear_cauldron)
	part_button.pressed.connect(_build_part)
	assemble_button.pressed.connect(_start_circuit)
	search_edit.text_changed.connect(func(_t): _refresh_codex())
	Inventory.changed.connect(_on_inventory_changed)
	circuit.solved.connect(_on_circuit_solved)
	circuit.cancelled.connect(func(): refresh())
	visibility_changed.connect(_on_visibility_changed)

	_build_cauldron_slots()
	_build_part_slots()
	rhythm_box.visible = false

## 呼び出し元(作業台かどうか)を指定して開く。
func set_bench_mode(value: bool) -> void:
	bench_mode = value
	if not bench_mode and current_tab == TAB_TOOL:
		current_tab = TAB_BREW

## Esc で閉じると _on_close を通らないので、ここで止める。
## そうしないと画面が消えたまま拍だけ進み、勝手に調合が終わってしまう。
func _on_visibility_changed() -> void:
	if visible:
		return
	playing = false
	rhythm_box.visible = false
	brew_button.disabled = false
	clear_button.disabled = false
	circuit.visible = false

func _on_inventory_changed() -> void:
	if not playing:
		refresh()

func _set_tab(tab: String) -> void:
	if tab == TAB_TOOL and not bench_mode:
		EventBus.notify.emit("道具は家の作業台でしか組めない")
		return
	current_tab = tab
	refresh()

# ---- 釜 ----

func _build_cauldron_slots() -> void:
	for i in range(AlchemyDB.SLOT_COUNT):
		var b := Button.new()
		b.custom_minimum_size = Vector2(84, 58)
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

## 途中の素材を抜いたら、後ろを前に詰める(順番が命なので穴を残さない)。
func _remove_from_cauldron(index: int) -> void:
	if playing or index < 0 or index >= cauldron.size() or cauldron[index] == "":
		return
	cauldron.remove_at(index)
	cauldron.append("")
	refresh()

func _clear_cauldron() -> void:
	if playing:
		return
	for i in range(cauldron.size()):
		cauldron[i] = ""
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
	judge_label.text = ""
	brew_button.disabled = true
	clear_button.disabled = true
	refresh()

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

func _beat_time(index: int) -> float:
	return LEAD_IN + BEAT_INTERVAL * float(index)

func _process(delta: float) -> void:
	if not playing:
		return
	_elapsed += delta

	while _next_beat < BEAT_COUNT and _elapsed > _beat_time(_next_beat) + WINDOW_GOOD:
		_mark_beat(_next_beat, Color(0.8, 0.3, 0.3))
		judge_label.text = "見逃し…"
		_next_beat += 1
		_hits += 1

	var t := clampf((_elapsed - LEAD_IN + BEAT_INTERVAL) / (BEAT_INTERVAL * float(BEAT_COUNT + 1)), 0.0, 1.0)
	track_head.position.x = TRACK_WIDTH * t

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

# ---- 道具設計 ----

func _build_part_slots() -> void:
	for i in range(ToolDB.PART_SLOTS):
		var b := Button.new()
		b.custom_minimum_size = Vector2(120, 46)
		var idx := i
		b.pressed.connect(func(): _remove_from_part(idx))
		part_slot_row.add_child(b)

func _add_to_part(id: String) -> void:
	var already := 0
	for entry in part_slots:
		if entry == id:
			already += 1
	if Inventory.get_count(id) <= already:
		EventBus.notify.emit("%sの持ち合わせが足りない" % ItemDB.get_display_name(id))
		return
	for i in range(part_slots.size()):
		if part_slots[i] == "":
			part_slots[i] = id
			refresh()
			return
	EventBus.notify.emit("これ以上は入らない")

func _remove_from_part(index: int) -> void:
	if index >= 0 and index < part_slots.size() and part_slots[index] != "":
		part_slots[index] = ""
		refresh()

func _clear_part_slots() -> void:
	for i in range(part_slots.size()):
		part_slots[i] = ""

func _select_tool(tool_id: String) -> void:
	selected_tool = tool_id
	selected_part = 0
	# まだできていない最初の部品に合わせる
	for i in range(ToolDB.part_count(tool_id)):
		if not ToolDB.is_part_done(tool_id, i):
			selected_part = i
			break
	_clear_part_slots()
	refresh()

func _select_part(index: int) -> void:
	selected_part = index
	_clear_part_slots()
	refresh()

func _build_part() -> void:
	if selected_tool == "":
		return
	if ToolDB.build_part(selected_tool, selected_part, part_slots):
		_clear_part_slots()
		# 次のまだできていない部品へ自動で進む
		for i in range(ToolDB.part_count(selected_tool)):
			if not ToolDB.is_part_done(selected_tool, i):
				selected_part = i
				break
	refresh()

func _start_circuit() -> void:
	if selected_tool == "" or not ToolDB.all_parts_done(selected_tool):
		return
	circuit.start(ToolDB.get_tool(selected_tool)["name"])

func _on_circuit_solved() -> void:
	if selected_tool != "":
		ToolDB.complete_tool(selected_tool)
	refresh()

# ---- 描画 ----

func refresh() -> void:
	tab_tool.visible = bench_mode
	tab_brew.button_pressed = current_tab == TAB_BREW
	tab_tool.button_pressed = current_tab == TAB_TOOL
	tab_codex.button_pressed = current_tab == TAB_CODEX
	brew_box.visible = current_tab == TAB_BREW
	tool_box.visible = current_tab == TAB_TOOL
	codex_box.visible = current_tab == TAB_CODEX

	if current_tab == TAB_BREW:
		_refresh_stock()
		_refresh_cauldron()
	elif current_tab == TAB_TOOL:
		_refresh_tools()
	else:
		_refresh_codex()

## 作業タブの持ち物一覧。魔力を宿している素材だけが並ぶ。
func _refresh_stock() -> void:
	for c in stock_list.get_children():
		c.queue_free()
	var shown := 0
	for id in ItemDB.all_ids():
		if not ManaDB.has_mana(id):
			continue
		var have := Inventory.get_count(id)
		if have <= 0:
			continue
		shown += 1
		var iid: String = id
		var buffer_mark := "  ◆緩衝材" if ManaDB.is_buffer(id) else ""
		stock_list.add_child(UIRowFactory.make_item_row(
			ItemDB.get_color(id),
			"%s  〈%s〉魔力%d  x%d%s" % [ItemDB.get_display_name(id),
				ManaDB.natures_label(id), ManaDB.get_mana(id), have, buffer_mark],
			"入れる", func(): _add_to_cauldron(iid), playing))
	if shown == 0:
		var l := Label.new()
		l.text = "魔力を宿した素材がない。採集してこよう。"
		stock_list.add_child(l)

func _refresh_cauldron() -> void:
	var result := AlchemyDB.preview(cauldron)
	var clash := int(result["clash"])
	for i in range(slot_row.get_child_count()):
		var b := slot_row.get_child(i) as Button
		if b == null:
			continue
		var id: String = cauldron[i] if i < cauldron.size() else ""
		if id == "":
			b.text = "%d\n(空)" % (i + 1)
			b.modulate = Color(1, 1, 1)
		else:
			b.text = "%d\n%s\n〈%s〉%d" % [i + 1, ItemDB.get_display_name(id),
				ManaDB.natures_label(id), ManaDB.get_mana(id)]
			# 弾き合っている位置は赤く出す
			b.modulate = Color(1, 0.6, 0.6) if (i == clash or i == clash - 1) else Color(1, 1, 1)
		b.disabled = playing

	readout_label.text = String(result["note"])
	brew_button.disabled = playing or not bool(result["ready"])

func _refresh_tools() -> void:
	for c in tool_list.get_children():
		c.queue_free()
	for t in ToolDB.tools:
		var tid: String = t["id"]
		var done := ToolDB.done_count(tid)
		var total := ToolDB.part_count(tid)
		var mark := "✓" if ToolDB.has_built(tid) else "%d/%d" % [done, total]
		tool_list.add_child(UIRowFactory.make_item_row(
			ItemDB.get_color(tid), "%s  [%s]" % [t["name"], mark],
			"選ぶ", func(): _select_tool(tid), tid == selected_tool))

	if selected_tool == "":
		part_title.text = "左から道具を選ぼう"
		part_note.text = ""
		part_readout.text = ""
		part_button.visible = false
		assemble_button.visible = false
		for c in part_stock.get_children():
			c.queue_free()
		for i in range(part_slot_row.get_child_count()):
			var sb := part_slot_row.get_child(i) as Button
			if sb != null:
				sb.text = "(空)"
		return

	var tool_def := ToolDB.get_tool(selected_tool)
	var part := ToolDB.get_part(selected_tool, selected_part)
	var lines: Array = []
	for i in range(ToolDB.part_count(selected_tool)):
		var p := ToolDB.get_part(selected_tool, i)
		var state := "済" if ToolDB.is_part_done(selected_tool, i) else "未"
		var cursor := "▶" if i == selected_part else "  "
		lines.append("%s%s(%s)" % [cursor, p["name"], state])
	part_title.text = "%s ─ %s" % [tool_def["name"], "  ".join(lines)]

	if part.is_empty():
		part_note.text = ""
	else:
		part_note.text = "%s: 〈%s〉を持つ素材で 魔力%d〜%d ─ %s" % [
			part["name"], ManaDB.nature_label(part["nature"]),
			int(part["min"]), int(part["max"]), part["note"]]

	# 部品を選ぶボタン(タイトル下に出す代わりに一覧の先頭へ)
	for c in part_stock.get_children():
		c.queue_free()
	for i in range(ToolDB.part_count(selected_tool)):
		var p := ToolDB.get_part(selected_tool, i)
		var idx := i
		var done := ToolDB.is_part_done(selected_tool, i)
		part_stock.add_child(UIRowFactory.make_item_row(
			ManaDB.nature_color(p["nature"]),
			"部品: %s 〈%s〉魔力%d〜%d%s" % [p["name"], ManaDB.nature_label(p["nature"]),
				int(p["min"]), int(p["max"]), "  ✓" if done else ""],
			"選ぶ", func(): _select_part(idx), done or i == selected_part))

	# その部品に使える素材だけを並べる
	if not part.is_empty() and not ToolDB.is_part_done(selected_tool, selected_part):
		for id in ItemDB.all_ids():
			if not ManaDB.has_nature(id, part["nature"]):
				continue
			var have := Inventory.get_count(id)
			if have <= 0:
				continue
			var iid: String = id
			part_stock.add_child(UIRowFactory.make_item_row(
				ItemDB.get_color(id),
				"%s  〈%s〉魔力%d  x%d" % [ItemDB.get_display_name(id),
					ManaDB.natures_label(id), ManaDB.get_mana(id), have],
				"入れる", func(): _add_to_part(iid)))

	for i in range(part_slot_row.get_child_count()):
		var b := part_slot_row.get_child(i) as Button
		if b == null:
			continue
		var id: String = part_slots[i] if i < part_slots.size() else ""
		b.text = "(空)" if id == "" else "%s\n魔力%d" % [ItemDB.get_display_name(id), ManaDB.get_mana(id)]

	var check := ToolDB.check_part(selected_tool, selected_part, part_slots)
	var part_done := ToolDB.is_part_done(selected_tool, selected_part)
	part_readout.text = "この部品はもうできている" if part_done else String(check["note"])
	part_button.visible = not part_done
	part_button.disabled = not bool(check["ok"])

	assemble_button.visible = ToolDB.all_parts_done(selected_tool)
	assemble_button.text = "魔力の回路をつなぐ(仕上げ)"

## 図鑑。検索語で絞り込める。ここから釜へ送る導線は置かない。
##
## いったん節(見出し + 行)を組み立ててから絞り込む。
## こうしないと「見出しは残っているが中身が全部消えた」節ができてしまう。
func _refresh_codex() -> void:
	for c in codex_list.get_children():
		c.queue_free()

	var query := search_edit.text.strip_edges().to_lower()
	var sections := _build_codex_sections()
	var shown := 0

	for section in sections:
		var hits: Array = []
		for line in section["lines"]:
			if query == "" or String(line).to_lower().contains(query):
				hits.append(line)
		if hits.is_empty():
			continue
		_add_codex_heading(section["title"])
		for line in hits:
			_add_codex_line(String(line))
			shown += 1

	if shown == 0:
		var l := Label.new()
		l.text = "「%s」に当たるものは見つからなかった。" % search_edit.text
		codex_list.add_child(l)

## 図鑑に載せる中身。節ごとに { "title": 見出し, "lines": [行, ...] }。
func _build_codex_sections() -> Array:
	var rules: Array = [
		"魔力の決まり: 素材はそれぞれ性質と魔力の強さを持つ。隣り合う素材は性質をひとつ以上共有していないと弾き合う。",
		"緩衝材: ふたつの性質を持つ素材は、本来つながらない性質どうしの橋渡しになる。触媒はどの性質にも馴染む。",
		"順番: 調合は入れた順番が意味を持つ。図鑑の並びどおりに入れること。",
		"魔力の量: 並びが合っていても、魔力の総量が帯に収まっていないと形にならない。",
		"道具: 道具は家の作業台でのみ組める。部品ごとに違う性質の魔力をまとわせ、すべて揃えたら魔力の回路をつないで仕上げる。",
	]

	var brews: Array = []
	for r in AlchemyDB.recipes:
		var labels: Array = []
		for n in r["sequence"]:
			labels.append(ManaDB.nature_label(n))
		if AlchemyDB.is_discovered(r["id"]):
			brews.append("%s ─ 並び〈%s〉 魔力%d〜%d ─ %s" % [
				r["name"], "・".join(labels), int(r["mana_min"]), int(r["mana_max"]),
				ItemDB.get_description(r["output_id"])])
		else:
			brews.append("？？？ ─ %s" % r["hint"])

	var blueprints: Array = []
	for t in ToolDB.tools:
		var parts: Array = []
		for p in t["parts"]:
			parts.append("%s〈%s〉魔力%d〜%d" % [p["name"], ManaDB.nature_label(p["nature"]),
				int(p["min"]), int(p["max"])])
		blueprints.append("%s ─ %s ─ %s" % [t["name"], "／".join(parts), t["blurb"]])

	# 緩衝材が「どの性質とどの性質をつなげるか」を書き出しておく。
	# 図鑑を読みながら並びを組み立てるとき、いちばん引きたくなる情報。
	var buffers: Array = []
	for id in ManaDB.mana_ids():
		if not ManaDB.is_buffer(id):
			continue
		var natures: Array = ManaDB.get_natures(id)
		if natures.size() >= ManaDB.NATURES.size():
			buffers.append("%s ─ どの性質にも馴染む。魔力%d。何と何のあいだにも挟める" % [
				ItemDB.get_display_name(id), ManaDB.get_mana(id)])
			continue
		var bridges: Array = []
		for i in range(natures.size()):
			for j in range(i + 1, natures.size()):
				bridges.append("〈%s〉と〈%s〉" % [
					ManaDB.nature_label(natures[i]), ManaDB.nature_label(natures[j])])
		buffers.append("%s 〈%s〉魔力%d ─ %sをつなげる" % [ItemDB.get_display_name(id),
			ManaDB.natures_label(id), ManaDB.get_mana(id), "、".join(bridges)])

	var materials: Array = []
	for id in ManaDB.mana_ids():
		var mark := "  ◆緩衝材" if ManaDB.is_buffer(id) else ""
		materials.append("%s 〈%s〉魔力%d%s ─ %s" % [ItemDB.get_display_name(id),
			ManaDB.natures_label(id), ManaDB.get_mana(id), mark, ItemDB.get_description(id)])

	# どこへ行けば採れるか。素材名でも土地名でも引けるようにしてある。
	var places: Array = []
	for area in AreaDB.AREAS:
		places.append("%s ─ %s %s" % [area["name"], area["blurb"], area["detail"]])
		for kind in ["herbs", "ores"]:
			var label := "薬草" if kind == "herbs" else "鉱石"
			for id in area[kind]:
				if not ManaDB.has_mana(id):
					continue
				places.append("%s の%s: %s 〈%s〉魔力%d" % [area["name"], label,
					ItemDB.get_display_name(id), ManaDB.natures_label(id), ManaDB.get_mana(id)])

	return [
		{"title": "魔力の決まりごと", "lines": rules},
		{"title": "調合の記録 (%d/%d)" % [AlchemyDB.discovered_count(), AlchemyDB.total_outputs()],
			"lines": brews},
		{"title": "道具の設計図", "lines": blueprints},
		{"title": "緩衝材の早見", "lines": buffers},
		{"title": "素材の性質", "lines": materials},
		{"title": "採れる場所", "lines": places},
	]

func _add_codex_heading(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	codex_list.add_child(l)

func _add_codex_line(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(900, 0)
	codex_list.add_child(l)

func _on_close() -> void:
	playing = false
	rhythm_box.visible = false
	circuit.visible = false
	_clear_cauldron()
	_clear_part_slots()
	EventBus.request_close_menus.emit()
