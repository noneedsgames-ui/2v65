class_name WorldRoot
extends Node2D
## 野外・町など各ワールドシーンの共通ルート。
## シーン遷移で指定されたスポーン位置にプレイヤーを移し、仲間もその足元へ寄せる。

@export var is_field: bool = false

# path_history など Player 固有のメンバーに触るので、あえて型を付けない
# (CharacterBody2D 型にすると unsafe property access の警告になる)。
@onready var player = $Player

func _ready() -> void:
	# 野外(初期シーン)のみ、起動時にセーブデータを読み込む。
	if is_field and not GameState.has_pending_spawn():
		if GameState.load_game():
			_place_player(GameState.player_spawn_position)
			return

	if GameState.has_pending_spawn():
		_place_player(GameState.pending_spawn)
		GameState.clear_pending_spawn()

func _place_player(pos: Vector2) -> void:
	player.global_position = pos
	# 移動履歴に転送前の座標が残っていると仲間が古い位置へ走り出すので捨てる
	player.path_history.clear()
	var companion := get_tree().get_first_node_in_group("companion")
	if companion:
		companion.global_position = pos + Vector2(-80, 0)
