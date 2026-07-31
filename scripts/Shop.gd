extends Area2D
## NPCの店。アイテムの購入・売却ができる。

func _ready() -> void:
	add_to_group("interactable")

func get_prompt() -> String:
	return "お店で売買する [E]"

func interact(_actor: Node) -> void:
	EventBus.request_open_shop.emit()
