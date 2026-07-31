extends Area2D
## 町の広場に構えるプレイヤーの露店。
## 売れるのは町人(TownNPC)が実際に歩いて来たときだけで、
## 一定確率で代金を払わずに持ち去られる(万引き)。
##
## 「店番」を始めるとプレイヤーは露店の内側に固定され、呼び込みミニゲームになる。
## F で呼び込み → 声の届く範囲の町人が買いに来る。店番中は目が届くので万引きされない。

const STALL_KIT_ID := "stall_kit"

@export var call_range: float = 620.0
@export var call_cooldown: float = 2.2
@export var call_attract_chance: float = 0.7

var tending: bool = false
var _call_timer: float = 0.0
var _tending_customers: int = 0
var _tending_gold: int = 0
var _player = null  # control_locked を触るため型は付けない

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("player_stall")
	EventBus.request_start_tending.connect(start_tending)

func _process(delta: float) -> void:
	if tending and _call_timer > 0.0:
		_call_timer -= delta

func get_prompt() -> String:
	if not Inventory.has_item(STALL_KIT_ID):
		return "露店 (%sが必要)" % ItemDB.get_display_name(STALL_KIT_ID)
	return "露店を管理する [E]"

func interact(_actor: Node) -> void:
	if not Inventory.has_item(STALL_KIT_ID):
		EventBus.notify.emit("%sがあれば露店を開けます" % ItemDB.get_display_name(STALL_KIT_ID))
		return
	EventBus.request_open_stall.emit()

# ---- 店番(呼び込みミニゲーム) ----

func start_tending() -> void:
	if tending:
		return
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	tending = true
	_call_timer = 0.0
	_tending_customers = 0
	_tending_gold = 0
	_player.control_locked = true
	_player.global_position = global_position
	EventBus.interact_prompt_hide.emit()
	EventBus.tending_started.emit()
	EventBus.tending_stats.emit(0, 0)
	EventBus.companion_say.emit("店番だね。Fで呼び込み！ 大きな声でいこう。")

func stop_tending() -> void:
	if not tending:
		return
	tending = false
	if _player != null and is_instance_valid(_player):
		_player.control_locked = false
	_player = null
	EventBus.tending_ended.emit()
	EventBus.notify.emit("店番おわり: %d人に売れて +%dG" % [_tending_customers, _tending_gold])
	# その場に立ったままでも「露店を管理する [E]」が戻るようにする
	EventBus.request_prompt_refresh.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not tending:
		return
	if event.is_action_pressed("use_item"):
		_call_out()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		stop_tending()
		get_viewport().set_input_as_handled()

func _call_out() -> void:
	if _call_timer > 0.0:
		return
	_call_timer = call_cooldown
	EventBus.notify.emit("「いらっしゃいませー！」")
	if not has_stock():
		EventBus.companion_say.emit("その前に、売り物を並べないと…")
		return
	var attracted := 0
	for npc in get_tree().get_nodes_in_group("townsfolk"):
		if abs(npc.global_position.x - global_position.x) > call_range:
			continue
		if randf() < call_attract_chance and npc.attract_to_stall():
			attracted += 1
	if attracted > 0:
		EventBus.notify.emit("%d人がこちらに気づいた！" % attracted)

# ---- 町人との取引 ----

func has_stock() -> bool:
	for entry in GameState.stall_items:
		if int(entry["count"]) > 0:
			return true
	return false

func _random_stocked_index() -> int:
	var candidates: Array = []
	for i in range(GameState.stall_items.size()):
		if int(GameState.stall_items[i]["count"]) > 0:
			candidates.append(i)
	if candidates.is_empty():
		return -1
	return candidates[randi() % candidates.size()]

## 町人ひとりぶんの取引を処理する。steal_chance の確率で万引きになるが、
## 店番中は店主が見ているので必ず代金を払う。
func serve_customer(steal_chance: float) -> void:
	var idx := _random_stocked_index()
	if idx < 0:
		return

	var entry: Dictionary = GameState.stall_items[idx]
	var quantity: int = min(int(entry["count"]), randi_range(1, 2))
	entry["count"] = int(entry["count"]) - quantity

	var item_name := ItemDB.get_display_name(entry["id"])
	var message := ""
	if not tending and randf() < steal_chance:
		message = "万引き! %sを%d個盗まれた" % [item_name, quantity]
		EventBus.companion_say.emit("あっ、今の人お金払ってないよ！ 追いかける？")
	else:
		var earned: int = int(entry["price"]) * quantity
		Inventory.add_gold(earned)
		message = "%sが%d個売れた (+%dG)" % [item_name, quantity, earned]
		if tending:
			_tending_customers += 1
			_tending_gold += earned
			EventBus.tending_stats.emit(_tending_customers, _tending_gold)

	GameState.stall_earnings_log.append(message)
	if GameState.stall_earnings_log.size() > 20:
		GameState.stall_earnings_log.remove_at(0)
	EventBus.notify.emit(message)

	if int(entry["count"]) <= 0:
		GameState.stall_items.remove_at(idx)
