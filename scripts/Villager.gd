extends Area2D
## 話しかけられる村人。通行人(TownNPC)と違って決まった場所に立ち、
## 名前と役割を持ち、クエストをくれる。

@export var resident_id: String = "mira"
@export var body_color: Color = Color(0.75, 0.4, 0.45)
@export var idle_lines: PackedStringArray = PackedStringArray()

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("villager")
	$Visual/Body.color = body_color
	$Visual/Head.color = Color(0.94, 0.8, 0.64)
	$NameLabel.text = Journal.get_resident_name(resident_id)

func get_prompt() -> String:
	return "%s と話す [E]" % Journal.get_resident_name(resident_id)

func interact(_actor: Node) -> void:
	Journal.meet(resident_id)
	EventBus.request_open_dialogue.emit(resident_id, idle_lines)
