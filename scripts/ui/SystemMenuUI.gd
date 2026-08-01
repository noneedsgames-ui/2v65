extends Control
## システムメニュー。セーブと設定、タイトルへ戻る。
## 左が操作、右が設定項目。

@onready var save_button: Button = $Center/Window/Margin/Content/Body/Left/SaveButton
@onready var save_info: Label = $Center/Window/Margin/Content/Body/Left/SaveInfo
@onready var title_button: Button = $Center/Window/Margin/Content/Body/Left/TitleButton
@onready var quit_button: Button = $Center/Window/Margin/Content/Body/Left/QuitButton

@onready var volume_slider: HSlider = $Center/Window/Margin/Content/Body/Right/VolumeSlider
@onready var volume_label: Label = $Center/Window/Margin/Content/Body/Right/VolumeLabel
@onready var fullscreen_check: CheckButton = $Center/Window/Margin/Content/Body/Right/FullscreenCheck
@onready var shake_check: CheckButton = $Center/Window/Margin/Content/Body/Right/ShakeCheck
@onready var bubble_slider: HSlider = $Center/Window/Margin/Content/Body/Right/BubbleSlider
@onready var bubble_label: Label = $Center/Window/Margin/Content/Body/Right/BubbleLabel

## タイトルへ戻る前の確認中フラグ
var _confirming_title: bool = false

func _ready() -> void:
	$Center/Window/Margin/Content/CloseButton.pressed.connect(_on_close)
	save_button.pressed.connect(_on_save)
	title_button.pressed.connect(_on_title)
	quit_button.pressed.connect(func(): get_tree().quit())

	volume_slider.value_changed.connect(func(v): Settings.set_master_volume(v / 100.0); _sync())
	bubble_slider.value_changed.connect(func(v): Settings.set_bubble_seconds(v); _sync())
	fullscreen_check.toggled.connect(func(v): Settings.set_fullscreen(v))
	shake_check.toggled.connect(func(v): Settings.set_screen_shake(v))

func refresh() -> void:
	_confirming_title = false
	title_button.text = "タイトルへ戻る"
	_sync()

func _sync() -> void:
	volume_slider.set_value_no_signal(Settings.master_volume * 100.0)
	volume_label.text = "音量: %d%%" % int(Settings.master_volume * 100.0)
	bubble_slider.set_value_no_signal(Settings.bubble_seconds)
	bubble_label.text = "相棒の吹き出し: %.1f秒" % Settings.bubble_seconds
	fullscreen_check.set_pressed_no_signal(Settings.fullscreen)
	shake_check.set_pressed_no_signal(Settings.screen_shake)
	save_info.text = "記録あり" if GameState.has_save else "まだ記録がない"

func _on_save() -> void:
	GameState.save_game()
	_sync()

## 未セーブの進行を失う操作なので、一度確認をはさむ。
func _on_title() -> void:
	if not _confirming_title:
		_confirming_title = true
		title_button.text = "本当に戻る？(未セーブ分は失われる)"
		return
	get_tree().paused = false
	GameState.clear_pending_spawn()
	get_tree().change_scene_to_file.call_deferred("res://scenes/TitleScreen.tscn")

func _on_close() -> void:
	EventBus.request_close_menus.emit()
