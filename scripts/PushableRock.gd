extends Area2D
## 道をふさぐ大岩の「調べる」ゾーン。相棒が近くにいれば押してどかしてもらえる。
## スクリプトはこのゾーンに付け、親ノード(岩全体)を動かす。

## 押す距離。既定は奥の森の落とし穴(幅140・深さ170)にはまる値。
@export var push_offset: Vector2 = Vector2(150, 170)

const COMPANION_RANGE := 280.0

var pushed: bool = false

func _ready() -> void:
	add_to_group("interactable")

func get_prompt() -> String:
	return "" if pushed else "相棒に岩を押してもらう [E]"

func interact(_actor: Node) -> void:
	if pushed:
		return
	var companion := get_tree().get_first_node_in_group("companion") as Node2D
	if companion == null or companion.global_position.distance_to(global_position) > COMPANION_RANGE:
		EventBus.notify.emit("相棒が近くに来るまで待とう")
		return
	pushed = true
	EventBus.companion_say.emit("よーし、任せて。……ぬおおお、よいしょーっ！")
	var rock := get_parent() as Node2D
	# 横に押してから穴に落とす(順番に実行される)
	var tween := create_tween()
	tween.tween_property(rock, "position:x", rock.position.x + push_offset.x, 1.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if push_offset.y != 0.0:
		tween.tween_property(rock, "position:y", rock.position.y + push_offset.y, 0.4) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func(): EventBus.notify.emit("岩が穴にはまって道ができた！"))
	EventBus.interact_prompt_hide.emit()
