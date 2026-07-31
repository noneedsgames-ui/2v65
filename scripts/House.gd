extends Area2D
## 自宅。収納チェストの利用とベッドでのセーブ/ロードができる。

func _ready() -> void:
	add_to_group("interactable")

func get_prompt() -> String:
	return "家に入る(収納・セーブ) [E]"

func interact(_actor: Node) -> void:
	EventBus.request_open_house.emit()
