extends Control
## 画面端に出る同行者のひとこと。EventBus.companion_say を受けて一定時間表示する。

@export var display_seconds: float = 4.5

@onready var panel: PanelContainer = $Panel
@onready var text_label: Label = $Panel/Margin/VBox/TextLabel
@onready var timer: Timer = $HideTimer

func _ready() -> void:
	EventBus.companion_say.connect(say)
	timer.one_shot = true
	timer.timeout.connect(func(): panel.visible = false)
	panel.visible = false

func say(text: String) -> void:
	if text == "":
		return
	text_label.text = text
	panel.visible = true
	timer.start(display_seconds)
