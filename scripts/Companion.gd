extends CharacterBody2D
## プレイヤーの2倍の背丈を持つ追従サブキャラクター。
## 普段はプレイヤーの過去の移動履歴(path_history)を辿って追いかけ、
## ジャンプの軌道もそのまま再現する。
## 近くに敵がいるときは追従をやめ、割って入って殴りかかる。

@export var follow_gap: int = 50       # プレイヤー履歴のどれだけ後ろを追うか(フレーム数)
@export var move_speed: float = 250.0
@export var teleport_distance: float = 900.0
@export var stop_threshold: float = 4.0

## 戦闘。体が大きいぶん一発が重く、手数は遅い。
@export var attack_damage: int = 18
@export var attack_cooldown: float = 1.1
@export var attack_reach: float = 90.0
## この距離までの敵に反応する。プレイヤーから離れすぎては追わない。
@export var aggro_range: float = 300.0
@export var max_distance_from_player: float = 420.0

var player = null

var _attack_timer: float = 0.0
var _target = null

@onready var visual: Node2D = $Visual

func _ready() -> void:
	add_to_group("companion")
	call_deferred("_find_player")

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_find_player()
		return

	_attack_timer -= delta
	_target = _pick_target()
	if _target != null:
		_fight(_target)
	else:
		_follow_player()

	move_and_slide()

## プレイヤーの近くにいる敵のうち、自分に最も近いものを狙う。
func _pick_target():
	var best = null
	var best_dist := aggro_range
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		# プレイヤーから離れすぎた敵は放っておく(はぐれ防止)
		if enemy.global_position.distance_to(player.global_position) > max_distance_from_player:
			continue
		var d := global_position.distance_to(enemy.global_position)
		if d < best_dist:
			best_dist = d
			best = enemy
	return best

func _fight(target) -> void:
	var to_target: Vector2 = target.global_position - global_position
	_face(to_target.x)

	if abs(to_target.x) > attack_reach * 0.7:
		# 敵とプレイヤーの間に体を入れるように寄る
		velocity.x = signf(to_target.x) * move_speed * 0.8
		velocity.y = move_toward(velocity.y, 0.0, move_speed)
	else:
		velocity = Vector2.ZERO
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			target.take_damage(attack_damage, global_position)
			_swing()

## 敵に噛まれたとき。体が大きいのでダメージは受けず、ひるんで押し戻されるだけ。
## プレイヤーの盾になるための挙動。
func on_bitten() -> void:
	visual.modulate = Color(1, 0.7, 0.7, 1)
	create_tween().tween_property(visual, "modulate", Color(1, 1, 1, 1), 0.3)
	EventBus.companion_say.emit("いてて…！ こっちは平気、下がってて！")

## 殴るときに体を少し傾けて、当たったことが見えるようにする。
func _swing() -> void:
	var tween := create_tween()
	tween.tween_property(visual, "rotation", 0.22 * signf(visual.scale.x), 0.08)
	tween.tween_property(visual, "rotation", 0.0, 0.16)

func _follow_player() -> void:
	var history: PackedVector2Array = player.path_history
	if history.size() == 0:
		velocity = Vector2.ZERO
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
		_face(to_target.x)
	else:
		velocity = Vector2.ZERO

func _face(dx: float) -> void:
	if dx > 4.0:
		visual.scale.x = abs(visual.scale.x)
	elif dx < -4.0:
		visual.scale.x = -abs(visual.scale.x)
