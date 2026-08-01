extends CharacterBody2D
## 横スクロール操作、採集/施設インタラクションを行うプレイヤー本体。

const SPEED := 220.0
const ATTACK_RANGE := 82.0
const ATTACK_DAMAGE := 25
const ATTACK_COOLDOWN := 0.45
const JUMP_VELOCITY := -520.0  # 到達可能高さ ≈ 96px (プラットフォーム配置と整合させること)
const GRAVITY := 1400.0
const PATH_HISTORY_MAX := 600

## 壁ジャンプ。壁に触れて落下中は壁ずりで減速し、そこからもう一段跳べる。
const WALL_SLIDE_SPEED := 90.0
const WALL_JUMP_VELOCITY := -500.0
const WALL_KICK_SPEED := 260.0
## 壁を蹴った直後は入力で横速度を上書きしない時間。これが無いと
## 壁に向かって入力したままだと蹴った瞬間に壁へ戻ってしまう。
const WALL_KICK_LOCK := 0.16
## 壁から離れた直後の猶予(コヨーテタイム)
const WALL_COYOTE := 0.1

var facing: int = 1
var nearby_interactables: Array = []
var path_history: PackedVector2Array = PackedVector2Array()

## true の間は操作を受け付けない(店番中など)。重力と減速だけ働く。
var control_locked: bool = false

var _attack_timer: float = 0.0
var _wall_kick_timer: float = 0.0
var _wall_coyote_timer: float = 0.0
## 直前に触れていた壁の向き(1 = 右側に壁, -1 = 左側に壁)
var _wall_side: int = 0
var wall_sliding: bool = false

@onready var interaction_area: Area2D = $InteractionArea
@onready var visual: Node2D = $Visual

func _ready() -> void:
	add_to_group("player")
	interaction_area.area_entered.connect(_on_area_entered)
	interaction_area.area_exited.connect(_on_area_exited)
	EventBus.request_prompt_refresh.connect(_update_prompt)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif velocity.y > 0:
		velocity.y = 0.0

	if control_locked:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		move_and_slide()
		return

	_attack_timer -= delta
	_wall_kick_timer -= delta
	_update_wall_contact(delta)

	var direction := Input.get_axis("move_left", "move_right")

	# 壁ずり: 壁に触れて落下中なら、ゆっくり滑り降りる
	wall_sliding = false
	if not is_on_floor() and _wall_side != 0 and velocity.y > 0.0 \
			and _wall_coyote_timer > 0.0 and direction * _wall_side > 0.0:
		wall_sliding = true
		velocity.y = min(velocity.y, WALL_SLIDE_SPEED)

	if Input.is_action_just_pressed("attack") and _attack_timer <= 0.0:
		_do_attack()

	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
		elif _wall_side != 0 and _wall_coyote_timer > 0.0:
			_do_wall_jump()

	if _wall_kick_timer > 0.0:
		# 壁を蹴った直後は反発を優先し、入力での上書きを待つ
		if direction != 0:
			facing = 1 if direction > 0 else -1
			visual.scale.x = facing * abs(visual.scale.x)
	elif direction != 0:
		velocity.x = direction * SPEED
		facing = 1 if direction > 0 else -1
		visual.scale.x = facing * abs(visual.scale.x)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	_record_path()

	if Input.is_action_just_pressed("interact"):
		_try_interact()

## 壁との接触状況を更新する。is_on_wall_only() は床に居ないときだけ true になる。
func _update_wall_contact(delta: float) -> void:
	if is_on_floor():
		_wall_side = 0
		_wall_coyote_timer = 0.0
		return
	if is_on_wall_only():
		# 法線は壁からプレイヤーへ向く。右側に壁があれば法線は左(-1)を向く。
		var normal_x := get_wall_normal().x
		if absf(normal_x) > 0.5:
			_wall_side = -1 if normal_x > 0.0 else 1
			_wall_coyote_timer = WALL_COYOTE
			return
	_wall_coyote_timer -= delta
	if _wall_coyote_timer <= 0.0:
		_wall_side = 0

## 壁を蹴って反対側へ跳ぶ。
func _do_wall_jump() -> void:
	velocity.y = WALL_JUMP_VELOCITY
	velocity.x = -_wall_side * WALL_KICK_SPEED
	facing = -_wall_side
	visual.scale.x = facing * abs(visual.scale.x)
	_wall_kick_timer = WALL_KICK_LOCK
	_wall_coyote_timer = 0.0
	_wall_side = 0

## 向いている方向の近くの敵をまとめて叩く。
func _do_attack() -> void:
	_attack_timer = ATTACK_COOLDOWN
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var d: Vector2 = enemy.global_position - global_position
		if abs(d.y) < 90.0 and abs(d.x) < ATTACK_RANGE and d.x * facing >= -12.0:
			enemy.take_damage(ATTACK_DAMAGE, global_position)

## シーン遷移などで瞬間移動したときに呼ぶ。
## path_history は PackedVector2Array(値型)なので、外部から取得して clear() しても
## 複製が消えるだけで実体に効かない。必ずこのメソッド経由で消すこと。
func reset_path_history() -> void:
	path_history.clear()

func _record_path() -> void:
	path_history.append(global_position)
	if path_history.size() > PATH_HISTORY_MAX:
		path_history = path_history.slice(path_history.size() - PATH_HISTORY_MAX)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("interactable") and not nearby_interactables.has(area):
		nearby_interactables.append(area)
		_update_prompt()

func _on_area_exited(area: Area2D) -> void:
	if nearby_interactables.has(area):
		nearby_interactables.erase(area)
	_update_prompt()

func _get_nearest_interactable() -> Node:
	var nearest: Node = null
	var nearest_dist := INF
	for area in nearby_interactables:
		if not is_instance_valid(area):
			continue
		var d := global_position.distance_to(area.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = area
	return nearest

func _update_prompt() -> void:
	var target := _get_nearest_interactable()
	if target and target.has_method("get_prompt"):
		var text: String = target.get_prompt()
		if text == "":
			EventBus.interact_prompt_hide.emit()
		else:
			EventBus.interact_prompt_show.emit(text)
	else:
		EventBus.interact_prompt_hide.emit()

func _try_interact() -> void:
	var target := _get_nearest_interactable()
	if target and target.has_method("interact"):
		target.interact(self)
		_update_prompt()
