extends Control
## 起動時のタイトル画面。ここからゲームを始める。

@onready var continue_button: Button = $Center/Menu/ContinueButton
@onready var new_button: Button = $Center/Menu/NewButton
@onready var settings_button: Button = $Center/Menu/SettingsButton
@onready var quit_button: Button = $Center/Menu/QuitButton
@onready var settings_box: VBoxContainer = $SettingsBox
@onready var volume_label: Label = $SettingsBox/Panel/Margin/VBox/VolumeLabel
@onready var volume_slider: HSlider = $SettingsBox/Panel/Margin/VBox/VolumeSlider
@onready var fullscreen_check: CheckButton = $SettingsBox/Panel/Margin/VBox/FullscreenCheck
@onready var back_button: Button = $SettingsBox/Panel/Margin/VBox/BackButton
@onready var note_label: Label = $Center/Menu/NoteLabel

## 「はじめから」を押した直後の確認中フラグ
var _confirming_new: bool = false

func _ready() -> void:
	# タイトルでは前の周回の一時停止が残っていることがあるので必ず解除する
	get_tree().paused = false

	new_button.pressed.connect(_on_new)
	continue_button.pressed.connect(_on_continue)
	settings_button.pressed.connect(func(): settings_box.visible = true)
	back_button.pressed.connect(func(): settings_box.visible = false)
	quit_button.pressed.connect(func(): get_tree().quit())

	volume_slider.value_changed.connect(func(v): Settings.set_master_volume(v / 100.0); _sync_settings())
	fullscreen_check.toggled.connect(func(v): Settings.set_fullscreen(v))

	settings_box.visible = false
	_sync_settings()

	var has_save := FileAccess.file_exists(GameState.SAVE_PATH)
	continue_button.disabled = not has_save
	note_label.text = "" if has_save else "まだ記録がない。「はじめから」で旅に出よう。"
	if has_save:
		continue_button.grab_focus()
	else:
		new_button.grab_focus()

func _sync_settings() -> void:
	volume_slider.set_value_no_signal(Settings.master_volume * 100.0)
	volume_label.text = "音量: %d%%" % int(Settings.master_volume * 100.0)
	fullscreen_check.set_pressed_no_signal(Settings.fullscreen)

## 記録があるときは上書きの確認をはさむ。
func _on_new() -> void:
	if FileAccess.file_exists(GameState.SAVE_PATH) and not _confirming_new:
		_confirming_new = true
		new_button.text = "本当に最初から？(今の記録は消えます)"
		return
	GameState.reset_for_new_game()
	GameState.clear_pending_spawn()
	get_tree().change_scene_to_file.call_deferred(GameState.FIELD_SCENE)

func _on_continue() -> void:
	# セーブの読み込みは野原シーンの WorldRoot が起動時に行う
	GameState.clear_pending_spawn()
	get_tree().change_scene_to_file.call_deferred(GameState.FIELD_SCENE)
