extends Area2D
## 話しかけられる村人。通行人(TownNPC)と違って決まった場所に立ち、
## 名前と役割を持ち、クエストをくれる。
##
## 物語のほうに話すことがあるときは、依頼画面よりそちらを先に出す。
## 章が来るまで町にいない村人もいるので、その場合は姿ごと消しておく。

@export var resident_id: String = "mira"
@export var body_color: Color = Color(0.75, 0.4, 0.45)
@export var idle_lines: PackedStringArray = PackedStringArray()
## 0 以下なら最初からいる。1 以上ならその章になるまで町に出ない。
@export var appears_from_chapter: int = 0

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("villager")
	$Visual/Body.color = body_color
	$Visual/Head.color = Color(0.94, 0.8, 0.64)
	$NameLabel.text = Journal.get_resident_name(resident_id)
	Story.story_changed.connect(_refresh_presence)
	_refresh_presence()

## まだ町に来ていない村人は、見えないうえに調べられないようにする。
func _refresh_presence() -> void:
	var here := Story.resident_available(resident_id, appears_from_chapter)
	visible = here
	# 当たり判定も切らないと、見えないのに「話す」が出てしまう
	set_deferred("monitorable", here)
	$CollisionShape2D.set_deferred("disabled", not here)

func get_prompt() -> String:
	return "%s と話す [E]" % Journal.get_resident_name(resident_id)

func interact(_actor: Node) -> void:
	Journal.meet(resident_id)
	var story_node := Story.node_for_resident(resident_id)
	if story_node != "":
		Story.mark_talk_seen(story_node)
		EventBus.request_open_story.emit(story_node)
		return
	EventBus.request_open_dialogue.emit(resident_id, idle_lines)
