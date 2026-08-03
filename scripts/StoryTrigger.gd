extends Area2D
## 通りかかると物語の出来事が起きる範囲。
##
## 起こしていいかどうかの判断は Story がまとめて持っている(章・旗・探索地)。
## こちらは「プレイヤーが入った」ことだけを伝える。
##
## 一度きりかどうかも StoryDB 側の once で決まるので、
## 同じ場所に置いたまま章が進めば別の出来事が起きる、という書き方ができる。
##
## 入った瞬間ではなく少し待ってから開く。await ではなく Timer を使うのは、
## 待っているあいだにシーンが切り替わると、await の再開先が消えているため。
## Timer なら自分ごと消えるので、そういう事故が起きない。

@export var event_id: String = ""
@export var delay_seconds: float = 0.25

@onready var timer: Timer = $Timer

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	timer.wait_time = maxf(0.05, delay_seconds)
	timer.timeout.connect(_on_timeout)

func _on_body_entered(body: Node) -> void:
	if event_id == "" or not timer.is_stopped():
		return
	if not body.is_in_group("player"):
		return
	if not Story.can_fire(event_id):
		return
	timer.start()

func _on_timeout() -> void:
	# 待っているあいだに条件が変わっていることがあるので、もう一度確かめる
	if Story.can_fire(event_id):
		Story.fire(event_id)
