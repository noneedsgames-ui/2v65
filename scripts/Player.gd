extends CharacterBody2D
## 横スクロール操作、採集/施設インタラクションを行うプレイヤー本体。

const SPEED := 220.0
const JUMP_VELOCITY := -520.0  # 到達可能高さ ≈ 96px (プラットフォーム配置と整合させること)
const GRAVITY := 1400.0
const PATH_HISTORY_MAX := 600

var facing: int = 1
var nearby_interactables: Array = []
var path_history: PackedVector2Array = PackedVector2Array()

@onready var interaction_area: Area2D = $InteractionArea
@onready var visual: Node2D = $Visual

func _ready() -> void:
	add_to_group("player")
	interaction_area.area_entered.connect(_on_area_entered)
	interaction_area.area_exited.connect(_on_area_exited)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif velocity.y > 0:
		velocity.y = 0.0

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0:
		velocity.x = direction * SPEED
		facing = 1 if direction > 0 else -1
		visual.scale.x = facing * abs(visual.scale.x)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	_record_path()

	if Input.is_action_just_pressed("interact"):
		_try_interact()

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
