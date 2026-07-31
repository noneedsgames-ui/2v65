extends Area2D
## 家の風呂。入るとさっぱりして、次に寝るまで採集量が増える。

func _ready() -> void:
	add_to_group("interactable")

func get_prompt() -> String:
	if GameState.refreshed:
		return "風呂 (もうさっぱりしている)"
	return "風呂に入る [E]"

func interact(_actor: Node) -> void:
	if GameState.refreshed:
		EventBus.notify.emit("もうさっぱりしている")
		return
	GameState.set_refreshed(true)
	GameState.restore_player_hp()
	EventBus.notify.emit("ひと風呂浴びた。HPが全回復し、採集量+%d(次に寝るまで)" % GameState.REFRESHED_GATHER_BONUS)
	EventBus.companion_say.emit("いいお湯だったね。体が軽いや。")
