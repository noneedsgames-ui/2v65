extends Control

@onready var gold_label: Label = $Margin/VBox/GoldLabel
@onready var help_label: Label = $Margin/VBox/HelpLabel
@onready var prompt_label: Label = $PromptLabel
@onready var toast_label: Label = $ToastLabel
@onready var toast_timer: Timer = $ToastTimer

func _ready() -> void:
	EventBus.interact_prompt_show.connect(_on_prompt_show)
	EventBus.interact_prompt_hide.connect(_on_prompt_hide)
	EventBus.notify.connect(_on_notify)
	Inventory.gold_changed.connect(_on_gold_changed)
	toast_timer.timeout.connect(func(): toast_label.visible = false)
	help_label.text = "移動:A/D  ジャンプ:Space  調べる:E  持ち物:I  クラフト:C  閉じる:Esc"
	prompt_label.visible = false
	toast_label.visible = false
	_on_gold_changed(Inventory.gold)

func _on_prompt_show(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = true

func _on_prompt_hide() -> void:
	prompt_label.visible = false

func _on_notify(text: String) -> void:
	toast_label.text = text
	toast_label.visible = true
	toast_timer.start()

func _on_gold_changed(amount: int) -> void:
	gold_label.text = "所持金: %dG" % amount
