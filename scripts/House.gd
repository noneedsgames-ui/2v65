extends Area2D
## 自宅の外観。調べると家の中へ入る。

@export var spawn_position: Vector2 = Vector2(200, 380)

func _ready() -> void:
	add_to_group("interactable")

func get_prompt() -> String:
	return "家に入る [E]"

func interact(_actor: Node) -> void:
	GameState.travel_to(GameState.HOUSE_SCENE, spawn_position)
