extends Area2D
## 家の収納箱。持ち物との出し入れ画面を開く。

func _ready() -> void:
	add_to_group("interactable")

func get_prompt() -> String:
	return "収納箱をあける [E]"

func interact(_actor: Node) -> void:
	EventBus.request_open_chest.emit()
