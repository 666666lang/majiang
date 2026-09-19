class_name WinChecker
extends RefCounted
## 胡牌判定。
##
## 支持三种牌型：
##   1. 标准型：4 面子 + 1 将（面子 = 顺子或刻子）
##   2. 七对子：7 个对子
##   3. 十三幺：13 种幺九字牌各一张，外加其中任意一张重复

const REQUIRED_ORPHANS := [0, 8, 9, 17, 18, 26, 27, 28, 29, 30, 31, 32, 33]


static func to_counts(tiles: Array) -> Array[int]:
	var counts: Array[int] = []
	counts.resize(TileCodec.KIND_COUNT)
	counts.fill(0)
	for t in tiles:
		if t >= 0 and t < TileCodec.KIND_COUNT:
			counts[t] += 1
	return counts


static func is_winning_hand(tiles: Array) -> bool:
	## tiles.size() 必须是 3n + 2（13 张听牌 + 1 张 = 14 张）
	if tiles.size() < 2 or tiles.size() % 3 != 2:
		return false
	var counts := to_counts(tiles)
	if _is_thirteen_orphans(counts, tiles.size()):
		return true
	if _is_seven_pairs(counts, tiles.size()):
		return true
	return _has_standard_shape(counts, tiles.size())


static func describe_win(tiles: Array) -> String:
	var counts := to_counts(tiles)
	if _is_thirteen_orphans(counts, tiles.size()):
		return "十三幺"
	if _is_seven_pairs(counts, tiles.size()):
		return "七对子"
	var honors := 0
	for kind in TileCodec.KIND_COUNT:
		if TileCodec.is_honor(kind):
			honors += counts[kind]
	if honors == tiles.size():
		return "字一色 · 4 面子 + 1 将"
	return "4 面子 + 1 将"


static func is_tenpai(hand_tiles: Array) -> bool:
	return not find_winning_tiles(hand_tiles).is_empty()


static func find_winning_tiles(hand_tiles: Array) -> Array:
	## 传入 3n + 1 张（典型是 13 张），返回所有能补成胡牌的牌。
	var result: Array[int] = []
	if hand_tiles.size() < 1 or hand_tiles.size() % 3 != 1:
		return result
	var counts := to_counts(hand_tiles)
	for kind in TileCodec.KIND_COUNT:
		if counts[kind] >= TileCodec.COPIES_PER_KIND:
			continue
		var probe := hand_tiles.duplicate()
		probe.append(kind)
		if is_winning_hand(probe):
			result.append(kind)
	return result


static func _is_seven_pairs(counts: Array[int], total: int) -> bool:
	if total != 14:
		return false
	var pairs := 0
	for kind in TileCodec.KIND_COUNT:
		if counts[kind] == 0:
			continue
		if counts[kind] != 2:
			return false
		pairs += 1
	return pairs == 7


static func _is_thirteen_orphans(counts: Array[int], total: int) -> bool:
	if total != 14:
		return false
	var pairs := 0
	for kind in TileCodec.KIND_COUNT:
		var c := counts[kind]
		if c == 0:
			continue
		if not TileCodec.is_terminal_or_honor(kind):
			return false
		if c == 2:
			pairs += 1
		elif c != 1:
			return false
	if pairs != 1:
		return false
	for kind in REQUIRED_ORPHANS:
		if counts[kind] < 1:
			return false
	return true


static func _has_standard_shape(counts: Array[int], total: int) -> bool:
	@warning_ignore("integer_division")
	var melds_needed := (total - 2) / 3
	for pair_kind in TileCodec.KIND_COUNT:
		if counts[pair_kind] < 2:
			continue
		var rest := counts.duplicate()
		rest[pair_kind] -= 2
		if _can_form_melds(rest, melds_needed):
			return true
	return false


static func _can_form_melds(counts: Array[int], melds_needed: int) -> bool:
	if melds_needed == 0:
		for c in counts:
			if c != 0:
				return false
		return true

	var first := -1
	for kind in TileCodec.KIND_COUNT:
		if counts[kind] > 0:
			first = kind
			break
	if first < 0:
		return false

	# 刻子
	if counts[first] >= 3:
		var as_triplet := counts.duplicate()
		as_triplet[first] -= 3
		if _can_form_melds(as_triplet, melds_needed - 1):
			return true

	# 顺子（仅数牌，且不能跨花色）
	if TileCodec.is_number_suit(first) and first % 9 <= 6:
		if counts[first + 1] > 0 and counts[first + 2] > 0:
			var as_run := counts.duplicate()
			as_run[first] -= 1
			as_run[first + 1] -= 1
			as_run[first + 2] -= 1
			if _can_form_melds(as_run, melds_needed - 1):
				return true

	return false
