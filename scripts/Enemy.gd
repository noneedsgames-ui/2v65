extends CharacterBody2D
## 奥の森に棲むけもの。範囲を巡回し、近づいたプレイヤーに噛みつく。
## J の攻撃で倒せる。頭上に HP バーを出す。

const GRAVITY := 1400.0

@export var max_hp: int = 60
@export var contact_damage: int = 12
@export var move_speed: float = 70.0
@export var patrol_min_x: float = 0.0
@export var patrol_max_x: float = 100000.0
@export var drop_id: String = "fiber"
@export var drop_min: int = 1
@export var drop_max: int = 2

var hp: int = 60
var direction: int = 1
var _hit_cooldown: float = 0.0
var _player = null

@onready var visual: Node2D = $Visual
@onready var hp_fill: Polygon2D = $HPBar/Fill

func _ready() -> void:
	add_to_group("enemy")
	hp = max_hp
	direction = 1 if randf() < 0.5 else -1
	move_speed *= randf_range(0.85, 1.15)
	call_deferred("_find_player")

func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

	_hit_cooldown -= delta
	velocity.x = direction * move_speed
	if global_position.x <= patrol_min_x or is_on_wall():
		direction = 1
	elif global_position.x >= patrol_max_x:
		direction = -1

	move_and_slide()
	if velocity.x > 1.0:
		visual.scale.x = abs(visual.scale.x)
	elif velocity.x < -1.0:
		visual.scale.x = -abs(visual.scale.x)

	# 接触ダメージ(体当たりの物理衝突はレイヤーで切ってあるので距離で判定)
	if _player != null and is_instance_valid(_player) and _hit_cooldown <= 0.0:
		var d: Vector2 = _player.global_position - global_position
		if abs(d.x) < 46.0 and abs(d.y) < 70.0:
			_hit_cooldown = 0.9
			GameState.damage_player(contact_damage)

func take_damage(amount: int, from_position: Vector2) -> void:
	hp -= amount
	# のけぞり
	global_position.x += 18.0 * (1.0 if global_position.x >= from_position.x else -1.0)
	hp_fill.scale.x = clampf(float(hp) / float(max_hp), 0.0, 1.0)
	visual.modulate = Color(1, 0.5, 0.5, 1)
	create_tween().tween_property(visual, "modulate", Color(1, 1, 1, 1), 0.25)
	if hp <= 0:
		_die()

func _die() -> void:
	var amount := randi_range(drop_min, drop_max)
	Inventory.add_item(drop_id, amount)
	EventBus.notify.emit("けものを追い払った！ %s +%d" % [ItemDB.get_display_name(drop_id), amount])
	queue_free()
