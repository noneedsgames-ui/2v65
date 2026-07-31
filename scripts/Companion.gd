extends CharacterBody2D
## プレイヤーの2倍の背丈を持つ追従サブキャラクター。
## プレイヤーの過去の移動履歴(path_history)を辿ることでジャンプの軌道も再現する。

@export var follow_gap: int = 50       # プレイヤー履歴のどれだけ後ろを追うか(フレーム数)
@export var move_speed: float = 250.0
@export var teleport_distance: float = 900.0
@export var stop_threshold: float = 4.0

var player = null

@onready var visual: Node2D = $Visual

func _ready() -> void:
	add_to_group("companion")
	call_deferred("_find_player")

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player")

func _physics_process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_find_player()
		return

	var history: PackedVector2Array = player.path_history
	if history.size() == 0:
		return

	var idx: int = max(0, history.size() - 1 - follow_gap)
	var target: Vector2 = history[idx]

	if global_position.distance_to(target) > teleport_distance:
		global_position = target
		velocity = Vector2.ZERO
		return

	var to_target := target - global_position
	if to_target.length() > stop_threshold:
		velocity = to_target.normalized() * move_speed
		if to_target.x > 4.0:
			visual.scale.x = abs(visual.scale.x)
		elif to_target.x < -4.0:
			visual.scale.x = -abs(visual.scale.x)
	else:
		velocity = Vector2.ZERO

	move_and_slide()
