class_name PlayerHand
extends RefCounted
## 玩家的手牌。
##
## tiles 是已经理顺（排序）的手牌；drawn_tile 是刚摸进来、
## 还没决定去留的那一张。手牌 + 摸牌合起来才是「全部牌」。

var tiles: Array[int] = []
var drawn_tile: int = -1


func reset(new_tiles: Array) -> void:
	tiles.clear()
	for t in new_tiles:
		tiles.append(t)
	drawn_tile = -1
	sort_tiles()


func sort_tiles() -> void:
	tiles.sort()


func has_drawn() -> bool:
	return drawn_tile >= 0


func all_tiles() -> Array:
	var all: Array = tiles.duplicate()
	if has_drawn():
		all.append(drawn_tile)
	return all


func size() -> int:
	return tiles.size() + (1 if has_drawn() else 0)


func tile_at(index: int) -> int:
	if index >= 0 and index < tiles.size():
		return tiles[index]
	if index == tiles.size() and has_drawn():
		return drawn_tile
	return -1


func set_drawn(tile: int) -> void:
	drawn_tile = tile


func take(index: int) -> int:
	## 打出第 index 张牌（index == tiles.size() 表示刚摸进来那张）。
	if index >= 0 and index < tiles.size():
		var picked: int = tiles[index]
		tiles.remove_at(index)
		return picked
	if index == tiles.size() and has_drawn():
		var drawn := drawn_tile
		drawn_tile = -1
		return drawn
	return -1


func settle() -> void:
	## 一次换牌结束：把摸到的牌并进手牌并重新理牌。
	if has_drawn():
		tiles.append(drawn_tile)
		drawn_tile = -1
	sort_tiles()


func keep_discarded_tile(tile: int) -> void:
	## 荣和：用别人打出的牌补齐手牌，自己刚摸的那张就不要了。
	drawn_tile = -1
	tiles.append(tile)
	sort_tiles()


func count_of(kind: int) -> int:
	## 手上有几张这个牌（含刚摸进来那张）
	var count := 0
	for tile in tiles:
		if tile == kind:
			count += 1
	if drawn_tile == kind:
		count += 1
	return count


func remove_all(kind: int) -> int:
	## 把某种牌全部拿走（暗杠用），返回拿走了几张
	var removed := 0
	for i in range(tiles.size() - 1, -1, -1):
		if tiles[i] == kind:
			tiles.remove_at(i)
			removed += 1
	if drawn_tile == kind:
		drawn_tile = -1
		removed += 1
	return removed
