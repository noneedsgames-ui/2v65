extends Area2D
## マップ端などに置く遷移ポイント。プレイヤーが触れると別シーンへ移動する。
## auto_travel が false の場合は [E] で調べたときだけ移動する。

@export_file("*.tscn") var target_scene: String = ""
@export var spawn_position: Vector2 = Vector2(200, 380)
@export var label: String = "町へ行く"
@export var auto_travel: bool = true

var _traveling: bool = false

func _ready() -> void:
	add_to_group("interactable")
	if auto_travel:
		body_entered.connect(_on_body_entered)

func get_prompt() -> String:
	return "%s [E]" % label

func interact(_actor: Node) -> void:
	_travel()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_travel()

func _travel() -> void:
	if _traveling or target_scene == "":
		return
	_traveling = true
	EventBus.interact_prompt_hide.emit()
	GameState.travel_to(target_scene, spawn_position)
