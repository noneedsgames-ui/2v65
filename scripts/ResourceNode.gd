extends Area2D
## 木・岩・茂みなど、採集可能な素材ノード。
## 採集後は一定時間で再湧きする。

@export var item_id: String = "wood"
@export var min_amount: int = 1
@export var max_amount: int = 3
@export var respawn_time: float = 12.0
@export var required_tool: String = ""  # 空なら道具不要。"axe" / "pickaxe" など(装備している必要がある)
@export var display_name: String = "木"

var depleted: bool = false

@onready var visual: Node2D = $Visual
@onready var timer: Timer = $RespawnTimer

func _ready() -> void:
	add_to_group("interactable")
	timer.wait_time = respawn_time
	timer.one_shot = true
	timer.timeout.connect(_on_respawn)

func _has_required_tool() -> bool:
	return required_tool == "" or Equipment.get_equipped(Equipment.SLOT_TOOL) == required_tool

func get_prompt() -> String:
	if depleted:
		return ""
	if not _has_required_tool():
		return "%s (%sの装備が必要)" % [display_name, ItemDB.get_display_name(required_tool)]
	return "%s を採集 [E]" % display_name

func interact(_actor: Node) -> void:
	if depleted:
		return
	if not _has_required_tool():
		EventBus.notify.emit("%sを装備する必要があります" % ItemDB.get_display_name(required_tool))
		return
	var amount := randi_range(min_amount, max_amount) + Equipment.get_total_gather_bonus()
	var added := Inventory.add_item(item_id, amount)
	if added > 0:
		EventBus.notify.emit("%s +%d" % [ItemDB.get_display_name(item_id), added])
	_deplete()

func _deplete() -> void:
	depleted = true
	visual.modulate = Color(1, 1, 1, 0.25)
	EventBus.interact_prompt_hide.emit()
	timer.start()

func _on_respawn() -> void:
	depleted = false
	visual.modulate = Color(1, 1, 1, 1)
