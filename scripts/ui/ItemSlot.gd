extends Button
## アイテム1個ぶんの升目。アイコン画像のみを表示し、個数は右下に小さく重ねる。
## SVG がまだインポートされていない環境ではアイコンが取れないので、
## その場合は ItemDB の色で塗った矩形にフォールバックする。

signal slot_pressed(index: int)

var index: int = -1
var item_id: String = ""

@onready var icon_rect: TextureRect = $Icon
@onready var color_rect: ColorRect = $Fallback
@onready var count_label: Label = $CountLabel
@onready var selection: Panel = $Selection

func _ready() -> void:
	pressed.connect(func(): slot_pressed.emit(index))
	set_selected(false)

## id が "" ならスロットを空表示にする。
func set_item(id: String, count: int) -> void:
	item_id = id
	if id == "":
		icon_rect.visible = false
		color_rect.visible = false
		count_label.text = ""
		tooltip_text = ""
		return

	var tex := ItemDB.get_icon(id)
	if tex != null:
		icon_rect.texture = tex
		icon_rect.visible = true
		color_rect.visible = false
	else:
		# アイコン未インポート時のフォールバック
		icon_rect.visible = false
		color_rect.color = ItemDB.get_color(id)
		color_rect.visible = true

	count_label.text = str(count) if count > 1 else ""
	tooltip_text = ItemDB.get_display_name(id)

func set_selected(value: bool) -> void:
	selection.visible = value
