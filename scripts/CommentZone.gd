extends Area2D
## プレイヤーが通りかかると同行者がひとこと言う範囲。
## 同じ場所で言い続けないよう、once か cooldown で間隔を空ける。

@export var lines: PackedStringArray = PackedStringArray()
## true なら1回だけ喋る(シーンを出入りするとまた喋る)
@export var once: bool = false
@export var cooldown_seconds: float = 25.0

var _spoken: bool = false
var _last_msec: int = -1000000

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or lines.is_empty():
		return
	if once and _spoken:
		return
	var now := Time.get_ticks_msec()
	if now - _last_msec < int(cooldown_seconds * 1000.0):
		return
	_last_msec = now
	_spoken = true
	EventBus.companion_say.emit(lines[randi() % lines.size()])
