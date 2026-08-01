extends Control
## 魔力回路つなぎ。道具の部品がすべて揃ったときに挟まる仕上げのパズル。
##
## 盤面の各マスには管が入っている。押すと90度回る。
## 左端の「源」から右端の「受け口」まで管がつながれば回路が通り、道具が完成する。
##
## 必ず解けることの保証:
##   まず左端から右端へ一本道を引き、その道に沿って管を置く(道の無いマスは飾り)。
##   そのあと各マスをランダムに回すだけなので、回し戻せば必ず元の解に戻せる。

signal solved()
signal cancelled()

const COLS := 5
const ROWS := 4
const CELL := 62.0
const GAP := 6.0

## 方角のビット(上下左右)
const UP := 1
const RIGHT := 2
const DOWN := 4
const LEFT := 8

const DIR_VECTORS := {
	UP: Vector2i(0, -1), RIGHT: Vector2i(1, 0),
	DOWN: Vector2i(0, 1), LEFT: Vector2i(-1, 0),
}
const OPPOSITE := {UP: DOWN, RIGHT: LEFT, DOWN: UP, LEFT: RIGHT}

var rng := RandomNumberGenerator.new()
## 各マスの管がつながっている方角(ビット和)
var cells: Array = []
## 解になる一本道(検算と、詰まったときの手がかりに使う)
var solution_path: Array = []
var _buttons: Array = []
var _running: bool = false

@onready var grid_holder: Control = $Panel/Margin/VBox/Board
@onready var status_label: Label = $Panel/Margin/VBox/StatusLabel
@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var give_up_button: Button = $Panel/Margin/VBox/GiveUpButton

func _ready() -> void:
	give_up_button.pressed.connect(_on_give_up)
	visible = false

func start(tool_name: String) -> void:
	rng.randomize()
	title_label.text = "%s ─ 魔力の回路をつなげ" % tool_name
	_generate()
	_build_buttons()
	_running = true
	visible = true
	_update()

# ---- 盤面づくり ----

## 左端から右端まで、上下移動を混ぜた一本道を引く。
func _make_path() -> Array:
	var path: Array = []
	var row := rng.randi_range(0, ROWS - 1)
	var col := 0
	path.append(Vector2i(col, row))
	while col < COLS - 1:
		# ときどき縦に振ってから右へ進む
		if rng.randf() < 0.45:
			var dir := 1 if rng.randf() < 0.5 else -1
			var steps := rng.randi_range(1, 2)
			for _i in range(steps):
				var next_row := row + dir
				if next_row < 0 or next_row >= ROWS:
					break
				# 同じマスを二度通らない
				if path.has(Vector2i(col, next_row)):
					break
				row = next_row
				path.append(Vector2i(col, row))
		col += 1
		path.append(Vector2i(col, row))
	return path

func _generate() -> void:
	cells.clear()
	for _i in range(COLS * ROWS):
		cells.append(0)

	solution_path = _make_path()

	# 道に沿って管をつなぐ。両端は盤の外(源と受け口)へ向けて開けておく。
	for i in range(solution_path.size()):
		var here: Vector2i = solution_path[i]
		var mask := 0
		if i == 0:
			mask |= LEFT
		else:
			mask |= _dir_between(here, solution_path[i - 1])
		if i == solution_path.size() - 1:
			mask |= RIGHT
		else:
			mask |= _dir_between(here, solution_path[i + 1])
		cells[_index(here)] = cells[_index(here)] | mask

	# 道から外れたマスには飾りの管を置く(まぎらわしくするため)
	for y in range(ROWS):
		for x in range(COLS):
			var idx := y * COLS + x
			if cells[idx] == 0:
				var choices := [UP | DOWN, LEFT | RIGHT, UP | RIGHT, RIGHT | DOWN, DOWN | LEFT, LEFT | UP]
				cells[idx] = choices[rng.randi() % choices.size()]

	# ぜんぶランダムに回す。回転で作った盤なので、回し戻せば必ず解ける。
	for i in range(cells.size()):
		var turns := rng.randi_range(0, 3)
		for _t in range(turns):
			cells[i] = _rotate(cells[i])

func _dir_between(from: Vector2i, to: Vector2i) -> int:
	var d := to - from
	for dir in DIR_VECTORS.keys():
		if DIR_VECTORS[dir] == d:
			return dir
	return 0

func _index(cell: Vector2i) -> int:
	return cell.y * COLS + cell.x

## 時計回りに90度。上→右→下→左とビットを送る。
func _rotate(mask: int) -> int:
	var out := 0
	if mask & UP:
		out |= RIGHT
	if mask & RIGHT:
		out |= DOWN
	if mask & DOWN:
		out |= LEFT
	if mask & LEFT:
		out |= UP
	return out

# ---- 表示 ----

func _build_buttons() -> void:
	for c in grid_holder.get_children():
		c.queue_free()
	_buttons.clear()
	for y in range(ROWS):
		for x in range(COLS):
			var b := Button.new()
			b.custom_minimum_size = Vector2(CELL, CELL)
			b.position = Vector2(x * (CELL + GAP), y * (CELL + GAP))
			b.size = Vector2(CELL, CELL)
			var idx := y * COLS + x
			b.pressed.connect(func(): _turn(idx))
			grid_holder.add_child(b)
			_buttons.append(b)

## 管の向きを文字で表す。矢印で開いている方角を示す。
func _cell_label(mask: int) -> String:
	var parts: Array = []
	if mask & UP:
		parts.append("↑")
	if mask & LEFT:
		parts.append("←")
	if mask & RIGHT:
		parts.append("→")
	if mask & DOWN:
		parts.append("↓")
	return "".join(parts) if not parts.is_empty() else "・"

func _turn(index: int) -> void:
	if not _running:
		return
	cells[index] = _rotate(cells[index])
	_update()

func _update() -> void:
	var live := _connected_cells()
	for i in range(_buttons.size()):
		var b := _buttons[i] as Button
		if b == null:
			continue
		b.text = _cell_label(cells[i])
		# 源からつながっているマスは光らせる
		b.modulate = Color(1.0, 0.92, 0.5) if live.has(i) else Color(0.72, 0.74, 0.8)

	if _is_solved():
		_running = false
		status_label.text = "回路がつながった！"
		# 光った状態を一瞬見せてから閉じる
		await get_tree().create_timer(0.6).timeout
		visible = false
		solved.emit()
	else:
		status_label.text = "マスを押すと管が回る。左の源から右の受け口までつなげよう。"

## 源(左端の外)からたどれるマスの集合。
func _connected_cells() -> Dictionary:
	var seen := {}
	var stack: Array = []
	# 左端の列で、左に開いているマスが入口
	for y in range(ROWS):
		var idx := y * COLS
		if cells[idx] & LEFT:
			stack.append(idx)
			seen[idx] = true
	while not stack.is_empty():
		var idx: int = stack.pop_back()
		var x := idx % COLS
		var y := idx / COLS
		for dir in DIR_VECTORS.keys():
			if not (cells[idx] & dir):
				continue
			var nx: int = x + DIR_VECTORS[dir].x
			var ny: int = y + DIR_VECTORS[dir].y
			if nx < 0 or nx >= COLS or ny < 0 or ny >= ROWS:
				continue
			var n_idx := ny * COLS + nx
			# 隣のマスもこちらへ開いていて初めてつながる
			if not (cells[n_idx] & OPPOSITE[dir]):
				continue
			if seen.has(n_idx):
				continue
			seen[n_idx] = true
			stack.append(n_idx)
	return seen

## 源からたどれるマスのうち、右端で右に開いているものがあれば通っている。
func _is_solved() -> bool:
	var live := _connected_cells()
	for y in range(ROWS):
		var idx := y * COLS + (COLS - 1)
		if live.has(idx) and (cells[idx] & RIGHT):
			return true
	return false

func _on_give_up() -> void:
	_running = false
	visible = false
	cancelled.emit()
