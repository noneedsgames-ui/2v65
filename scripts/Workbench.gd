extends Area2D
## 家の作業台。工房を開く。ここからだけ道具設計ができる。

func _ready() -> void:
	add_to_group("interactable")

func get_prompt() -> String:
	return "作業台で調合・道具づくり [E]"

func interact(_actor: Node) -> void:
	EventBus.request_open_workshop.emit(true)
