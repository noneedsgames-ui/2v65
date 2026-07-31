extends Area2D
## NPCの店。品揃えはシーン側で指定でき、町には種類の違う店が並ぶ。

@export var shop_name: String = "よろず屋"
@export var stock: PackedStringArray = PackedStringArray(["axe", "pickaxe", "basket", "stall_kit"])

func _ready() -> void:
	add_to_group("interactable")

func get_prompt() -> String:
	return "%s で売買する [E]" % shop_name

func interact(_actor: Node) -> void:
	EventBus.request_open_shop.emit(shop_name, stock)
