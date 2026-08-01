extends Control
## 行き先(探索地)を選ぶ画面。それぞれの危険度と採れるものを見て決める。

@onready var list: VBoxContainer = $Center/Window/Margin/Content/List

func _ready() -> void:
	$Center/Window/Margin/Content/CloseButton.pressed.connect(_on_close)

func refresh() -> void:
	for c in list.get_children():
		c.queue_free()

	for area in AreaDB.AREAS:
		var panel := PanelContainer.new()
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_bottom", 10)
		panel.add_child(margin)

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		margin.add_child(box)

		var title := Label.new()
		title.text = area["name"]
		title.add_theme_font_size_override("font_size", 20)
		title.add_theme_color_override("font_color", area["surface"])
		box.add_child(title)

		var blurb := Label.new()
		blurb.text = area["blurb"]
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.custom_minimum_size = Vector2(560, 0)
		box.add_child(blurb)

		var detail := Label.new()
		detail.text = area["detail"]
		detail.add_theme_font_size_override("font_size", 14)
		detail.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.custom_minimum_size = Vector2(560, 0)
		box.add_child(detail)

		var stats := Label.new()
		stats.text = "けものの強さ: %d / 距離: %dm" % [
			int(area["enemy_hp"]), int(float(area["length"]) / 100.0)]
		stats.add_theme_font_size_override("font_size", 13)
		stats.add_theme_color_override("font_color", Color(1, 0.8, 0.6))
		box.add_child(stats)

		var go := Button.new()
		go.text = "%s へ向かう" % area["name"]
		go.custom_minimum_size = Vector2(0, 36)
		var aid: String = area["id"]
		go.pressed.connect(func(): _depart(aid))
		box.add_child(go)

		list.add_child(panel)

func _depart(area_id: String) -> void:
	GameState.selected_area = area_id
	var area := AreaDB.get_area(area_id)
	EventBus.companion_say.emit("%sだね。準備はいい？ 行こう！" % area["name"])
	# 遷移すると今のシーンごと消えるので、閉じる処理は travel_to 側の paused 解除に任せる
	GameState.travel_to(GameState.WILDS_SCENE, Vector2(160, 380))

func _on_close() -> void:
	EventBus.request_close_menus.emit()
