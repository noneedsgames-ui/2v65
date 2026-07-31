extends Area2D
## 家の作業台。クラフト画面を開く。

func _ready() -> void:
	add_to_group("interactable")

func get_prompt() -> String:
	return "作業台で作る [E]"

func interact(_actor: Node) -> void:
	EventBus.request_open_crafting.emit()
