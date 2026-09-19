class_name MahjongWall
extends RefCounted
## 牌墙：136 张无花牌牌的洗牌与摸牌。

var _tiles: Array[int] = []
var _next: int = 0
var _rng := RandomNumberGenerator.new()


func _init(rng_seed: int = 0) -> void:
	reset(rng_seed)


func reset(rng_seed: int = 0) -> void:
	_tiles.clear()
	for kind in TileCodec.KIND_COUNT:
		for copy in TileCodec.COPIES_PER_KIND:
			_tiles.append(kind)
	if rng_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = rng_seed
	_shuffle()
	_next = 0


func _shuffle() -> void:
	# Fisher-Yates
	for i in range(_tiles.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := _tiles[i]
		_tiles[i] = _tiles[j]
		_tiles[j] = tmp


func total() -> int:
	return _tiles.size()


func remaining() -> int:
	return _tiles.size() - _next


func draw() -> int:
	if _next >= _tiles.size():
		return -1
	var tile := _tiles[_next]
	_next += 1
	return tile


func stack_next(kind: int, offset: int = 0) -> void:
	## 调试/测试用：把后面第 offset 张会摸到的牌换成指定牌。
	var index := _next + offset
	if index < _tiles.size() and kind >= 0 and kind < TileCodec.KIND_COUNT:
		_tiles[index] = kind
