extends Node2D
## ワールドのエントリポイント。セーブデータがあれば起動時に復元する。

@onready var player: CharacterBody2D = $Player

func _ready() -> void:
	# オートロード(_ready)はメインシーンより先に初期化済みなので、ここで安全に復元できる。
	if GameState.load_game():
		player.global_position = GameState.player_spawn_position
