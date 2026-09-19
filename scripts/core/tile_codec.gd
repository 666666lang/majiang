class_name TileCodec
extends RefCounted
## 麻将牌的编号与显示工具。
##
## 本作使用「无花牌」牌库：34 种牌 × 4 张 = 136 张。
## 编号约定（kind）：
##   0..8   万 1..9
##   9..17  筒 1..9
##   18..26 条 1..9
##   27..30 东南西北
##   31..33 中发白
##
## 春夏秋冬、梅兰竹菊这 8 张花牌不在编号体系内，
## 因此 MahjongWall 构筑牌墙时天然不可能包含它们。

enum Suit { WAN = 0, TONG = 1, TIAO = 2, WIND = 3, DRAGON = 4 }

const KIND_COUNT := 34
const COPIES_PER_KIND := 4
const DECK_SIZE := KIND_COUNT * COPIES_PER_KIND  # 136
const BASE_TILE_SCORE := 10

const SUIT_NAMES := {
	0: "万",
	1: "筒",
	2: "条",
	3: "风",
	4: "箭",
}

const _WAN_NAMES := ["一万", "二万", "三万", "四万", "五万", "六万", "七万", "八万", "九万"]
const _TONG_NAMES := ["一筒", "二筒", "三筒", "四筒", "五筒", "六筒", "七筒", "八筒", "九筒"]
const _TIAO_NAMES := ["一条", "二条", "三条", "四条", "五条", "六条", "七条", "八条", "九条"]
const _WIND_NAMES := ["東", "南", "西", "北"]
const _DRAGON_NAMES := ["中", "發", "白"]


static func suit_of(kind: int) -> int:
	if kind < 9:
		return Suit.WAN
	if kind < 18:
		return Suit.TONG
	if kind < 27:
		return Suit.TIAO
	if kind < 31:
		return Suit.WIND
	return Suit.DRAGON


static func rank_of(kind: int) -> int:
	# 数牌返回 1..9；风牌返回 1..4（东南西北）；箭牌返回 1..3（中发白）
	if kind < 27:
		return kind % 9 + 1
	if kind < 31:
		return kind - 27 + 1
	return kind - 31 + 1


static func kind_of(suit: int, rank: int) -> int:
	match suit:
		Suit.WAN:
			return rank - 1
		Suit.TONG:
			return 9 + rank - 1
		Suit.TIAO:
			return 18 + rank - 1
		Suit.WIND:
			return 27 + rank - 1
		_:
			return 31 + rank - 1


static func is_number_suit(kind: int) -> bool:
	return kind >= 0 and kind < 27


static func is_honor(kind: int) -> bool:
	return kind >= 27 and kind < KIND_COUNT


static func is_terminal(kind: int) -> bool:
	# 老头牌：一万/九万/一筒/九筒/一条/九条
	return is_number_suit(kind) and (rank_of(kind) == 1 or rank_of(kind) == 9)


static func is_terminal_or_honor(kind: int) -> bool:
	return is_terminal(kind) or is_honor(kind)


static func display_name(kind: int) -> String:
	if kind < 0 or kind >= KIND_COUNT:
		return "?"
	if kind < 9:
		return _WAN_NAMES[kind]
	if kind < 18:
		return _TONG_NAMES[kind - 9]
	if kind < 27:
		return _TIAO_NAMES[kind - 18]
	if kind < 31:
		return _WIND_NAMES[kind - 27]
	return _DRAGON_NAMES[kind - 31]


static func short_name(kind: int) -> String:
	# 紧凑写法，用于听牌提示一类的场合：三万 -> 3万，东 -> 东
	if kind < 0 or kind >= KIND_COUNT:
		return "?"
	if kind < 27:
		return "%d%s" % [rank_of(kind), SUIT_NAMES[suit_of(kind)]]
	return display_name(kind)


static func names_of(kinds: Array) -> String:
	var parts := PackedStringArray()
	for k in kinds:
		parts.append(display_name(k))
	return " ".join(parts)


static func base_score(kind: int) -> int:
	## 一张牌的基础分值。以后想让某些牌更值钱（比如字牌、幺九），改这一个函数就行。
	if kind < 0 or kind >= KIND_COUNT:
		return 0
	return BASE_TILE_SCORE
