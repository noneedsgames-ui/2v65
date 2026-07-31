class_name UIRowFactory
extends RefCounted
## UI パネル内の「アイコン色 + ラベル + ボタン」の1行を組み立てる共通ヘルパー。

static func make_item_row(icon_color: Color, label_text: String, button_text: String, on_pressed: Callable, disabled: bool = false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(22, 22)
	swatch.color = icon_color
	row.add_child(swatch)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(260, 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	if button_text != "":
		var button := Button.new()
		button.text = button_text
		button.disabled = disabled
		button.pressed.connect(on_pressed)
		row.add_child(button)

	return row
