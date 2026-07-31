extends CharacterBody2D
## 町を自律的に歩き回る町人。
## 露店に在庫があると、ときどき興味を持って歩いて来て買っていく。
## ただし一定確率で代金を払わずに持ち去る(万引き)。
## 店番中はさらに、露店を狙う泥棒として走ってくることがある。
## 品物を掴んで逃げるので、プレイヤーは走って追いつけば取り返せる。

enum State { WANDER, PAUSE, APPROACH_STALL, BROWSE, THIEF_APPROACH, FLEE }

const GRAVITY := 1400.0
## 逃走速度。プレイヤーの走り(220)より少し遅く、追えば捕まえられる。
const FLEE_SPEED := 185.0
const CATCH_DISTANCE := 48.0
const FLEE_TIME_LIMIT := 12.0

@export var walk_speed: float = 55.0
@export var patrol_min_x: float = 120.0
@export var patrol_max_x: float = 2400.0
## 判断のたびに露店へ向かう確率
@export var stall_interest_chance: float = 0.45
## 買い物客が万引きに走る確率
@export var shoplift_chance: float = 0.18
@export var browse_seconds: float = 1.6

var state: int = State.WANDER
var direction: int = 1
var _state_timer: float = 0.0
var _decision_timer: float = 0.0
var _stall = null   # Stall.gd 固有のメソッドを呼ぶため型は付けない
var _player = null
var _flee_timer: float = 0.0
var _stolen: Array = []  # 逃走中に抱えている品 [{id, count, price}]

@onready var visual: Node2D = $Visual

func _ready() -> void:
	add_to_group("townsfolk")
	direction = 1 if randf() < 0.5 else -1
	walk_speed *= randf_range(0.8, 1.25)
	_decision_timer = randf_range(2.0, 7.0)
	_randomize_look()
	call_deferred("_find_stall")

func _find_stall() -> void:
	_stall = get_tree().get_first_node_in_group("player_stall")

## 町人ごとに服と肌の色を少し変えて、群衆に見えるようにする。
func _randomize_look() -> void:
	var shirt := Color.from_hsv(randf(), randf_range(0.35, 0.7), randf_range(0.55, 0.9))
	var trousers := Color.from_hsv(randf(), randf_range(0.2, 0.5), randf_range(0.25, 0.5))
	var skin := Color.from_hsv(randf_range(0.05, 0.11), randf_range(0.25, 0.45), randf_range(0.75, 0.95))
	$Visual/Body.color = shirt
	$Visual/Legs.color = trousers
	$Visual/Head.color = skin
	# 背丈にも個体差をつける
	visual.scale.y = randf_range(0.9, 1.12)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

	match state:
		State.WANDER:
			_process_wander(delta)
		State.PAUSE:
			_process_pause(delta)
		State.APPROACH_STALL:
			_process_approach(delta)
		State.BROWSE:
			_process_browse(delta)
		State.THIEF_APPROACH:
			_process_thief_approach(delta)
		State.FLEE:
			_process_flee(delta)

	move_and_slide()
	if velocity.x > 1.0:
		visual.scale.x = abs(visual.scale.x)
	elif velocity.x < -1.0:
		visual.scale.x = -abs(visual.scale.x)

## 呼び込みに反応して露店へ向かわせる。すでに向かっている/品定め中なら false。
func attract_to_stall() -> bool:
	if _stall == null or not is_instance_valid(_stall) or not _stall.has_stock():
		return false
	if state != State.WANDER and state != State.PAUSE:
		return false
	state = State.APPROACH_STALL
	return true

## 泥棒として露店を狙わせる(店番イベントから呼ばれる)。
func start_theft_run() -> bool:
	if state == State.THIEF_APPROACH or state == State.FLEE:
		return false
	if _stall == null or not is_instance_valid(_stall) or not _stall.has_stock():
		return false
	state = State.THIEF_APPROACH
	return true

func can_become_thief() -> bool:
	return state == State.WANDER or state == State.PAUSE

func _process_wander(delta: float) -> void:
	velocity.x = direction * walk_speed
	if global_position.x <= patrol_min_x:
		direction = 1
	elif global_position.x >= patrol_max_x:
		direction = -1

	_decision_timer -= delta
	if _decision_timer <= 0.0:
		_decision_timer = randf_range(3.0, 8.0)
		if _stall != null and is_instance_valid(_stall) and _stall.has_stock() \
				and randf() < stall_interest_chance:
			state = State.APPROACH_STALL
		elif randf() < 0.35:
			state = State.PAUSE
			_state_timer = randf_range(0.8, 2.5)
		else:
			direction = -direction

func _process_pause(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, walk_speed)
	_state_timer -= delta
	if _state_timer <= 0.0:
		state = State.WANDER

func _process_approach(_delta: float) -> void:
	if _stall == null or not is_instance_valid(_stall) or not _stall.has_stock():
		state = State.WANDER
		return
	# _stall は未型付け(Variant)なので := では型推論できない。明示的に float を指定する。
	var dx: float = _stall.global_position.x - global_position.x
	if abs(dx) < 36.0:
		velocity.x = 0.0
		state = State.BROWSE
		_state_timer = browse_seconds
		return
	direction = 1 if dx > 0.0 else -1
	velocity.x = direction * walk_speed

func _process_browse(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, walk_speed)
	_state_timer -= delta
	if _state_timer > 0.0:
		return
	if _stall != null and is_instance_valid(_stall):
		_stall.serve_customer(shoplift_chance, self)
	state = State.WANDER
	_decision_timer = randf_range(5.0, 12.0)
	direction = 1 if randf() < 0.5 else -1

func _process_thief_approach(_delta: float) -> void:
	if _stall == null or not is_instance_valid(_stall) or not _stall.has_stock():
		state = State.WANDER
		return
	var dx: float = _stall.global_position.x - global_position.x
	if abs(dx) < 34.0:
		_grab_and_run()
		return
	direction = 1 if dx > 0.0 else -1
	velocity.x = direction * FLEE_SPEED * 0.8

func _grab_and_run() -> void:
	_stolen = _stall.on_theft_grab()
	if _stolen.is_empty():
		state = State.WANDER
		return
	_player = get_tree().get_first_node_in_group("player")
	# プレイヤーと反対側へ逃げる(重なっていたらランダム)
	var away := 0.0
	if _player != null:
		away = global_position.x - _player.global_position.x
	direction = 1 if (away > 2.0 or (abs(away) <= 2.0 and randf() < 0.5)) else -1
	_flee_timer = FLEE_TIME_LIMIT
	state = State.FLEE

func _process_flee(delta: float) -> void:
	velocity.x = direction * FLEE_SPEED
	_flee_timer -= delta

	if _player != null and is_instance_valid(_player) \
			and global_position.distance_to(_player.global_position) < CATCH_DISTANCE:
		_on_caught()
		return

	if _flee_timer <= 0.0 \
			or global_position.x <= patrol_min_x - 40.0 \
			or global_position.x >= patrol_max_x + 40.0:
		_on_escaped()

func _on_caught() -> void:
	for entry in _stolen:
		GameState.stall_add_item(entry["id"], int(entry["count"]), int(entry["price"]))
	EventBus.notify.emit("泥棒を捕まえた！ 品物を取り返した")
	EventBus.companion_say.emit("ナイス追走！ 品物は台に戻しておいたよ。")
	_stolen = []
	velocity.x = 0.0
	# しばらくその場でしょんぼりしてから立ち去る
	state = State.PAUSE
	_state_timer = 2.0

func _on_escaped() -> void:
	if not _stolen.is_empty():
		var names: Array = []
		for entry in _stolen:
			names.append("%s x%d" % [ItemDB.get_display_name(entry["id"]), int(entry["count"])])
		EventBus.notify.emit("逃げられた… %s を失った" % "、".join(names))
		EventBus.companion_say.emit("くっ、足が速い…。次は早めに追いかけよう。")
	_stolen = []
	state = State.WANDER
	_decision_timer = randf_range(6.0, 12.0)
