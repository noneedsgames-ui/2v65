extends Area2D
## 家のベッド。眠るとセーブする。
## 風呂上がりのさっぱり感は寝ると翌日になって解ける。

## 次にゲームを始めたときに立っている場所(野原シーンの座標)。
@export var wake_position: Vector2 = Vector2(380, 380)

func _ready() -> void:
	add_to_group("interactable")

func get_prompt() -> String:
	return "ベッドで眠る(セーブ) [E]"

func interact(_actor: Node) -> void:
	GameState.player_spawn_position = wake_position
	GameState.set_refreshed(false)
	GameState.restore_player_hp()
	GameState.save_game()
	EventBus.companion_say.emit("おやすみ。明日もいい採集日和だといいね。")
