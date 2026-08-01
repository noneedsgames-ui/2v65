extends Control

@onready var gold_label: Label = $Margin/VBox/GoldLabel
@onready var hp_fill: ColorRect = $Margin/VBox/HPBar/Fill
@onready var hp_text: Label = $Margin/VBox/HPBar/HPText
@onready var help_label: Label = $Margin/VBox/HelpLabel
@onready var prompt_label: Label = $PromptLabel
@onready var toast_label: Label = $ToastLabel
@onready var toast_timer: Timer = $ToastTimer

func _ready() -> void:
	EventBus.interact_prompt_show.connect(_on_prompt_show)
	EventBus.interact_prompt_hide.connect(_on_prompt_hide)
	EventBus.notify.connect(_on_notify)
	Inventory.gold_changed.connect(_on_gold_changed)
	EventBus.player_hp_changed.connect(_on_hp_changed)
	_on_hp_changed(GameState.player_hp, GameState.PLAYER_MAX_HP)
	toast_timer.timeout.connect(func(): toast_label.visible = false)
	help_label.text = "移動:A/D  ジャンプ(壁蹴り):Space  調べる:E  攻撃:J\n持ち物:I  工房:C  メモ帳:K  メニュー:Tab  使う:F  閉じる:Esc"
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
	toast_timer.start(Settings.toast_seconds)

func _on_gold_changed(amount: int) -> void:
	gold_label.text = "所持金: %dG" % amount

func _on_hp_changed(hp: int, max_hp: int) -> void:
	hp_fill.size = Vector2(176.0 * float(hp) / maxf(1.0, float(max_hp)), 14.0)
	hp_text.text = "HP %d/%d" % [hp, max_hp]
