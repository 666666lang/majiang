class_name MahjongRound
extends RefCounted
## 一局的流程（一共几巡由关卡表决定）。玩家始终是庄家，
## 所以起手 14 张、第一巡不摸牌直接打出。
##
## 花牌要在 start() 之前登记到 flowers 里——满天星这种会改巡数，
## start() 里就要用到。
##
## 一轮的顺序：
##   0. 第一巡：庄家手里已有 14 张，直接打出一张（起手就成牌就是天胡）
##   1. 之后每一巡：玩家摸一张（此时 14 张，判定自摸）
##   2. 玩家打出一张，回到 13 张
##   3. 玩家换完牌之后才轮到电脑：电脑一张一张地打，共 3 张，
##      每打完一张就检查玩家能不能荣和 / 碰，能就停下来问玩家
##   4. 玩家碰了之后可以立刻再打一张，电脑剩下没打完的接着出完
##
## 碰、明杠、暗杠记在 melds 里（碰 3 张，两种杠都是 4 张），手上只剩「暗牌」。
## 暗牌张数永远是 3n + 1（等牌）或 3n + 2（刚摸到 / 刚吃进一张），
## 所以胡牌判定只看暗牌就够：暗牌拆成 (4 - 副露副数) 个面子 + 1 将即可。

signal changed
signal finished(won: bool, description: String)

enum State { READY, DISCARDING, AI_TURN, CLAIM, WON, LOST }

const START_HAND_SIZE := 14   # 庄家起手 14 张
const AI_DISCARDS_PER_TURN := 3
const PONG_SCORE_MULTIPLIER := 2  # 碰的计分倍数：三张牌分值相加再乘这个数
const KONG_SCORE_MULTIPLIER := 5  # 明杠的计分倍数：四张牌分值相加再乘这个数
const CONCEALED_KONG_SCORE_MULTIPLIER := 6  # 暗杠的计分倍数（自己扣的，给得更高）
const REPEAT_FLOWER_MULTIPLIER := 5         # 荷花：牌河里已有同样的牌时，这一张 ×5
const STAR_FLOWER_EXTRA_TOURS := 3          # 满天星（史诗）：每一关多给三巡
## 胡牌的计分倍数：全部牌的分值相加再乘下面这个数，三种胡法各自一档
const WIN_SCORE_MULTIPLIER := 10        # 荣和（胡别人打出的牌）
const TSUMO_SCORE_MULTIPLIER := 20      # 自摸
const HEAVENLY_SCORE_MULTIPLIER := 48   # 天胡（庄家起手 14 张直接成牌）

var wall: MahjongWall
var hand: PlayerHand
var state: int = State.READY
var tour: int = 1             # 当前第几巡
var level: int = 1            # 当前第几关
var target_score: int = 0     # 本关目标分数
var total_tours: int = 0      # 本关一共几巡
var discards: Array[int] = []      # 自己打出的牌
var ai_discards: Array[int] = []   # 电脑打出的牌（被碰走/被胡的会从这里拿掉）
## 副露。每一项形如 {"kind": 牌的编号, "kong": 是否杠}，碰算 3 张、杠算 4 张。
var melds: Array[Dictionary] = []
var last_drawn: int = -1
var claim_tile: int = -1           # 正在等玩家决定要不要的那张牌
var can_ron: bool = false
var can_pong: bool = false
var can_kong: bool = false
var winning_tile: int = -1         # 结算时用来高亮的胡牌张
var result_text: String = ""
var rng_seed: int = 0
## 道具加成：按类别给「每张牌基础分」加值（本局有效）
var bonus_wan: int = 0
var bonus_tong: int = 0
var bonus_tiao: int = 0
var bonus_honor: int = 0
## 本局买到的花牌效果（效果代号，比如 "combo"）
var flowers: Array[String] = []
## 桃花：连续「摸什么打什么」的连击数（断掉归零）
var combo_streak: int = 0
var _claim_broke_streak: bool = false   # 碰 / 杠 之后的打出必然打断连击
## 紫罗兰：换牌时弃掉的牌。不进牌河、不给分，也不会再回到牌墙里。
var swapped: Array[int] = []
var _swap_window: bool = false   # 「这一关开局」的换牌窗口开着没（一关只开一次）
## 刚换进来的牌理完牌之后排在下标几，界面拿它播入场动画
var swap_positions: Array[int] = []
var draw_serial: int = 0           # 摸牌次数（含杠后补摸），界面靠它判断该不该播摸牌动画
var score: int = 0                 # 本局得分
var score_from_discards: int = 0   # 其中「打出」贡献的部分
var score_from_pongs: int = 0      # 其中「碰」贡献的部分
var score_from_kongs: int = 0      # 其中「杠」贡献的部分
var score_from_win: int = 0        # 其中「胡牌」贡献的部分
var last_score_gain: int = 0       # 最近一次得分变化
var last_score_reason: String = "" # 最近一次得分的来源
var _ai_discards_pending: int = 0
var _ai_discards_shown_from: int = 0  # 本轮电脑出牌在 ai_discards 里的起点


func start(seed_value: int = 0, preset: Array = [], level_value: int = 1) -> void:
	## preset 只给测试用：指定起手那 14 张（牌墙照样按发牌张数前进）
	level = clampi(level_value, 1, LevelTable.MAX_LEVEL)
	target_score = LevelTable.target_score(level)
	total_tours = LevelTable.tours(level) + flower_extra_tours()
	rng_seed = seed_value
	wall = MahjongWall.new(seed_value)
	hand = PlayerHand.new()
	discards = []
	ai_discards = []
	melds = []

	var dealt: Array[int] = []
	for i in START_HAND_SIZE:
		var tile := wall.draw()
		if tile >= 0:
			dealt.append(tile)
	hand.reset(dealt)
	if not preset.is_empty():
		hand.reset(preset)

	tour = 1
	last_drawn = -1
	claim_tile = -1
	can_ron = false
	can_pong = false
	can_kong = false
	winning_tile = -1
	result_text = ""
	draw_serial = 0
	score = 0
	score_from_discards = 0
	score_from_pongs = 0
	score_from_kongs = 0
	score_from_win = 0
	last_score_gain = 0
	last_score_reason = ""
	swapped = []
	_swap_window = false
	swap_positions = []
	_ai_discards_pending = 0
	_ai_discards_shown_from = 0

	# 庄家起手 14 张就能成牌，那就是天胡
	if WinChecker.is_winning_hand(hand.tiles):
		_award_win_score("天胡", HEAVENLY_SCORE_MULTIPLIER)
		result_text = _win_text("天胡 · %s" % WinChecker.describe_win(hand.tiles))
		state = State.WON
		changed.emit()
		finished.emit(true, result_text)
		return

	# 第一巡不摸牌，直接打出一张
	state = State.DISCARDING
	_swap_window = true   # 紫罗兰：一关（回合）只有开局这一次换牌机会
	changed.emit()


# ---------------------------------------------------------------- 玩家的回合

func can_draw() -> bool:
	return state == State.READY


func draw_tile() -> int:
	## 用掉一次换牌机会，摸一张牌；如果这 14 张能和牌就立刻结算。
	if not can_draw():
		return -1
	_swap_window = false   # 摸了牌，这一关的换牌机会就过去了
	var tile := wall.draw()
	if tile < 0:
		_finish(false, "牌墙摸空了")
		return -1

	hand.set_drawn(tile)
	last_drawn = tile
	draw_serial += 1

	var all := hand.all_tiles()
	if WinChecker.is_winning_hand(all):
		winning_tile = tile
		_award_win_score("自摸", TSUMO_SCORE_MULTIPLIER)
		result_text = _win_text("自摸 · %s" % WinChecker.describe_win(all))
		state = State.WON
		changed.emit()
		finished.emit(true, result_text)
		return tile

	# 摸完牌先等玩家决定打哪张：电脑要等玩家换完牌才行动
	state = State.DISCARDING
	changed.emit()
	return tile


func discard(index: int) -> int:
	## 打出一张牌。玩家打完之后才轮到电脑出牌。
	if state != State.DISCARDING:
		return -1
	_swap_window = false   # 打出去之后这一关的换牌机会就过去了
	# 打的是不是刚摸到的那张？（要在拿走之前判断）
	var from_draw := hand.has_drawn() and index == hand.tiles.size()
	var tile := hand.take(index)
	if tile < 0:
		return -1
	hand.settle()

	# 桃花：连续「摸什么打什么」可以把这张的分数翻倍，断了就归零。
	# 碰 / 杠 之后的打出一定打断（哪怕打的是补摸上来的那张）。
	if has_flower("combo"):
		if from_draw and not _claim_broke_streak:
			combo_streak += 1
		else:
			combo_streak = 0
	_claim_broke_streak = false

	# 荷花：打出的这张，牌河里已经有同样的了
	var repeat_in_pile := discards.has(tile)
	discards.append(tile)
	last_drawn = -1
	var gained := tile_score(tile)
	var reason := "打出 %s" % TileCodec.display_name(tile)
	if repeat_in_pile and has_flower("repeat"):
		gained *= REPEAT_FLOWER_MULTIPLIER
		reason += " ×%d（牌河已有同样的）" % REPEAT_FLOWER_MULTIPLIER
	if combo_streak > 1:
		gained *= combo_streak
		reason += " ×%d（桃花连击）" % combo_streak
	_add_score(gained, reason)
	score_from_discards += gained

	# 这一张打出去刚好达标，本关就到此为止，不用再轮到电脑
	_check_target()
	if state == State.WON:
		return tile

	if _ai_discards_pending > 0:
		# 碰完之后打出的那一张：电脑本轮剩下的牌接着出
		state = State.AI_TURN
		changed.emit()
	else:
		start_opponent_turn()
	return tile


# ---------------------------------------------------------------- 电脑的回合

func start_opponent_turn() -> void:
	state = State.AI_TURN
	_ai_discards_shown_from = ai_discards.size()
	_ai_discards_pending = AI_DISCARDS_PER_TURN
	changed.emit()


func opponent_discard_once() -> int:
	## 电脑打出一张，并立刻检测玩家能不能响应这一张。
	## 返回打出的牌；-1 表示电脑这一轮已经出完了。
	if state != State.AI_TURN or _ai_discards_pending <= 0:
		return -1
	var tile := wall.draw()
	if tile < 0:
		_ai_discards_pending = 0
		return -1
	ai_discards.append(tile)
	_ai_discards_pending -= 1

	can_ron = can_ron_on(tile)
	can_pong = can_pong_on(tile)
	can_kong = can_kong_on(tile)
	if can_ron or can_pong or can_kong:
		claim_tile = tile
		state = State.CLAIM
	changed.emit()
	return tile


func opponent_turn_finished() -> bool:
	return _ai_discards_pending <= 0


func end_opponent_turn() -> void:
	## 电脑这一轮出完了，收尾：要么轮回玩家，要么本局结束。
	## 注意：本关可能已经在玩家那边达标结束了，这时候不能再改状态。
	if is_over() or state == State.CLAIM or _ai_discards_pending > 0:
		return
	_end_turn()


func run_opponent_turn() -> void:
	## 不带动画地把电脑这一轮跑完；遇到荣和/碰的机会一律放弃。
	## 界面用的是逐张出牌的流程，这个方法留给测试和调试。
	while not opponent_turn_finished():
		if opponent_discard_once() < 0:
			break
		if state == State.CLAIM:
			pass_claim()
	end_opponent_turn()


func ai_discards_this_turn() -> Array:
	## 只取本轮电脑打出的那几张（画面只画这些，历史的牌不占地方）。
	return ai_discards.slice(_ai_discards_shown_from)


# ---------------------------------------------------------------- 响应电脑的牌

func can_ron_on(tile: int) -> bool:
	## 荣和判定用的是手上的暗牌（刚摸的那张不在里面）。
	var probe: Array = hand.tiles.duplicate()
	probe.append(tile)
	return WinChecker.is_winning_hand(probe)


func can_pong_on(tile: int) -> bool:
	## 手里有两张一样的，才能碰。
	return hand_count_of(tile) >= 2


func can_kong_on(tile: int) -> bool:
	## 手里有三张一样的，电脑又打出第四张，才能杠。
	return hand_count_of(tile) >= 3


func hand_count_of(tile: int) -> int:
	var count := 0
	for owned in hand.tiles:
		if owned == tile:
			count += 1
	return count


func has_claim() -> bool:
	return state == State.CLAIM


func declare_ron() -> void:
	if state != State.CLAIM or not can_ron:
		return
	winning_tile = claim_tile
	var probe: Array = hand.tiles.duplicate()
	probe.append(claim_tile)
	hand.keep_discarded_tile(claim_tile)
	_award_win_score("荣和", WIN_SCORE_MULTIPLIER)
	result_text = _win_text("荣和 · %s" % WinChecker.describe_win(probe))
	_take_claimed_tile_from_discards()
	_clear_claim()
	state = State.WON
	changed.emit()
	finished.emit(true, result_text)


func declare_pong() -> bool:
	## 碰：把自己手里的两张拿出来，和电脑打出的一张凑成一副。
	## 碰完必须打出一张，所以进入 DISCARDING 状态。
	if state != State.CLAIM or not can_pong:
		return false
	var tile := claim_tile
	var removed := 0
	for i in range(hand.tiles.size() - 1, -1, -1):
		if removed >= 2:
			break
		if hand.tiles[i] == tile:
			hand.tiles.remove_at(i)
			removed += 1
	if removed < 2:
		return false
	hand.sort_tiles()
	melds.append({"kind": tile, "kong": false})

	# 碰的计分：三张牌的分值加起来，再翻倍
	var each := tile_score(tile)
	var gained := each * 3 * PONG_SCORE_MULTIPLIER
	_add_score(gained, "碰 %s（%d+%d+%d）×%d" % [
		TileCodec.display_name(tile), each, each, each, PONG_SCORE_MULTIPLIER,
	])
	score_from_pongs += gained

	_take_claimed_tile_from_discards()
	_clear_claim()
	_claim_broke_streak = true  # 碰之后的打出会打断桃花连击
	last_drawn = -1
	state = State.DISCARDING
	changed.emit()
	_check_target()
	return true


func declare_kong() -> bool:
	## 杠：手里三张 + 电脑打出的第四张，凑成四张一副。
	## 杠完要补摸一张（这时候如果成牌就是杠上开花），然后再打出一张。
	if state != State.CLAIM or not can_kong:
		return false
	var tile := claim_tile
	var removed := 0
	for i in range(hand.tiles.size() - 1, -1, -1):
		if removed >= 3:
			break
		if hand.tiles[i] == tile:
			hand.tiles.remove_at(i)
			removed += 1
	if removed < 3:
		return false
	hand.sort_tiles()
	melds.append({"kind": tile, "kong": true})

	var each := tile_score(tile)
	var gained := each * 4 * KONG_SCORE_MULTIPLIER
	_add_score(gained, "杠 %s（%d+%d+%d+%d）×%d" % [
		TileCodec.display_name(tile), each, each, each, each, KONG_SCORE_MULTIPLIER,
	])
	score_from_kongs += gained

	_take_claimed_tile_from_discards()
	_clear_claim()
	last_drawn = -1
	_draw_after_kong()
	_check_target()
	return true


func can_concealed_kong() -> bool:
	## 暗杠：自己手上凑齐了四张一样的（刚摸到第四张的时候最常见）
	return state == State.DISCARDING and _concealed_kong_kind() >= 0


func tile_score(kind: int) -> int:
	## 一张牌的实际分值 = 基础分 + 道具加成（按花色/字牌分类）
	return TileCodec.base_score(kind) + bonus_for(kind)


func bonus_for(kind: int) -> int:
	if TileCodec.is_honor(kind):
		return bonus_honor
	if kind < 9:
		return bonus_wan
	if kind < 18:
		return bonus_tong
	return bonus_tiao


func apply_bonus(key: String, amount: int) -> void:
	## 买下道具时调用，按类别累加
	match key:
		"wan":
			bonus_wan += amount
		"tong":
			bonus_tong += amount
		"tiao":
			bonus_tiao += amount
		"honor":
			bonus_honor += amount


func has_flower(key: String) -> bool:
	return flowers.has(key)


func flower_extra_tours() -> int:
	## 花牌带来的额外巡数（目前只有满天星）
	return STAR_FLOWER_EXTRA_TOURS if has_flower("star") else 0


# ---------------------------------------------------------------- 紫罗兰：每关（回合）开局换牌

func can_swap() -> bool:
	## 紫罗兰：每个回合（每关）开局、还没摸牌也没打牌的时候，
	## 可以弃掉手里若干张，再从牌墙摸等量的新牌。一个回合只有这一次机会。
	return has_flower("violet") and _swap_window


func swap_tiles(indices: Array) -> int:
	## 弃掉指定的这几张，再摸同样多的牌，手牌张数不变。
	## 弃掉的牌不进牌河（不算打出的牌、不给分），但也不会再回到牌墙里。
	## 返回实际换了几张（牌墙不够时可能比选得少）。
	if not can_swap():
		return 0
	var picked: Array[int] = []
	var seen := {}
	for value in indices:
		var index := int(value)
		if index < 0 or index >= hand.tiles.size() or seen.has(index):
			continue
		seen[index] = true
		picked.append(index)
	if picked.is_empty():
		return 0
	picked.sort()

	# 先把新牌摸出来：这样牌墙快见底时也只是少换几张，手牌张数不会变少
	var replacements: Array[int] = []
	for i in picked.size():
		var tile := wall.draw()
		if tile < 0:
			break
		replacements.append(tile)
	if replacements.is_empty():
		return 0

	# 从后往前删，免得下标错位
	for i in range(replacements.size() - 1, -1, -1):
		var index: int = picked[i]
		swapped.append(hand.tiles[index])
		hand.tiles.remove_at(index)

	# 重新理牌，同时记下新牌最后落在哪几个位置（同种的旧牌排在前面），
	# 界面照着这几个位置播「刚摸进来」的入场动画。
	var merged: Array = []
	for tile in hand.tiles:
		merged.append({"kind": tile, "fresh": false})
	for tile in replacements:
		merged.append({"kind": tile, "fresh": true})
	merged.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["kind"] != b["kind"]:
			return a["kind"] < b["kind"]
		return b["fresh"] and not a["fresh"])
	hand.tiles.clear()
	swap_positions = []
	for i in merged.size():
		hand.tiles.append(merged[i]["kind"])
		if merged[i]["fresh"]:
			swap_positions.append(i)

	_swap_window = false   # 一个回合（一关）只换这一次，换几张都一样
	_check_heavenly_after_swap()
	changed.emit()
	return replacements.size()


func _check_heavenly_after_swap() -> void:
	## 换牌之后手里依旧是庄家开局那 14 张，所以照样可以凑成天胡
	if tour != 1 or is_over():
		return
	if hand.tiles.size() != START_HAND_SIZE or hand.has_drawn():
		return
	if not WinChecker.is_winning_hand(hand.tiles):
		return
	winning_tile = -1
	_award_win_score("天胡", HEAVENLY_SCORE_MULTIPLIER)
	result_text = _win_text("天胡 · %s" % WinChecker.describe_win(hand.tiles))
	state = State.WON
	finished.emit(true, result_text)


func _concealed_kong_kind() -> int:
	var counts := WinChecker.to_counts(hand.all_tiles())
	for kind in TileCodec.KIND_COUNT:
		if counts[kind] >= TileCodec.COPIES_PER_KIND:
			return kind
	return -1


func declare_concealed_kong() -> bool:
	## 暗杠：四张全在自己手上，扣下去，补摸一张，再打出一张。
	if not can_concealed_kong():
		return false
	var tile := _concealed_kong_kind()
	if hand.remove_all(tile) != TileCodec.COPIES_PER_KIND:
		return false

	melds.append({"kind": tile, "kong": true, "concealed": true})
	var each := tile_score(tile)
	var gained := each * 4 * CONCEALED_KONG_SCORE_MULTIPLIER
	_add_score(gained, "暗杠 %s（%d+%d+%d+%d）×%d" % [
		TileCodec.display_name(tile), each, each, each, each, CONCEALED_KONG_SCORE_MULTIPLIER,
	])
	score_from_kongs += gained
	last_drawn = -1
	_draw_after_kong()
	_check_target()
	return true


func _draw_after_kong() -> void:
	## 杠完补摸一张；这时候成牌就是杠上开花。
	var replacement := wall.draw()
	if replacement < 0:
		state = State.DISCARDING
		changed.emit()
		return
	hand.set_drawn(replacement)
	last_drawn = replacement
	draw_serial += 1
	var all := hand.all_tiles()
	if WinChecker.is_winning_hand(all):
		winning_tile = replacement
		_award_win_score("杠上开花", TSUMO_SCORE_MULTIPLIER)
		result_text = _win_text("杠上开花 · %s" % WinChecker.describe_win(all))
		state = State.WON
		changed.emit()
		finished.emit(true, result_text)
		return
	state = State.DISCARDING
	changed.emit()


func pass_claim() -> void:
	## 这张不要，电脑接着出牌。
	if state != State.CLAIM:
		return
	_clear_claim()
	state = State.AI_TURN
	changed.emit()


func _clear_claim() -> void:
	claim_tile = -1
	can_ron = false
	can_pong = false
	can_kong = false


func _add_score(gained: int, reason: String) -> void:
	score += gained
	last_score_gain = gained
	last_score_reason = reason


func winning_hand_tiles() -> Array:
	## 胡牌时要算分的所有牌：手上的暗牌（含刚摸到 / 刚胡到的那张）加副露。
	## 通常正好 14 张；杠过的牌型因为一副占 4 张，会是 15 张。
	var all: Array = hand.all_tiles()
	for tile in meld_tiles():
		all.append(tile)
	return all


func _award_win_score(label: String, multiplier: int) -> void:
	## 胡牌计分：全部牌的分值加起来，再乘这个胡法的倍数。
	var tiles := winning_hand_tiles()
	var base_total := 0
	for tile in tiles:
		base_total += tile_score(tile)
	var points := base_total * multiplier
	_add_score(points, "%s %d 张牌共 %d 分 × %d" % [
		label, tiles.size(), base_total, multiplier,
	])
	score_from_win += points


func _take_claimed_tile_from_discards() -> void:
	## 被碰走 / 被胡的牌已经从电脑的牌河里拿走了，不该再算成「打出去的牌」。
	if ai_discards.is_empty():
		return
	var last := ai_discards.size() - 1
	if ai_discards[last] != claim_tile:
		return
	ai_discards.remove_at(last)
	if _ai_discards_shown_from > ai_discards.size():
		_ai_discards_shown_from = ai_discards.size()


func _end_turn() -> void:
	if is_over():
		return  # 本关已经结束，别把结果冲掉
	if tour >= total_tours:
		state = State.LOST
		result_text = "%d 巡打完 · %d 分（目标 %d 分）" % [total_tours, score, target_score]
		changed.emit()
		finished.emit(false, result_text)
	else:
		tour += 1
		state = State.READY
		changed.emit()


func _check_target() -> void:
	## 达到本关目标分数就立刻过关，不管还剩几巡。
	if state == State.WON or state == State.LOST:
		return
	if score < target_score:
		return
	result_text = "达标 %d 分（目标 %d 分）· 过关" % [score, target_score]
	state = State.WON
	changed.emit()
	finished.emit(true, result_text)


func _win_text(base: String) -> String:
	## 胡牌和达标可能同时发生，这里把两件事写在一起
	if score >= target_score:
		return "%s · 过关（%d 分）" % [base, score]
	return base


func _finish(won: bool, description: String) -> void:
	state = State.WON if won else State.LOST
	result_text = description
	changed.emit()
	finished.emit(won, description)


func is_over() -> bool:
	return state == State.WON or state == State.LOST


func remaining_tours() -> int:
	## 本关还剩几巡没打
	return maxi(0, total_tours - tour)


func clear_coin_reward() -> int:
	## 过关拿到的银两 = 关卡奖励 + 剩余巡数（剩几巡就多给几两）
	return LevelTable.clear_reward(level) + remaining_tours()


# ---------------------------------------------------------------- 剩余张数与提示

func visible_count(kind: int) -> int:
	## 这张牌已经露面的张数：自己手上的 + 碰下的 + 自己打出的 + 电脑打出的。
	var seen := 0
	for tile in hand.all_tiles():
		if tile == kind:
			seen += 1
	for meld in melds:
		if meld["kind"] == kind:
			seen += meld_tile_count(meld)
	# 紫罗兰换牌弃掉的牌不在牌河里，但确实已经出了场，算进「露面」才对得上实际张数
	for tile in swapped:
		if tile == kind:
			seen += 1
	for tile in discards:
		if tile == kind:
			seen += 1
	for tile in ai_discards:
		if tile == kind:
			seen += 1
	return seen


func meld_tile_count(meld: Dictionary) -> int:
	## 一副副露实际占几张牌：碰 3 张，杠 4 张。
	return 4 if meld.get("kong", false) else 3


func meld_tiles() -> Array:
	## 把副露摊开成一张张牌，方便算分和统计。
	var tiles: Array = []
	for meld in melds:
		for i in meld_tile_count(meld):
			tiles.append(meld["kind"])
	return tiles


func remaining_count(kind: int) -> int:
	## 这张牌还剩几张没露面（也就是自己还有机会摸到 / 等到的张数）。
	return maxi(0, TileCodec.COPIES_PER_KIND - visible_count(kind))


func _waits_with_counts(waits: Array) -> String:
	## 提示行只排一行，听太多的牌（比如十三幺听 13 种）就只列前几种
	const MAX_SHOWN := 8
	var parts := PackedStringArray()
	var shown := mini(waits.size(), MAX_SHOWN)
	for i in shown:
		var kind: int = waits[i]
		parts.append("%s(剩%d)" % [TileCodec.short_name(kind), remaining_count(kind)])
	if waits.size() > shown:
		parts.append("…")
	return " ".join(parts)


func tenpai_hint() -> String:
	## 提示当前能胡哪些牌。
	if state == State.CLAIM:
		return claim_hint()

	if state == State.DISCARDING:
		return _discard_hint()

	if not is_over() and hand.size() % 3 == 1:
		var waits := WinChecker.find_winning_tiles(hand.tiles)
		if waits.is_empty():
			return ""  # 没听牌就不占这一行
		return "听：%s" % _waits_with_counts(waits)

	if state == State.LOST:
		var final_waits := _waits_text(hand.tiles)
		return "" if final_waits == "" else "最终手牌听：%s" % final_waits
	return ""


func claim_hint() -> String:
	if not can_ron and not can_pong and not can_kong:
		return ""
	var parts := PackedStringArray()
	if can_ron:
		var probe: Array = hand.tiles.duplicate()
		probe.append(claim_tile)
		parts.append("荣和就是 %s" % WinChecker.describe_win(probe))
	if can_kong:
		parts.append("杠完会补摸一张，再打出一张")
	elif can_pong:
		parts.append("碰完还要打出一张")
	return " ｜ ".join(parts)


func _discard_hint() -> String:
	## 找出「打出哪张之后能听牌」的选项。
	var all := hand.all_tiles()
	var lines := PackedStringArray()
	for tile in tenpai_discards():
		var rest: Array = all.duplicate()
		rest.erase(tile)
		var waits := WinChecker.find_winning_tiles(rest)
		lines.append("打 %s → 听 %s" % [TileCodec.short_name(tile), _waits_with_counts(waits)])
		if lines.size() >= 3:
			break
	if lines.is_empty():
		return ""  # 怎么打都不听牌，就不用占这一行了
	return " | ".join(lines)


func tenpai_discards() -> Array:
	## 14 张时，打出哪些牌之后能听牌（返回牌的种类）。
	## 界面拿它给这些牌画红描边，提示玩家该打哪张。
	var result: Array[int] = []
	if state != State.DISCARDING:
		return result
	var all := hand.all_tiles()
	var seen := {}
	for index in all.size():
		var tile: int = all[index]
		if seen.has(tile):
			continue
		seen[tile] = true
		var rest: Array = all.duplicate()
		rest.remove_at(index)
		if not WinChecker.find_winning_tiles(rest).is_empty():
			result.append(tile)
	return result


func _waits_text(tiles: Array) -> String:
	var waits := WinChecker.find_winning_tiles(tiles)
	if waits.is_empty():
		return ""
	return _waits_with_counts(waits)
