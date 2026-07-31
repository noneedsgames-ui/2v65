extends CharacterBody2D
## 町を自律的に歩き回る町人。
## 露店に在庫があると、ときどき興味を持って歩いて来て買っていく。
## ただし一定確率で代金を払わずに持ち去る(万引き)。

enum State { WANDER, PAUSE, APPROACH_STALL, BROWSE }

const GRAVITY := 1400.0

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
var _stall = null  # Stall.gd 固有のメソッドを呼ぶため型は付けない

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

	move_and_slide()
	if velocity.x > 1.0:
		visual.scale.x = abs(visual.scale.x)
	elif velocity.x < -1.0:
		visual.scale.x = -abs(visual.scale.x)

## 呼び込みに反応して露店へ向かわせる。すでに向かっている/品定め中なら false。
func attract_to_stall() -> bool:
	if _stall == null or not is_instance_valid(_stall) or not _stall.has_stock():
		return false
	if state == State.APPROACH_STALL or state == State.BROWSE:
		return false
	state = State.APPROACH_STALL
	return true

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
		_stall.serve_customer(shoplift_chance)
	state = State.WANDER
	_decision_timer = randf_range(5.0, 12.0)
	direction = 1 if randf() < 0.5 else -1
