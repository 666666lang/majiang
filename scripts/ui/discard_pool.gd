class_name DiscardPool
extends Control
## 一家的牌河。
##
## 最多 6 列 × 3 行：第一行离自己最近，往桌子中心方向长。
## 整块牌河按座位方向旋转，所以牌面上字的朝向、以及长牌的方向
## 都会自动跟真实牌桌一致（对面那家看到的是倒过来的牌）。

const COLS := 6
const ROWS := 3
const DROP_HEIGHT := 46.0   # 落桌时从多高处下来
const DROP_TIME := 0.26

var tile_size := Vector2(26, 37)
var _kinds: Array[int] = []
var _tiles: Array[TileWidget] = []


func setup(p_tile_size: Vector2, facing_radians: float) -> void:
	tile_size = p_tile_size
	var box := Vector2(COLS * tile_size.x, ROWS * tile_size.y)
	custom_minimum_size = box
	size = box
	rotation = facing_radians
	pivot_offset = box * 0.5


func set_discards(kinds: Array) -> void:
	## 同步牌河内容：多出来的牌就落下来，少了（比如重开一局）就整体重建。
	if kinds.size() <= _kinds.size():
		if kinds.size() < _kinds.size():
			_kinds.clear()
			_clear_tiles()
			for kind in kinds:
				_kinds.append(kind)
				_add_tile(_kinds.size() - 1, false)
		return
	for i in range(_kinds.size(), kinds.size()):
		_kinds.append(kinds[i])
		_add_tile(i, true)


func highlight_last(value: bool) -> void:
	## 正在等玩家决定的那一张（荣和 / 碰 / 杠）描金
	for i in _tiles.size():
		_tiles[i].set_selected(value and i == _tiles.size() - 1)


func _clear_tiles() -> void:
	for tile in _tiles:
		remove_child(tile)
		tile.queue_free()
	_tiles.clear()


func _add_tile(index: int, animate: bool) -> void:
	@warning_ignore("integer_division")
	var row := index / COLS
	var col := index % COLS
	# 第一行贴着自己（局部坐标的下方），一行一行往远处排
	var target := Vector2(col * tile_size.x, size.y - float(row + 1) * tile_size.y)

	var tile := TileWidget.new()
	tile.setup(_kinds[index])
	tile.set_tile_size(tile_size)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.position = target
	add_child(tile)
	_tiles.append(tile)

	if not animate:
		return
	# 牌河整块是旋转过的，所以「从上方落下」要换算回本地的方向；
	# 这样不管哪一家，牌看上去都是从画面上方落到桌上。
	var from := target + Vector2(0.0, -DROP_HEIGHT).rotated(-rotation)
	tile.position = from
	tile.modulate.a = 0.0
	var tween := tile.create_tween()
	tween.set_parallel(true)
	tween.tween_property(tile, "modulate:a", 1.0, 0.14)
	tween.tween_property(tile, "position", target, DROP_TIME) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
