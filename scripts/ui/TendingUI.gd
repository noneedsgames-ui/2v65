extends Control
## 店番中だけ画面下に出る案内。呼び込みキーと、その回の売上を表示する。

@onready var stats_label: Label = $Panel/Margin/VBox/StatsLabel

func _ready() -> void:
	visible = false
	EventBus.tending_started.connect(func(): visible = true)
	EventBus.tending_ended.connect(func(): visible = false)
	EventBus.tending_stats.connect(_on_stats)

func _on_stats(customers: int, gold: int) -> void:
	stats_label.text = "この店番での売上: %d人 / +%dG" % [customers, gold]
