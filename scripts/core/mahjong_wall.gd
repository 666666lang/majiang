class_name MahjongWall
extends RefCounted
## 牌墙：一副牌的洗牌与摸牌。
##
## 默认就是 136 张无花牌；但删牌机制会改牌库（删掉的牌永久消失、跨关继承），
## 所以这里支持「指定牌库」。牌摸空了会自动重洗一副同样的牌库——
## 一副 136 张不够打 24 关，重洗之后牌库的构成照样是删过牌之后的样子。

var _tiles: Array[int] = []
var _next: int = 0
var _rng := RandomNumberGenerator.new()
## 这一局的牌库（不再是固定的 136 张，删牌之后会少）
var _source: Array[int] = []


func _init(rng_seed: int = 0, deck: Array = []) -> void:
	reset(rng_seed, deck)


func reset(rng_seed: int = 0, deck: Array = []) -> void:
	_source.clear()
	if deck.is_empty():
		# 没指定就用标准牌库
		for kind in TileCodec.KIND_COUNT:
			for copy in TileCodec.COPIES_PER_KIND:
				_source.append(kind)
	else:
		for tile in deck:
			_source.append(tile)
	if rng_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = rng_seed
	_refill()


func _refill() -> void:
	## 重洗一副：把牌库整个复制一份洗开
	_tiles = _source.duplicate()
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
	if _source.is_empty():
		return -1
	if _next >= _tiles.size():
		_refill()   # 摸空了就重洗，牌库跨关继承，不会摸干
	var tile := _tiles[_next]
	_next += 1
	return tile


func stack_next(kind: int, offset: int = 0) -> void:
	## 调试/测试用：把后面第 offset 张会摸到的牌换成指定牌。
	var index := _next + offset
	if index >= _tiles.size() and not _source.is_empty():
		# 已经摸到这一副的末尾了，先重洗再放
		var left := _tiles.size() - _next
		_refill()
		index = offset - left
	if index < 0:
		index = 0
	if index < _tiles.size() and kind >= 0 and kind < TileCodec.KIND_COUNT:
		_tiles[index] = kind
