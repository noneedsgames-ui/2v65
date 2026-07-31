extends Control
## 店番中、通行人が話しかけてくる接客交渉。
## 手順その1、求められた品を台の上の在庫から正しく選んで渡す。
## 手順その2、そのまま売る / 値上げ交渉 / 抱き合わせ提案 のいずれかで商談をまとめる。

const RAISE_MULT := 1.4
const RAISE_SUCCESS := 0.55
const BUNDLE_SUCCESS := 0.5
## 客が値下げを要求してくる確率と、その割引率
const DISCOUNT_DEMAND_CHANCE := 0.35
const DISCOUNT_MULT := 0.7
## 値下げを断られた客が逆上して品物を掴んで逃げる確率
const RAMPAGE_CHANCE := 0.35

var request: Dictionary = {}
var stage: String = "item"
var strikes: int = 0
var discount_demand: bool = false

@onready var say_label: Label = $Center/Window/Margin/Content/SayLabel
@onready var info_label: Label = $Center/Window/Margin/Content/InfoLabel
@onready var choices: VBoxContainer = $Center/Window/Margin/Content/Choices

## 開く前に UIRoot から呼ばれる。
func set_request(req: Dictionary) -> void:
	request = req
	stage = "item"
	strikes = 0
	discount_demand = randf() < DISCOUNT_DEMAND_CHANCE

func refresh() -> void:
	_build_stage()

func _clear_choices() -> void:
	for c in choices.get_children():
		c.queue_free()

func _add_choice(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 38)
	b.pressed.connect(cb)
	choices.add_child(b)

func _base_total() -> int:
	return int(request["unit_price"]) * int(request["qty"])

func _build_stage() -> void:
	_clear_choices()
	if stage == "item":
		say_label.text = "「すみません、%sを%d個もらえるかい？」" % \
			[ItemDB.get_display_name(request["id"]), int(request["qty"])]
		info_label.text = "台の上から正しい品を渡そう"
		var ids: Array = []
		for entry in GameState.stall_items:
			if int(entry["count"]) > 0 and not ids.has(entry["id"]):
				ids.append(entry["id"])
		ids.shuffle()
		for id in ids.slice(0, 4):
			var iid: String = id
			_add_choice(ItemDB.get_display_name(iid), func(): _pick_item(iid))
	elif stage == "discount":
		var base := _base_total()
		var offer := int(base * DISCOUNT_MULT)
		say_label.text = "「それそれ！ でもちょっと高いな…%dGに負けてくれない？」" % offer
		info_label.text = "値下げに応じる？ 断ると怒るかも…"
		_add_choice("値下げに応じる (%dG)" % offer, func(): _sell_at(offer, "まけておいた (+%dG)" % offer))
		_add_choice("断る(定価 %dG を主張)" % base, _refuse_discount)
	else:
		var base := _base_total()
		say_label.text = "「それそれ！ %dGでいいかい？」" % base
		info_label.text = "売り方を選ぼう"
		_add_choice("この値段で売る (%dG)" % base, _sell_base)
		_add_choice("強気に値上げする (%dG)" % int(base * RAISE_MULT), _try_raise)
		var other := _pick_other_id()
		if other != "":
			_add_choice("抱き合わせを提案する (+%s)" % ItemDB.get_display_name(other),
				func(): _try_bundle(other))
		_add_choice("売らない", func(): _finish(0, "客は肩をすくめて去っていった"))

func _pick_item(id: String) -> void:
	if id == request["id"]:
		stage = "discount" if discount_demand else "deal"
		_build_stage()
		return
	strikes += 1
	if strikes >= 2:
		_finish(0, "「もういいよ…」品を間違えて、客は呆れて帰ってしまった")
	else:
		say_label.text = "「いやいや、それじゃなくて…%sだってば」" % ItemDB.get_display_name(request["id"])

func _pick_other_id() -> String:
	var candidates: Array = []
	for entry in GameState.stall_items:
		if int(entry["count"]) > 0 and entry["id"] != request["id"] and not candidates.has(entry["id"]):
			candidates.append(entry["id"])
	if candidates.is_empty():
		return ""
	return candidates[randi() % candidates.size()]

func _take_stock(id: String, qty: int) -> bool:
	for i in range(GameState.stall_items.size()):
		var entry = GameState.stall_items[i]
		if entry["id"] == id and int(entry["count"]) >= qty:
			entry["count"] = int(entry["count"]) - qty
			if int(entry["count"]) <= 0:
				GameState.stall_items.remove_at(i)
			return true
	return false

func _stock_price(id: String) -> int:
	for entry in GameState.stall_items:
		if entry["id"] == id:
			return int(entry["price"])
	return 0

func _sell_base() -> void:
	var total := _base_total()
	if _take_stock(request["id"], int(request["qty"])):
		_finish(total, "%sを%d個売った (+%dG)" % \
			[ItemDB.get_display_name(request["id"]), int(request["qty"]), total])
	else:
		_finish(0, "在庫が足りなかった…")

func _sell_at(total: int, message: String) -> void:
	if _take_stock(request["id"], int(request["qty"])):
		_finish(total, message)
	else:
		_finish(0, "在庫が足りなかった…")

## 値下げを断る。客はたいてい折れるが、たまに逆上して品物を掴んで逃げる。
func _refuse_discount() -> void:
	var roll := randf()
	if roll < RAMPAGE_CHANCE:
		var npc = request.get("npc")
		if npc != null and is_instance_valid(npc):
			npc.start_theft_run()
			EventBus.companion_say.emit("わっ、逆上した！ 品物を掴む気だ、止めて！")
			_finish(0, "「けちんぼ！」客が逆上して台に手を伸ばした！")
		else:
			_finish(0, "「けちんぼ！」客は怒って帰ってしまった")
	elif roll < 0.7:
		var total := _base_total()
		_sell_at(total, "「…わかったよ、それで頼む」定価で売れた (+%dG)" % total)
	else:
		_finish(0, "「じゃあいいや」客は去っていった")

func _try_raise() -> void:
	if randf() < RAISE_SUCCESS:
		var total := int(_base_total() * RAISE_MULT)
		if _take_stock(request["id"], int(request["qty"])):
			_finish(total, "交渉成立！ 高値で売れた (+%dG)" % total)
		else:
			_finish(0, "在庫が足りなかった…")
	elif randf() < 0.5:
		var total := _base_total()
		if _take_stock(request["id"], int(request["qty"])):
			_finish(total, "「高いなあ、元の値段なら」— 定価で売れた (+%dG)" % total)
		else:
			_finish(0, "在庫が足りなかった…")
	else:
		_finish(0, "「高すぎるよ！」客は怒って帰ってしまった")

func _try_bundle(other_id: String) -> void:
	var other_price := _stock_price(other_id)
	if randf() < BUNDLE_SUCCESS:
		var total := _base_total() + other_price
		if _take_stock(request["id"], int(request["qty"])) and _take_stock(other_id, 1):
			_finish(total, "抱き合わせ成功！ %sも一緒に売れた (+%dG)" % \
				[ItemDB.get_display_name(other_id), total])
		else:
			_finish(0, "在庫が足りなかった…")
	else:
		var total := _base_total()
		if _take_stock(request["id"], int(request["qty"])):
			_finish(total, "「それは要らないかな」— 本命だけ売れた (+%dG)" % total)
		else:
			_finish(0, "在庫が足りなかった…")

func _finish(gold: int, text: String) -> void:
	if gold > 0:
		Inventory.add_gold(gold)
	EventBus.notify.emit(text)
	EventBus.negotiation_finished.emit(gold, text)
	EventBus.request_close_menus.emit()
