extends Area2D
## 町の外れの分かれ道。調べると行き先(探索地)を選ぶ画面が開く。
## 触れただけでは移動しないので、うっかり出発してしまうことがない。

func _ready() -> void:
	add_to_group("interactable")

func get_prompt() -> String:
	return "探索へ出かける [E]"

func interact(_actor: Node) -> void:
	EventBus.request_open_area_select.emit()
