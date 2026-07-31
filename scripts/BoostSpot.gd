extends Area2D
## 高い段差の下に置くスポット。相棒が近くにいれば、
## プレイヤーを肩に乗せて上まで引き上げてくれる。

@export var target_position: Vector2 = Vector2.ZERO

const COMPANION_RANGE := 280.0

func _ready() -> void:
	add_to_group("interactable")

func get_prompt() -> String:
	return "相棒に引き上げてもらう [E]"

func interact(actor: Node) -> void:
	var companion := get_tree().get_first_node_in_group("companion") as Node2D
	if companion == null or companion.global_position.distance_to(global_position) > COMPANION_RANGE:
		EventBus.notify.emit("相棒が近くに来るまで待とう")
		return
	EventBus.companion_say.emit("肩に乗って！ ……せーのっ！")
	actor.global_position = target_position
	if actor.has_method("reset_path_history"):
		actor.reset_path_history()
	EventBus.interact_prompt_hide.emit()
