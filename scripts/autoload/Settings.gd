extends Node
## 遊びやすさの設定。ゲームの進行とは別ファイルに保存する。
## セーブデータを消しても設定は残るようにしたいため。

signal changed()

const PATH := "user://settings.json"

var master_volume: float = 0.8
var fullscreen: bool = false
## 同行者の吹き出しを出しておく秒数
var bubble_seconds: float = 4.5
## 画面のゆれ(被弾時など)を出すか
var screen_shake: bool = true
## 通知の表示秒数
var toast_seconds: float = 2.5

func _ready() -> void:
	load_settings()
	apply()

func apply() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
		AudioServer.set_bus_mute(bus, master_volume <= 0.0)
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	changed.emit()

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	apply()
	save_settings()

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply()
	save_settings()

func set_bubble_seconds(value: float) -> void:
	bubble_seconds = clampf(value, 1.5, 12.0)
	apply()
	save_settings()

func set_toast_seconds(value: float) -> void:
	toast_seconds = clampf(value, 1.0, 8.0)
	apply()
	save_settings()

func set_screen_shake(value: bool) -> void:
	screen_shake = value
	apply()
	save_settings()

func save_settings() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"master_volume": master_volume,
		"fullscreen": fullscreen,
		"bubble_seconds": bubble_seconds,
		"toast_seconds": toast_seconds,
		"screen_shake": screen_shake,
	}))
	file.close()

func load_settings() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	master_volume = clampf(float(data.get("master_volume", master_volume)), 0.0, 1.0)
	fullscreen = bool(data.get("fullscreen", fullscreen))
	bubble_seconds = clampf(float(data.get("bubble_seconds", bubble_seconds)), 1.5, 12.0)
	toast_seconds = clampf(float(data.get("toast_seconds", toast_seconds)), 1.0, 8.0)
	screen_shake = bool(data.get("screen_shake", screen_shake))
