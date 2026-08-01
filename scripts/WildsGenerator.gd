extends Node2D
## 奥の森の地形をシーン読み込み時に自動生成する。
##
## 生成方針: 左端の入口区画から右へ、区画(セグメント)を1つずつ継ぎ足していく。
## 各区画は「入口の床の高さ」と「出口の床の高さ」を持ち、次の区画は必ず前の出口高さから
## 始まるので、道が途切れることがない。段差は必ずジャンプ・壁ジャンプ・相棒のいずれかで
## 越えられる高さに収めているため、生成結果は常に踏破可能になる。

const GROUND_Y := 400.0          # 基準の地面の高さ
const JUMP_REACH := 92.0         # 通常ジャンプで登れる段差(実測96pxより余裕を取る)
const SEGMENT_MIN := 420.0
const SEGMENT_MAX := 620.0
const START_X := 260.0           # 入口(門とコメントゾーン)のぶん空ける
const END_MARGIN := 320.0        # 右端の壁の手前に取る余白
## 地面の高さが動ける範囲。ここに収めないと段差を重ねるうちに地形が沈み込む。
const FLOOR_Y_MIN := GROUND_Y - 150.0
const FLOOR_Y_MAX := GROUND_Y + 40.0

const TREE := preload("res://scenes/Tree.tscn")
const ROCK := preload("res://scenes/Rock.tscn")
const BUSH := preload("res://scenes/Bush.tscn")
const IRON_VEIN := preload("res://scenes/IronVein.tscn")
const FIBER_PATCH := preload("res://scenes/FiberPatch.tscn")
const ENEMY := preload("res://scenes/Enemy.tscn")
const BOOST_SPOT := preload("res://scenes/BoostSpot.tscn")
const COMMENT_ZONE := preload("res://scenes/CommentZone.tscn")

const GATHER_SCENES := [TREE, ROCK, BUSH, IRON_VEIN, FIBER_PATCH]

@export var stage_length: float = 4400.0
## 0 なら毎回ランダム。値を入れると同じ地形を再現できる(デバッグ用)。
@export var generation_seed: int = 0

## 入る探索地(AreaDB)の定義。見た目・採れる素材・敵の強さがここで決まる。
var area: Dictionary = {}

var rng := RandomNumberGenerator.new()
var _terrain: Node2D
var _props: Node2D
## 生成した「立てる床」の区間 [{x_min, x_max, y}] 。素材や敵を床の上に置くのに使う。
var _platforms: Array = []

func _ready() -> void:
	_terrain = Node2D.new()
	_terrain.name = "GeneratedTerrain"
	add_child(_terrain)
	_props = Node2D.new()
	_props.name = "GeneratedProps"
	add_child(_props)

	area = AreaDB.get_area(GameState.selected_area)
	stage_length = float(area.get("length", stage_length))

	if generation_seed != 0:
		rng.seed = generation_seed
	else:
		rng.randomize()

	_paint_backdrop()
	_generate()

## 空と遠景をその土地の色に塗る。
func _paint_backdrop() -> void:
	var sky := get_parent().get_node_or_null("Sky") as Polygon2D
	if sky != null:
		sky.color = area["sky"]
	var far := get_parent().get_node_or_null("FarShapes")
	if far != null:
		for child in far.get_children():
			var poly := child as Polygon2D
			if poly != null:
				poly.color = area["far"]

func _generate() -> void:
	var x := START_X
	var floor_y := GROUND_Y
	# 入口はかならず平らな足場から始める(スポーン地点が宙に浮かないように)
	_add_ground(0.0, START_X, GROUND_Y)
	_add_platform_record(0.0, START_X, GROUND_Y)

	var limit := stage_length - END_MARGIN
	var kinds := ["flat", "step_up", "step_down", "gap", "tunnel", "high_ledge", "pit_rock"]
	var used_high_ledge := false
	var used_pit_rock := false

	while x < limit:
		var width: float = rng.randf_range(SEGMENT_MIN, SEGMENT_MAX)
		if x + width > limit:
			width = limit - x
		if width < 200.0:
			break

		var kind: String = kinds[rng.randi() % kinds.size()]
		# 相棒ギミックはステージに1回ずつだけ出す(何度も出ると単調になる)
		if kind == "high_ledge" and used_high_ledge:
			kind = "flat"
		if kind == "pit_rock" and used_pit_rock:
			kind = "flat"
		# 端に張り付いたら逆向きの段差にして、上下に変化を出す
		if floor_y <= FLOOR_Y_MIN and kind == "step_up":
			kind = "step_down"
		if floor_y >= FLOOR_Y_MAX and kind == "step_down":
			kind = "step_up"

		match kind:
			"flat":
				_seg_flat(x, width, floor_y)
			"step_up":
				floor_y = _seg_step_up(x, width, floor_y)
			"step_down":
				floor_y = _seg_step_down(x, width, floor_y)
			"gap":
				_seg_gap(x, width, floor_y)
			"tunnel":
				_seg_tunnel(x, width, floor_y)
			"high_ledge":
				_seg_high_ledge(x, width, floor_y)
				used_high_ledge = true
			"pit_rock":
				_seg_pit_rock(x, width, floor_y)
				used_pit_rock = true
		x += width

	# 右端まで床を伸ばして、崖の壁の足元を埋める
	if x < stage_length:
		_add_ground(x, stage_length - x, floor_y)
		_add_platform_record(x, x + (stage_length - x), floor_y)

	# 行き止まりの崖。探索地ごとに長さが違うので、生成側で立てる。
	_add_wall(stage_length, FLOOR_Y_MIN - 500.0, 40.0, 1000.0)
	var cliff := Polygon2D.new()
	cliff.polygon = PackedVector2Array([
		Vector2(stage_length, FLOOR_Y_MIN - 500.0), Vector2(stage_length + 80.0, FLOOR_Y_MIN - 500.0),
		Vector2(stage_length + 80.0, FLOOR_Y_MAX + 200.0), Vector2(stage_length, FLOOR_Y_MAX + 200.0)])
	cliff.color = area["ground"].darkened(0.25)
	_terrain.add_child(cliff)
	_add_comment(stage_length - 90.0, floor_y, ["行き止まりだ。ここから先へは進めないよ。"])

	_populate()
	# プレイヤーは生成器より後に _ready するので、カメラの調整は次のフレームに回す
	call_deferred("_apply_camera_limits")

## 探索地の長さにあわせてカメラの可動範囲を締める。
func _apply_camera_limits() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam != null:
		cam.limit_right = int(stage_length + 40.0)

# ---- 区画の種類 ----

func _seg_flat(x: float, w: float, y: float) -> void:
	_add_ground(x, w, y)
	_add_platform_record(x, x + w, y)
	# 気分転換に浮き足場を置くことがある
	if rng.randf() < 0.45:
		var pw: float = rng.randf_range(160.0, 240.0)
		var px: float = x + rng.randf_range(40.0, max(40.0, w - pw - 40.0))
		var py: float = y - rng.randf_range(80.0, JUMP_REACH)
		_add_platform(px, pw, py)
		_add_platform_record(px, px + pw, py)

func _seg_step_up(x: float, w: float, y: float) -> float:
	var half := w * 0.5
	_add_ground(x, half, y)
	_add_platform_record(x, x + half, y)
	# 帯域で頭打ちにする。切り詰めても段差は要求値以下なので、必ず登れる。
	var new_y: float = maxf(FLOOR_Y_MIN, y - rng.randf_range(60.0, JUMP_REACH))
	_add_ground(x + half, w - half, new_y)
	_add_platform_record(x + half, x + w, new_y)
	return new_y

func _seg_step_down(x: float, w: float, y: float) -> float:
	var half := w * 0.5
	_add_ground(x, half, y)
	_add_platform_record(x, x + half, y)
	# 同様に頭打ち。落差も要求値以下になるので、必ず登り返せる。
	var new_y: float = minf(FLOOR_Y_MAX, y + rng.randf_range(50.0, JUMP_REACH - 4.0))
	_add_ground(x + half, w - half, new_y)
	_add_platform_record(x + half, x + w, new_y)
	return new_y

## 飛び越える隙間。落ちても下に床があるので詰まない。
func _seg_gap(x: float, w: float, y: float) -> void:
	var gap_w: float = rng.randf_range(110.0, 170.0)
	var left_w := (w - gap_w) * 0.5
	_add_ground(x, left_w, y)
	_add_platform_record(x, x + left_w, y)
	_add_ground(x + left_w + gap_w, w - left_w - gap_w, y)
	_add_platform_record(x + left_w + gap_w, x + w, y)
	# 落下時の受け皿。JUMP_REACH 以内にして、普通のジャンプで必ず登り返せるようにする。
	var pit_y := y + JUMP_REACH - 12.0
	_add_ground(x + left_w, gap_w, pit_y)
	_add_platform_record(x + left_w, x + left_w + gap_w, pit_y)

## プレイヤーだけが通れる狭い隙間。上に迂回路の足場を置き、相棒はそちらを通れる。
func _seg_tunnel(x: float, w: float, y: float) -> void:
	_add_ground(x, w, y)
	_add_platform_record(x, x + w, y)
	var tw: float = min(280.0, w - 120.0)
	var tx: float = x + (w - tw) * 0.5
	# 天井スラブは指定 y から y+30 を占める。足元(y)との空きを 70px にするため上端は y-100。
	# プレイヤー(高さ54)は通れて相棒(高さ108)は通れない。
	# 相棒は重力を受けず目標へ直進するので、天井の上を越えて追いついてくる。
	_add_platform(tx, tw, y - 100.0)

## 相棒に引き上げてもらう高台。ジャンプでは届かない高さにする。
func _seg_high_ledge(x: float, w: float, y: float) -> void:
	_add_ground(x, w, y)
	_add_platform_record(x, x + w, y)
	var lw: float = min(360.0, w - 120.0)
	var lx: float = x + w - lw - 40.0
	var ly: float = y - 150.0   # JUMP_REACH(92)より高いので相棒が必要
	_add_platform(lx, lw, ly)
	_add_platform_record(lx, lx + lw, ly)

	var spot := BOOST_SPOT.instantiate()
	spot.position = Vector2(lx - 70.0, y)
	spot.target_position = Vector2(lx + lw * 0.5, ly - 30.0)
	_props.add_child(spot)
	_add_comment(lx - 70.0, y, ["あの段差は高すぎるね。わたしに頼んで！ 引き上げるよ。"])

## 相棒に岩を押してもらって渡る谷。
## 谷幅 200px はジャンプの飛距離(約160px)を超えるので飛び越えられないが、
## 落ちても側壁を蹴って(壁ジャンプで)登り返せるため、閉じ込められることはない。
const PIT_WIDTH := 200.0
const PIT_DEPTH := 130.0

func _seg_pit_rock(x: float, w: float, y: float) -> void:
	var left_w: float = (w - PIT_WIDTH) * 0.5
	_add_ground(x, left_w, y)
	_add_platform_record(x, x + left_w, y)
	_add_ground(x + left_w + PIT_WIDTH, w - left_w - PIT_WIDTH, y)
	_add_platform_record(x + left_w + PIT_WIDTH, x + w, y)

	var pit_x := x + left_w
	# 谷底と、壁ジャンプの足がかりになる通しの側壁
	_add_ground(pit_x, PIT_WIDTH, y + PIT_DEPTH)
	_add_wall(pit_x - 12.0, y, 12.0, PIT_DEPTH)
	_add_wall(pit_x + PIT_WIDTH, y, 12.0, PIT_DEPTH)
	_add_dark_rect(pit_x, y, PIT_WIDTH, PIT_DEPTH)

	# 岩は谷の手前。押すと谷に落ちて足場になり、楽に渡れるようになる。
	var rock := preload("res://scenes/PushableRock.tscn").instantiate()
	# 岩の当たり判定は幅120。陸の上に完全に載る位置に置き、押すと谷の中央へ落ちる。
	rock.position = Vector2(pit_x - 70.0, y)
	rock.get_node("Zone").push_offset = Vector2(130.0, PIT_DEPTH)
	_props.add_child(rock)
	_add_comment(pit_x - 90.0, y, ["大きな岩だ…。わたしが押せば、谷の足場になりそう。"])

# ---- 生成のためのプリミティブ ----

func _add_ground(x: float, w: float, y: float) -> void:
	if w <= 0.0:
		return
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector2(x + w * 0.5, y + 20.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, 40.0)
	shape.shape = rect
	body.add_child(shape)

	var dirt := Polygon2D.new()
	dirt.polygon = PackedVector2Array([
		Vector2(-w * 0.5, -20), Vector2(w * 0.5, -20),
		Vector2(w * 0.5, 140), Vector2(-w * 0.5, 140)])
	dirt.color = area["ground"]
	body.add_child(dirt)

	var moss := Polygon2D.new()
	moss.polygon = PackedVector2Array([
		Vector2(-w * 0.5, -20), Vector2(w * 0.5, -20),
		Vector2(w * 0.5, -10), Vector2(-w * 0.5, -10)])
	moss.color = area["surface"]
	body.add_child(moss)

	_terrain.add_child(body)

func _add_platform(x: float, w: float, y: float) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector2(x + w * 0.5, y + 15.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, 30.0)
	shape.shape = rect
	body.add_child(shape)

	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-w * 0.5, -15), Vector2(w * 0.5, -15),
		Vector2(w * 0.5, 15), Vector2(-w * 0.5, 15)])
	visual.color = area["ground"].lightened(0.12)
	body.add_child(visual)
	_terrain.add_child(body)

func _add_wall(x: float, y: float, w: float, h: float) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = Vector2(x + w * 0.5, y + h * 0.5)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	shape.shape = rect
	body.add_child(shape)
	_terrain.add_child(body)

func _add_dark_rect(x: float, y: float, w: float, h: float) -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
	poly.color = Color(0.16, 0.11, 0.07)
	_terrain.add_child(poly)

func _add_platform_record(x_min: float, x_max: float, y: float) -> void:
	_platforms.append({"x_min": x_min, "x_max": x_max, "y": y})

func _add_comment(x: float, y: float, lines: Array) -> void:
	var zone := COMMENT_ZONE.instantiate()
	zone.position = Vector2(x, y)
	zone.lines = PackedStringArray(lines)
	zone.cooldown_seconds = 40.0
	_props.add_child(zone)

# ---- 素材と敵の配置 ----

func _populate() -> void:
	for plat in _platforms:
		var width: float = plat["x_max"] - plat["x_min"]
		if width < 150.0:
			continue
		# 入口付近は安全地帯にしておく
		var is_start: bool = plat["x_min"] < START_X + 40.0

		var slots := int(width / 190.0)
		for i in range(slots):
			var px: float = plat["x_min"] + 90.0 + i * 190.0 + rng.randf_range(-25.0, 25.0)
			if px < plat["x_min"] + 60.0 or px > plat["x_max"] - 60.0:
				continue
			var roll := rng.randf()
			if not is_start and roll < float(area["enemy_rate"]):
				_spawn_enemy(px, plat)
			elif roll < 0.72:
				_spawn_gather(px, plat["y"])

	_add_comment(START_X - 40.0, GROUND_Y,
		["ここが%sだね。%s" % [area["name"], area["blurb"]],
		"地形は来るたびに変わるみたい。気をつけて。"])

const NODE_SCENES := {"tree": TREE, "bush": BUSH, "fiber": FIBER_PATCH,
	"rock": ROCK, "vein": IRON_VEIN}

## 重み付きで採集ノードの種類を選ぶ。土地ごとに出やすさが違う。
func _pick_node_kind() -> String:
	var weights: Dictionary = area["nodes"]
	var total := 0
	for k in weights.keys():
		total += int(weights[k])
	var roll := rng.randi_range(1, max(1, total))
	for k in weights.keys():
		roll -= int(weights[k])
		if roll <= 0:
			return k
	return "tree"

func _spawn_gather(x: float, y: float) -> void:
	var kind := _pick_node_kind()
	var node = NODE_SCENES[kind].instantiate()
	node.position = Vector2(x, y)
	# 草木からはその土地の薬草、岩と鉱脈からは鉱石が採れる
	if kind == "rock" or kind == "vein":
		node.bonus_ids = PackedStringArray(area["ores"])
	else:
		node.bonus_ids = PackedStringArray(area["herbs"])
	_props.add_child(node)

func _spawn_enemy(x: float, plat: Dictionary) -> void:
	var enemy := ENEMY.instantiate()
	enemy.position = Vector2(x, plat["y"])
	# 足場からはみ出さない範囲を巡回させる
	enemy.patrol_min_x = plat["x_min"] + 40.0
	enemy.patrol_max_x = plat["x_max"] - 40.0
	enemy.max_hp = int(area["enemy_hp"])
	enemy.contact_damage = int(area["enemy_damage"])
	# 奥へ行くほど手強くし、落とす物も良くなる
	if x > stage_length * 0.6:
		enemy.max_hp = int(area["enemy_hp"]) + 25
		var ores: Array = area["ores"]
		enemy.drop_id = ores[rng.randi() % ores.size()]
	else:
		var herbs: Array = area["herbs"]
		enemy.drop_id = herbs[rng.randi() % herbs.size()]
	_props.add_child(enemy)
