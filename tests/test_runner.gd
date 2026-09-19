extends SceneTree
## 无窗口测试入口：
##   godot --headless --path . --script res://tests/test_runner.gd

const TileCodecS := preload("res://scripts/core/tile_codec.gd")
const MahjongWallS := preload("res://scripts/core/mahjong_wall.gd")
const WinCheckerS := preload("res://scripts/core/win_checker.gd")
const PlayerHandS := preload("res://scripts/core/player_hand.gd")
const MahjongRoundS := preload("res://scripts/core/mahjong_round.gd")
const LevelTableS := preload("res://scripts/core/level_table.gd")
const ShopItemsS := preload("res://scripts/core/shop_items.gd")
const FlowerTilesS := preload("res://scripts/core/flower_tiles.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	_test_deck_has_no_flowers()
	_test_deal_and_swap_flow()
	_test_levels()
	_test_shop()
	_test_winning_hands()
	_test_not_winning_hands()
	_test_tenpai()
	_test_opponent_discards_and_remaining_counts()
	_test_only_current_turn_is_shown()
	_test_ai_waits_for_player()
	_test_ron()
	_test_pong()
	_test_kong()
	_test_concealed_kong()
	_test_violet_swap()
	_test_scoring()
	_test_seeded_round_is_deterministic()
	await _test_ui_scene_smoke()

	print("")
	print("通过 %d 项，失败 %d 项" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- 断言工具

func _check(condition: bool, name: String) -> void:
	if condition:
		_passed += 1
		print("  [ok]   ", name)
	else:
		_failed += 1
		print("  [FAIL] ", name)


func _check_eq(actual: Variant, expected: Variant, name: String) -> void:
	if actual == expected:
		_passed += 1
		print("  [ok]   ", name)
	else:
		_failed += 1
		print("  [FAIL] %s  实际=%s  期望=%s" % [name, str(actual), str(expected)])


func _count_melds(instance: Node) -> int:
	## 副露现在跟手牌同占一行，数「带副露标记的牌」就是副露张数
	var row: Node = instance.get("_tile_row")
	if row == null:
		return 0
	var count := 0
	for child in row.get_children():
		if child.get("is_melded") == true:
			count += 1
	return count


func _meld_matches_hand_size(instance: Node) -> bool:
	## 副露的牌得跟手牌一样大
	var row: Node = instance.get("_tile_row")
	var hand_size: Vector2 = Vector2.ZERO
	var meld_size: Vector2 = Vector2.ZERO
	for child in row.get_children():
		if child.get("is_melded") == true:
			meld_size = child.custom_minimum_size
		elif child.get("kind") != null and hand_size == Vector2.ZERO:
			hand_size = child.custom_minimum_size
	return hand_size != Vector2.ZERO and hand_size == meld_size


func _parse_hand(text: String) -> Array[int]:
	## "123m 456p 77s 11z" -> 牌编号数组（z: 1东 2南 3西 4北 5中 6发 7白）
	var out: Array[int] = []
	var nums: Array[int] = []
	for i in text.length():
		var ch := text[i]
		if ch >= "0" and ch <= "9":
			nums.append(ch.to_int())
			continue
		var base := -1
		match ch:
			"m":
				base = 0
			"p":
				base = 9
			"s":
				base = 18
			"z":
				base = 27
			_:
				continue
		for n in nums:
			out.append(base + n - 1)
		nums.clear()
	return out


func _rig_ready(seed_value: int, tiles: Array) -> MahjongRound:
	## 造一个「第一巡已打完、第二巡开始」的局面，手上就是传进来的 13 张。
	## 庄家起手 14 张，所以多塞一张重复的当第一巡打掉的那张；
	## 第一巡电脑打的三张也先安排好，免得随机出牌影响断言。
	## 目标分数调到摸不到的高度，让「达标即过关」不打断这些机制用例。
	var round_ := MahjongRoundS.new()
	round_.start(seed_value)
	round_.target_score = 999999
	var opening: Array = tiles.duplicate()
	var drop: int = tiles[0]
	opening.append(drop)
	round_.hand.reset(opening)
	for i in 3:
		round_.wall.stack_next(33 - i, i)
	# 手牌是排过序的，所以按点数找回那张多塞的牌，而不是按位置
	round_.discard(round_.hand.tiles.find(drop))
	round_.run_opponent_turn()
	return round_


# ---------------------------------------------------------------- 测试

func _test_deck_has_no_flowers() -> void:
	print("牌库（无花牌）")
	var wall := MahjongWallS.new(20260915)
	_check_eq(wall.total(), 136, "牌墙总张数是 136")
	_check_eq(TileCodecS.DECK_SIZE, 136, "牌库常量是 136")
	_check_eq(TileCodecS.KIND_COUNT, 34, "共 34 种牌")

	var counts := {}
	while wall.remaining() > 0:
		var tile: int = wall.draw()
		counts[tile] = counts.get(tile, 0) + 1
	_check_eq(counts.size(), 34, "牌墙里恰好出现 34 种牌")

	var all_four := true
	var all_in_range := true
	for kind in counts:
		if counts[kind] != 4:
			all_four = false
		if kind < 0 or kind >= 34:
			all_in_range = false
	_check(all_four, "每种牌都是 4 张")
	_check(all_in_range, "没有 34 种之外的牌（花牌不可能出现）")

	var has_flower_kind := false
	for kind in counts:
		# 花牌若混进来，会表现为某个花色里点数超过 9 或出现第 35 种以上的编号
		if TileCodecS.is_number_suit(kind) and TileCodecS.rank_of(kind) > 9:
			has_flower_kind = true
	_check(not has_flower_kind, "数牌点数都在 1..9 之间")


func _test_deal_and_swap_flow() -> void:
	print("庄家起手 14 张、第 1 关 10 巡")
	var round_ := MahjongRoundS.new()
	round_.start(4242)

	_check_eq(round_.level, 1, "默认从第 1 关开始")
	_check_eq(round_.target_score, 100, "第 1 关目标 100 分")
	_check_eq(round_.total_tours, 10, "第 1 关 10 巡")
	_check_eq(round_.hand.tiles.size(), 14, "庄家起手 14 张")
	_check_eq(round_.hand.size(), 14, "开局总牌数是 14")
	_check_eq(round_.tour, 1, "开局是第一巡")
	_check_eq(round_.state, MahjongRoundS.State.DISCARDING, "第一巡不摸牌，直接进入打牌")
	_check(not round_.can_draw(), "第一巡不能摸牌")
	_check_eq(round_.wall.remaining(), 122, "牌墙还剩 122 张")

	var sorted_ok := true
	for i in range(1, round_.hand.tiles.size()):
		if round_.hand.tiles[i] < round_.hand.tiles[i - 1]:
			sorted_ok = false
	_check(sorted_ok, "开局手牌已理牌")

	var dealt_counts := WinCheckerS.to_counts(round_.hand.tiles)
	var over_four := false
	for kind in TileCodecS.KIND_COUNT:
		if dealt_counts[kind] > 4:
			over_four = true
	_check(not over_four, "发牌没有出现同一种牌超过 4 张")

	# 一路打出去：每巡 10 分，第 10 巡刚好凑满 100 分过关
	var draws := 0
	while not round_.is_over():
		if round_.can_draw():
			draws += 1
			var drawn: int = round_.draw_tile()
			_check(drawn >= 0, "第 %d 巡摸到一张牌" % round_.tour)
			if round_.state == MahjongRoundS.State.WON:
				break
			_check_eq(round_.hand.size(), 14, "摸牌后手上有 14 张")
		round_.discard(0)
		if round_.is_over():
			break
		_check_eq(round_.state, MahjongRoundS.State.AI_TURN, "玩家打完之后才轮到电脑")
		# run_opponent_turn 会把电脑这一轮跑完，遇到荣和/碰的机会一律放弃
		round_.run_opponent_turn()
		if not round_.is_over():
			_check_eq(round_.hand.size(), 13, "打出后手上回到 13 张")

	_check_eq(round_.state, MahjongRoundS.State.WON, "打到目标分数就过关")
	_check_eq(round_.score, 100, "刚好凑满 100 分")
	_check_eq(round_.tour, 10, "打满 10 巡")
	_check_eq(draws, 9, "10 巡里摸 9 次（第一巡不摸）")
	_check_eq(round_.discards.size(), 10, "自己打出 10 张")
	_check_eq(round_.ai_discards.size(), 27, "前 9 巡电脑各打 3 张")
	_check_eq(round_.wall.remaining(), 122 - 9 - 27, "牌墙消耗 = 自己摸的 + 电脑打的")
	_check_eq(round_.score, round_.discards.size() * TileCodecS.BASE_TILE_SCORE,
		"得分 = 打出的张数 × 10")


func _test_levels() -> void:
	print("关卡参数与过关规则")
	_check_eq(LevelTableS.MAX_LEVEL, 24, "一共 24 关")
	_check_eq(LevelTableS.target_score(1), 100, "第 1 关目标 100 分")
	_check_eq(LevelTableS.target_score(2), 140, "第 2 关目标 140 分")
	_check_eq(LevelTableS.target_score(3), 180, "第 3 关目标 180 分")
	_check_eq(LevelTableS.target_score(4), 240, "第 4 关目标 240 分（第 4 关起每关 +60）")
	_check_eq(LevelTableS.target_score(5), 300, "第 5 关目标 300 分")
	_check_eq(LevelTableS.target_score(6), 360, "第 6 关目标 360 分")
	_check_eq(LevelTableS.target_score(7), 450, "第 7 关目标 450 分（这里跳到 +100）")
	_check_eq(LevelTableS.target_score(8), 550, "第 8 关目标 550 分")
	_check_eq(LevelTableS.target_score(9), 650, "第 9 关目标 650 分")
	_check_eq(LevelTableS.target_score(10), 750, "第 10 关目标 750 分")
	_check_eq(LevelTableS.target_score(23), 2050, "第 23 关目标 2050 分")
	_check_eq(LevelTableS.target_score(24), 2150, "第 24 关目标 2150 分")

	_check_eq(LevelTableS.tours(1), 10, "第 1 关 10 巡")
	_check_eq(LevelTableS.tours(3), 10, "第 3 关还是 10 巡")
	_check_eq(LevelTableS.tours(4), 11, "第 4 关 11 巡（每 3 关 +1）")
	_check_eq(LevelTableS.tours(7), 12, "第 7 关 12 巡")
	_check_eq(LevelTableS.tours(24), 17, "第 24 关 17 巡")

	_check_eq(LevelTableS.bgm_name(1), "small", "第 1 关放 small")
	_check_eq(LevelTableS.bgm_name(2), "big", "第 2 关放 big")
	_check_eq(LevelTableS.bgm_name(3), "boss", "第 3 关放 boss")
	_check_eq(LevelTableS.bgm_name(4), "small", "第 4 关回到 small")
	_check_eq(LevelTableS.bgm_name(7), "small", "第 7 关放 small")
	_check_eq(LevelTableS.bgm_name(9), "boss", "第 9 关放 boss")
	_check_eq(LevelTableS.bgm_name(24), "boss", "第 24 关放 boss")

	_check_eq(LevelTableS.clear_reward(1), 8, "第 1 关过关给 8 金币")
	_check_eq(LevelTableS.clear_reward(2), 8, "第 2 关过关给 8 金币")
	_check_eq(LevelTableS.clear_reward(3), 10, "第 3 关过关给 10 金币")
	_check_eq(LevelTableS.clear_reward(6), 10, "第 6 关过关给 10 金币")
	_check_eq(LevelTableS.clear_reward(7), 8, "第 7 关又回到 8 金币")
	_check_eq(LevelTableS.clear_reward(9), 10, "第 9 关过关给 10 金币")

	# 过关银两 = 关卡奖励 + 剩余巡数
	var reward := MahjongRoundS.new()
	reward.start(1, [], 1)          # 第 1 关：10 巡、基础 8 两
	_check_eq(reward.remaining_tours(), 9, "开局还剩 9 巡")
	_check_eq(reward.clear_coin_reward(), 17, "8 两 + 剩 9 巡 = 17 两")
	reward.tour = 7
	_check_eq(reward.remaining_tours(), 3, "打到第 7 巡还剩 3 巡")
	_check_eq(reward.clear_coin_reward(), 11, "8 两 + 剩 3 巡 = 11 两")
	reward.tour = 10
	_check_eq(reward.clear_coin_reward(), 8, "最后一巡才过关，只剩基础 8 两")

	# 巡数用完还没达标 → 本关失败
	var failed := MahjongRoundS.new()
	failed.start(7, [], 24)
	_check_eq(failed.target_score, 2150, "第 24 关目标 2150 分")
	_check_eq(failed.total_tours, 17, "第 24 关 17 巡")
	# 全孤张：碰不上、杠不上、也胡不了，只能靠打出的每巡 10 分
	failed.hand.reset(_parse_hand("147m 147p 147s 1257z 3z"))
	while not failed.is_over():
		if failed.can_draw():
			failed.draw_tile()
		if failed.state == MahjongRoundS.State.DISCARDING:
			_drop_last(failed)
		if failed.state == MahjongRoundS.State.AI_TURN:
			failed.run_opponent_turn()
	_check_eq(failed.state, MahjongRoundS.State.LOST, "17 巡打完没达标 → 失败")
	_check_eq(failed.score, 170, "只拿到打出的 17 × 10 = 170 分")
	_check_eq(failed.tour, 17, "打满 17 巡")
	_check_eq(failed.result_text, "17 巡打完 · 170 分（目标 2150 分）", "失败文案写清差距")

	# 换个低关口：同样的打法也能过关（第 1 关只要 100 分）
	var passed := MahjongRoundS.new()
	passed.start(8, [], 1)
	passed.hand.reset(_parse_hand("147m 147p 147s 1257z 3z"))
	while not passed.is_over():
		if passed.can_draw():
			passed.draw_tile()
		if passed.state == MahjongRoundS.State.DISCARDING:
			_drop_last(passed)
		if passed.state == MahjongRoundS.State.AI_TURN:
			passed.run_opponent_turn()
	_check_eq(passed.state, MahjongRoundS.State.WON, "第 1 关打到 100 分就过关")
	_check_eq(passed.score, 100, "刚好 100 分")
	_check_eq(passed.tour, 10, "第 10 巡达标")

	# 打出的那一张刚好达标：过关状态不能被电脑回合收尾冲掉（界面会调 end_opponent_turn）
	var ui_clear := MahjongRoundS.new()
	ui_clear.start(3, [], 1)
	ui_clear.hand.reset(_parse_hand("147m 147p 147s 1257z 3z"))
	ui_clear.score = 90
	ui_clear.discard(0)
	_check_eq(ui_clear.state, MahjongRoundS.State.WON, "打出达标 → 立刻过关")
	_check_eq(ui_clear.score, 100, "刚好凑满 100 分")
	_check_eq(ui_clear.result_text, "达标 100 分（目标 100 分）· 过关", "过关文案不重复")
	ui_clear.end_opponent_turn()
	_check_eq(ui_clear.state, MahjongRoundS.State.WON, "电脑回合收尾不能把过关状态改回去")
	_check_eq(ui_clear.tour, 1, "巡数也不会被推进")
	_check_eq(ui_clear.discard(0), -1, "过关之后再打牌不生效，不会重复触发过关")


func _test_shop() -> void:
	print("道具与商店")
	_check_eq(ShopItemsS.PRICE, 6, "道具售价都是 6 两")
	_check_eq(ShopItemsS.POOL.size(), 4, "池子里有 4 件道具")
	var keys: Array = []
	for item in ShopItemsS.POOL:
		keys.append(item["key"])
	for key in ["tiao", "tong", "wan", "honor"]:
		_check(key in keys, "池子里有 %s 加成" % key)

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var picks := ShopItemsS.roll(2, rng)
	_check_eq(picks.size(), 2, "商店第二行抽两件")
	_check(picks[0] != picks[1], "抽出来的两件不重复")
	_check(picks[0] >= 0 and picks[0] < ShopItemsS.POOL.size(), "下标在池子范围内")

	# 花牌只卖一次：买过的不会再被抽出来
	var rolled := FlowerTilesS.roll(2, null, ["桃花"])
	for entry in rolled:
		_check(entry["id"] != "桃花", "已买过的桃花不会再摆出来")

	# 加成落在「每张牌的基础分」上
	# 荷花：打出的牌牌河里已有同样的 → 这一张 ×5
	_check_eq(FlowerTilesS.effect_key("荷花"), "repeat", "荷花登记了「牌河重张」效果")
	_check_eq(FlowerTilesS.effect_key("菊花"), "", "没登记的花牌效果为空")
	var repeat_round := MahjongRoundS.new()
	repeat_round.start(1, [], 1)
	repeat_round.flowers.assign(["repeat"])
	repeat_round.hand.reset(_parse_hand("11s 19m 147p 1234567z"))
	repeat_round.discard(repeat_round.hand.tiles.find(18))   # 第一条一条：牌河还是空的
	_check_eq(repeat_round.score, 10, "牌河里没有同样的一条，正常 10 分")
	repeat_round.run_opponent_turn()
	repeat_round.draw_tile()
	repeat_round.discard(repeat_round.hand.tiles.find(18))   # 再打一条：牌河里已有一条
	_check_eq(repeat_round.score, 60, "牌河里已有一条 → 这一张 ×5，共 60 分")

	# 桃花：连续「摸什么打什么」分数 ×连击数，断了归零
	_check_eq(FlowerTilesS.effect_key("桃花"), "combo", "桃花登记了「连击」效果")
	var combo := MahjongRoundS.new()
	combo.start(1, [], 1)
	combo.flowers.assign(["combo"])
	combo.hand.reset(_parse_hand("19m 147p 1147s 123z"))
	# 第一巡是庄家直接打出（不摸牌），先走掉这一手
	combo.discard(combo.hand.tiles.size() - 1)
	_check_eq(combo.combo_streak, 0, "第一巡没摸牌，连击还是 0")
	combo.run_opponent_turn()
	for i in 3:
		combo.draw_tile()                       # 摸一张
		combo.discard(combo.hand.tiles.size())  # 就打摸到的那张
		_check_eq(combo.combo_streak, i + 1, "第 %d 次摸打，连击 %d" % [i + 1, i + 1])
		combo.run_opponent_turn()
	_check_eq(combo.score, 10 + 10 + 20 + 30, "第一巡 10 分，之后 ×1、×2、×3，共 70 分")

	# 中间打断：摸五万却打别的 → 连击归零
	var broken := MahjongRoundS.new()
	broken.start(1, [], 1)
	broken.flowers.assign(["combo"])
	broken.hand.reset(_parse_hand("19m 147p 1147s 123z"))
	broken.discard(broken.hand.tiles.size() - 1)  # 第一巡直接打出
	broken.run_opponent_turn()
	broken.draw_tile()
	broken.discard(broken.hand.tiles.size())
	_check_eq(broken.combo_streak, 1, "第一次摸打，连击 1")
	broken.run_opponent_turn()
	broken.draw_tile()
	broken.discard(0)  # 打手牌，不打摸到的那张
	_check_eq(broken.combo_streak, 0, "没打摸到的那张 → 连击断了")

	# 满天星（史诗花牌）：售价 14 两，每一关额外多三巡
	_check_eq(FlowerTilesS.effect_key("满天星"), "star", "满天星登记了效果")
	_check(FlowerTilesS.effect_desc("满天星") != "", "满天星有说明文字")
	_check(FlowerTilesS.is_epic("满天星"), "满天星是史诗花牌")
	_check(not FlowerTilesS.is_epic("桃花"), "桃花还是普通花牌")
	_check_eq(FlowerTilesS.rarity_name("满天星"), "史诗", "稀有度显示「史诗」")
	_check_eq(FlowerTilesS.rarity_name("荷花"), "普通", "普通花牌显示「普通」")
	_check_eq(FlowerTilesS.price("满天星"), 14, "史诗花牌卖 14 两")
	_check_eq(FlowerTilesS.price("桃花"), 10, "普通花牌还是 10 两")
	_check_eq(FlowerTilesS.price("荷花"), 10, "普通花牌还是 10 两")
	_check_eq(FlowerTilesS.LIMIT, 5, "一局最多带 5 张花牌")
	var peach_path := FlowerTilesS.path_of("桃花")
	_check(peach_path != "" and peach_path.contains("桃花"), "按名字能找到花牌的图片")
	_check_eq(FlowerTilesS.path_of("没这张花"), "", "找不到的花牌给空路径，不报错")

	# 花牌要在 start() 之前登记
	var star := MahjongRoundS.new()
	star.flowers.assign(["star"])
	star.start(1, [], 1)
	_check_eq(star.total_tours, LevelTableS.tours(1) + 3, "满天星多三巡：第 1 关 13 巡")
	_check_eq(star.remaining_tours(), 12, "第 1 关开局还剩 12 巡")
	_check_eq(star.clear_coin_reward(), 8 + 12, "剩几巡就多给几两，史诗花牌照样算")
	var star_end := MahjongRoundS.new()
	star_end.flowers.assign(["star"])
	star_end.start(2, [], 24)
	_check_eq(star_end.total_tours, LevelTableS.tours(24) + 3, "第 24 关 17+3=20 巡")
	var no_star := MahjongRoundS.new()
	no_star.start(1, [], 1)
	_check_eq(no_star.total_tours, LevelTableS.tours(1), "没买满天星就是原本的 10 巡")

	# 打掉五条就能听牌：界面要给五条画红描边
	var five_s := TileCodecS.kind_of(TileCodecS.Suit.TIAO, 5)
	var seven_s := TileCodecS.kind_of(TileCodecS.Suit.TIAO, 7)
	var hint_round := _rig_ready(9, _parse_hand("123m 456m 789m 11p 56s"))
	hint_round.wall.stack_next(five_s, 0)
	hint_round.draw_tile()  # 摸到五条，进到 14 张的「该打哪张」阶段
	_check_eq(hint_round.state, MahjongRoundS.State.DISCARDING, "摸完牌进入打牌阶段")
	var hints := hint_round.tenpai_discards()
	_check(five_s in hints, "算出「打五条能听牌」")
	var after_discard: Array = hint_round.hand.all_tiles()
	after_discard.erase(five_s)
	_check(seven_s in WinCheckerS.find_winning_tiles(after_discard), "打掉五条之后听七条")
	var round_ := MahjongRoundS.new()
	round_.start(1, [], 1)
	_check_eq(round_.tile_score(18), 10, "没买道具时一条就是 10 分")
	round_.apply_bonus("tiao", 2)
	_check_eq(round_.tile_score(18), 12, "买了条牌 +2，一条变 12 分")
	_check_eq(round_.tile_score(0), 10, "万牌不受条牌加成影响")
	round_.apply_bonus("honor", 3)
	_check_eq(round_.tile_score(27), 13, "买了字牌 +3，东变 13 分")
	_check_eq(round_.tile_score(31), 13, "中也是字牌，同样 +3")
	round_.apply_bonus("tiao", 2)
	_check_eq(round_.tile_score(18), 14, "同一件道具可以叠加")

	# 打出计分跟着加成走
	round_.hand.reset(_parse_hand("147m 147p 147s 1257z 3z"))
	round_.discard(round_.hand.tiles.find(18))  # 打掉一条
	_check_eq(round_.score, 14, "打出一张一条，拿的是叠加两次加成后的 14 分")


func _drop_last(round_: MahjongRound) -> void:
	## 调试用：打掉手上最后一张（刚摸到的那张优先）
	if round_.hand.has_drawn():
		round_.discard(round_.hand.tiles.size())
	else:
		round_.discard(round_.hand.tiles.size() - 1)


func _test_opponent_discards_and_remaining_counts() -> void:
	print("电脑出牌与剩余张数")
	var round_ := _rig_ready(1, _parse_hand("123m 456m 789m 123p 1z"))  # 听东
	_check_eq(round_.remaining_count(27), 3, "东在自己手上 1 张，外面还剩 3 张")
	_check_eq(round_.tenpai_hint(), "听：東(剩3)", "听牌提示显示剩余张数")

	round_.ai_discards.append(27)
	round_.ai_discards.append(27)
	_check_eq(round_.remaining_count(27), 1, "电脑打出 2 张东之后只剩 1 张")
	_check_eq(round_.tenpai_hint(), "听：東(剩1)", "剩余张数会跟着电脑出牌变少")

	# 摸一张不会胡的牌，看电脑是否照常打掉 3 张
	# 这副牌全是孤张，怎么摸都听不了，正好用来测流程
	var fresh := _rig_ready(99, _parse_hand("147m 147p 147s 1357z"))
	fresh.wall.stack_next(TileCodecS.kind_of(TileCodecS.Suit.WAN, 5))
	var before := fresh.wall.remaining()
	var ai_before := fresh.ai_discards.size()
	fresh.draw_tile()
	_check_eq(fresh.state, MahjongRoundS.State.DISCARDING, "摸到五万没胡，进入打牌状态")
	_check_eq(fresh.ai_discards.size(), ai_before, "玩家还没打牌，电脑一张都没出")
	_check_eq(fresh.wall.remaining(), before - 1, "牌墙只少了玩家摸的那张")
	fresh.discard(0)
	fresh.run_opponent_turn()
	_check_eq(fresh.ai_discards.size(), ai_before + 3, "玩家打完之后电脑才打 3 张")
	_check_eq(fresh.wall.remaining(), before - 4, "牌墙一共少了 4 张（自己 1 张 + 电脑 3 张）")
	_check_eq(fresh.tour, 3, "打完这一巡进入下一巡")


func _test_ron() -> void:
	print("荣和：胡电脑打出的牌")
	var round_ := _rig_ready(5, _parse_hand("123m 456m 789m 123p 1z"))  # 听东
	round_.wall.stack_next(TileCodecS.kind_of(TileCodecS.Suit.WAN, 5), 0)   # 自己摸五万，不胡
	round_.wall.stack_next(TileCodecS.kind_of(TileCodecS.Suit.WIND, 1), 1)  # 电脑第一张打东
	var ai_before := round_.ai_discards.size()
	round_.draw_tile()
	_check_eq(round_.state, MahjongRoundS.State.DISCARDING, "先等玩家打牌")
	_check_eq(round_.ai_discards.size(), ai_before, "这时电脑还没出牌")
	round_.discard(round_.hand.tiles.size())  # 打掉刚摸到的五万，留下 13 张听东
	_check_eq(round_.state, MahjongRoundS.State.AI_TURN, "玩家打完轮到电脑")
	round_.opponent_discard_once()

	_check_eq(round_.state, MahjongRoundS.State.CLAIM, "电脑打出东，停下等玩家决定")
	_check_eq(round_.claim_tile, 27, "荣和的是东")
	_check(round_.can_ron, "可以荣和")
	_check(not round_.can_pong, "手里只有一张东，碰不了")
	_check_eq(round_.hand.size(), 13, "荣和提示期间自己手上是 13 张")
	_check_eq(round_.tenpai_hint(), "荣和就是 4 面子 + 1 将", "提示说明荣和后的牌型")
	_check(not round_.can_draw(), "可以荣和的时候不能再摸牌")

	round_.declare_ron()
	_check_eq(round_.state, MahjongRoundS.State.WON, "荣和之后本局结束")
	_check_eq(round_.result_text, "荣和 · 4 面子 + 1 将", "结算文案区分自摸和荣和")
	_check_eq(round_.hand.tiles.size(), 14, "结算画面能看到完整的 14 张")
	_check_eq(round_.winning_tile, 27, "记录了用来高亮的胡牌张")
	_check_eq(round_.ai_discards_this_turn().size(), 0, "被胡走的牌不再算电脑打出的牌")

	# 选择不胡，电脑剩下的牌继续打完
	var skipped := _rig_ready(6, _parse_hand("123m 456m 789m 123p 1z"))
	skipped.wall.stack_next(TileCodecS.kind_of(TileCodecS.Suit.WAN, 5), 0)
	skipped.wall.stack_next(27, 1)
	skipped.wall.stack_next(3, 2)
	skipped.wall.stack_next(4, 3)
	skipped.draw_tile()
	skipped.discard(skipped.hand.tiles.size())
	skipped.opponent_discard_once()
	_check_eq(skipped.state, MahjongRoundS.State.CLAIM, "同样可以荣和")
	skipped.pass_claim()
	_check_eq(skipped.state, MahjongRoundS.State.AI_TURN, "过掉之后电脑接着出")
	skipped.run_opponent_turn()
	_check_eq(skipped.state, MahjongRoundS.State.READY, "选择不胡之后轮到玩家摸牌")
	_check_eq(skipped.ai_discards_this_turn().size(), 3, "不胡的话电脑照样打满 3 张")
	_check_eq(skipped.claim_tile, -1, "跳过之后清掉了荣和提示")


func _test_only_current_turn_is_shown() -> void:
	print("画面只画本轮电脑出牌")
	var round_ := _rig_ready(31, _parse_hand("147m 147p 147s 1357z"))  # 全孤张，专心测流程
	_check_eq(round_.ai_discards_this_turn().size(), 3, "第一轮画 3 张")
	round_.draw_tile()
	round_.discard(0)
	round_.run_opponent_turn()
	_check_eq(round_.ai_discards.size(), 6, "数据里累计了 6 张")
	_check_eq(round_.ai_discards_this_turn().size(), 3, "但画面只画本轮的 3 张")
	_check_eq(round_.ai_discards_this_turn(), round_.ai_discards.slice(3, 6), "本轮画的是最后 3 张")
	_check_eq(round_.ai_discards_this_turn()[0], round_.ai_discards[3], "本轮起点对得上")


func _test_ai_waits_for_player() -> void:
	print("电脑必须等玩家换完牌才出牌")
	var round_ := _rig_ready(23, _parse_hand("147m 147p 147s 1357z"))  # 全孤张，不会触发荣和
	var wall_before := round_.wall.remaining()
	var ai_before := round_.ai_discards.size()

	round_.draw_tile()
	_check_eq(round_.state, MahjongRoundS.State.DISCARDING, "摸完牌先等玩家决定打哪张")
	_check_eq(round_.ai_discards.size(), ai_before, "玩家没打完，电脑一张都没出")
	_check_eq(round_.wall.remaining(), wall_before - 1, "牌墙只少了玩家摸的那张")
	_check_eq(round_.hand.size(), 14, "这时手上有 14 张可以挑")

	round_.discard(5)
	_check_eq(round_.hand.size(), 13, "玩家打完回到 13 张")
	_check_eq(round_.state, MahjongRoundS.State.AI_TURN, "玩家打完之后才轮到电脑")
	_check_eq(round_.ai_discards.size(), ai_before, "电脑还没出第一张")

	# 电脑一张一张出，每出一张都会单独检测一次
	round_.opponent_discard_once()
	_check_eq(round_.ai_discards_this_turn().size(), 1, "电脑出了第 1 张")
	_check(not round_.opponent_turn_finished(), "这一轮还没出完")
	round_.opponent_discard_once()
	_check_eq(round_.ai_discards_this_turn().size(), 2, "电脑出了第 2 张")
	round_.opponent_discard_once()
	_check_eq(round_.ai_discards_this_turn().size(), 3, "电脑出了第 3 张")
	_check(round_.opponent_turn_finished(), "电脑本轮出完了")

	round_.end_opponent_turn()
	_check_eq(round_.wall.remaining(), wall_before - 4, "牌墙一共少了 4 张")
	_check_eq(round_.state, MahjongRoundS.State.READY, "电脑出完牌才轮回玩家")


func _test_pong() -> void:
	print("碰：手里有一对，电脑打出第三张")
	# 一万一对，其余全是孤张：碰得上，但怎么都胡不了
	var round_ := _rig_ready(11, _parse_hand("11m 4m 7m 1p 4p 7p 1s 4s 7s 1z 3z 5z"))
	_check_eq(round_.hand.tiles.size(), 13, "手上 13 张")
	round_.wall.stack_next(2, 0)  # 自己摸三万，不胡
	round_.wall.stack_next(0, 1)  # 电脑第一张打一万
	round_.draw_tile()
	round_.discard(round_.hand.tiles.size())

	var tile := round_.opponent_discard_once()
	_check_eq(tile, 0, "电脑打出一万")
	_check_eq(round_.state, MahjongRoundS.State.CLAIM, "停下来等玩家决定")
	_check(round_.can_pong, "手里有一对，可以碰")
	_check(not round_.can_ron, "这副牌胡不了，只能碰")
	_check_eq(round_.claim_tile, 0, "等着决定的就是一万")
	_check_eq(round_.claim_hint(), "碰完还要打出一张", "提示告诉玩家碰完还要打牌")

	_check(round_.declare_pong(), "碰成功")
	_check_eq(round_.state, MahjongRoundS.State.DISCARDING, "碰完必须打出一张")
	_check_eq(round_.melds.size(), 1, "碰下了一副一万")
	_check_eq(round_.melds[0]["kind"], 0, "碰的是一万")
	_check_eq(round_.melds[0]["kong"], false, "这是碰不是杠")
	_check_eq(round_.meld_tile_count(round_.melds[0]), 3, "碰占 3 张")
	_check_eq(round_.hand.tiles.size(), 11, "手牌拿走两张，剩 11 张")
	_check_eq(round_.hand.size(), 11, "没有摸到的牌，手上就是 11 张")
	_check_eq(round_.visible_count(0), 4, "碰下的三张 + 第一巡打掉的一张")
	_check_eq(round_.remaining_count(0), 0, "外面没有一万了")
	_check_eq(round_.ai_discards_this_turn().size(), 0, "被碰走的牌不再算电脑打出的牌")

	# 碰完打一张，电脑把本轮剩下的牌出完
	round_.flowers.assign(["combo"])
	round_.combo_streak = 3  # 假装之前连了三次
	round_.discard(0)
	_check_eq(round_.combo_streak, 0, "碰之后的打出会打断桃花连击")
	_check_eq(round_.hand.tiles.size(), 10, "打完只剩 10 张暗牌")
	_check_eq(round_.state, MahjongRoundS.State.AI_TURN, "电脑继续出剩下的牌")
	round_.opponent_discard_once()
	round_.opponent_discard_once()
	_check(round_.opponent_turn_finished(), "电脑本轮出完了")
	round_.end_opponent_turn()
	_check_eq(round_.state, MahjongRoundS.State.READY, "轮回玩家摸牌")
	_check_eq(round_.hand.size(), 10, "碰过一副之后手上是 10 张暗牌")
	_check_eq(round_.tour, 3, "碰不额外消耗巡数")


func _test_kong() -> void:
	print("杠：手里有三张，电脑打出第四张")
	# 一万三张，其余全是孤张：杠得上，但胡不了
	var round_ := _rig_ready(21, _parse_hand("111m 4m 7m 1p 4p 7p 1s 4s 7s 1z 3z"))
	_check_eq(round_.hand.tiles.size(), 13, "手上 13 张")
	round_.wall.stack_next(2, 0)   # 自己摸三万，不胡
	round_.wall.stack_next(0, 1)   # 电脑第一张打一万
	round_.wall.stack_next(26, 2)  # 杠完补摸的那张：九条
	round_.draw_tile()
	round_.discard(round_.hand.tiles.size())

	var tile := round_.opponent_discard_once()
	_check_eq(tile, 0, "电脑打出一万")
	_check_eq(round_.state, MahjongRoundS.State.CLAIM, "停下来等玩家决定")
	_check(round_.can_kong, "手里有三张，可以杠")
	_check(round_.can_pong, "手里有三张时碰也合法，两个选项都给玩家")
	_check(not round_.can_ron, "这副牌胡不了")
	_check("杠" in round_.claim_hint(), "提示里说明杠完会补摸一张")

	var before := round_.wall.remaining()
	# 顺手验证：杠是「摸一打一」，打补摸的那张不算断连击
	round_.flowers.assign(["combo"])
	round_.combo_streak = 2
	_check(round_.declare_kong(), "杠成功")
	_check_eq(round_.melds.size(), 1, "杠下了一副")
	_check_eq(round_.melds[0]["kind"], 0, "杠的是一万")
	_check_eq(round_.melds[0]["kong"], true, "记成杠而不是碰")
	_check_eq(round_.meld_tile_count(round_.melds[0]), 4, "杠占 4 张")
	_check_eq(round_.hand_count_of(0), 0, "手里的一万全被杠走了")
	_check_eq(round_.visible_count(0), 5, "四张在杠里 + 第一巡打掉的一张")
	_check_eq(round_.remaining_count(0), 0, "外面没有一万了")
	_check_eq(round_.score_from_kongs, 200, "杠的计分：(10+10+10+10)×5 = 200")

	# 杠完补摸一张
	_check_eq(round_.wall.remaining(), before - 1, "补摸也消耗牌墙")
	_check_eq(round_.last_drawn, 26, "补摸到九条")
	_check_eq(round_.hand.tiles.size(), 10, "杠完手里剩 10 张暗牌")
	_check_eq(round_.hand.size(), 11, "补摸之后是 11 张")
	_check_eq(round_.state, MahjongRoundS.State.DISCARDING, "杠完必须打出一张")

	# 打完这一张，电脑把本轮剩下的牌出完
	round_.discard(round_.hand.tiles.size())
	_check_eq(round_.combo_streak, 3, "杠之后打补摸的牌，桃花连击继续")
	_check_eq(round_.hand.tiles.size(), 10, "打完只剩 10 张暗牌")
	_check_eq(round_.state, MahjongRoundS.State.AI_TURN, "电脑继续出剩下的牌")
	round_.run_opponent_turn()
	_check_eq(round_.state, MahjongRoundS.State.READY, "轮回玩家摸牌")
	_check_eq(round_.tour, 3, "杠不额外消耗巡数")
	_check_eq(round_.hand.size(), 10, "杠过一副之后手上是 10 张暗牌")

	# 杠上开花：补摸的那张正好成牌
	var flowery := _rig_ready(22, _parse_hand("111m 234m 567m 789m 5p"))
	flowery.wall.stack_next(2, 0)   # 自己摸三万
	flowery.wall.stack_next(0, 1)   # 电脑打一万 → 杠
	flowery.wall.stack_next(13, 2)  # 补摸五筒，正好凑成将
	flowery.draw_tile()
	flowery.discard(flowery.hand.tiles.size())
	flowery.opponent_discard_once()
	_check(flowery.declare_kong(), "杠成功")
	_check_eq(flowery.state, MahjongRoundS.State.WON, "补摸的牌正好成牌 → 杠上开花")
	_check_eq(flowery.result_text, "杠上开花 · 4 面子 + 1 将", "结算文案标明杠上开花")
	_check_eq(flowery.winning_hand_tiles().size(), 15, "杠过的牌型是 15 张（杠占 4 张）")
	_check_eq(flowery.score_from_win, 3000, "杠上开花算自摸：15 张 × 10 分 × 20")
	_check_eq(flowery.score, 20 + 200 + 3000, "合计 = 打出 20 + 杠 200 + 胡牌 3000")


func _test_concealed_kong() -> void:
	print("暗杠：自己摸到第四张")
	# 手里三张一万，等下摸到第四张
	var round_ := _rig_ready(31, _parse_hand("111m 4m 7m 1p 4p 7p 1s 4s 7s 1z 3z"))
	_check_eq(round_.hand.tiles.size(), 13, "手上 13 张")
	_check(not round_.can_concealed_kong(), "还没摸到第四张，不能暗杠")

	round_.wall.stack_next(0, 0)  # 摸到第四张一万
	round_.draw_tile()
	_check_eq(round_.state, MahjongRoundS.State.DISCARDING, "摸完牌进入打牌状态")
	_check(round_.can_concealed_kong(), "手上凑齐四张一万，可以暗杠")
	_check_eq(round_.hand.count_of(0), 4, "手上确实有四张")

	var before := round_.wall.remaining()
	_check(round_.declare_concealed_kong(), "暗杠成功")
	_check_eq(round_.melds.size(), 1, "暗杠记了一副")
	_check_eq(round_.melds[0]["kind"], 0, "暗杠的是一万")
	_check_eq(round_.melds[0]["kong"], true, "记成杠")
	_check_eq(round_.melds[0].get("concealed", false), true, "而且是暗杠不是明杠")
	_check_eq(round_.meld_tile_count(round_.melds[0]), 4, "暗杠占 4 张")
	_check_eq(round_.hand.tiles.size(), 10, "四张扣下去，手里剩 10 张")
	_check_eq(round_.score_from_kongs, 240, "暗杠计分：(10+10+10+10)×6 = 240")
	_check_eq(round_.wall.remaining(), before - 1, "暗杠也要补摸一张")
	_check_eq(round_.hand.size(), 11, "补摸之后手上 11 张")
	_check_eq(round_.state, MahjongRoundS.State.DISCARDING, "补摸完还得打出一张")
	_check(not round_.can_concealed_kong(), "一万已经扣下去了，不能再暗杠")
	_check_eq(round_.visible_count(0), 5, "四张在暗杠里 + 第一巡打掉的一张")
	_check_eq(round_.remaining_count(0), 0, "外面没有一万了")

	round_.discard(round_.hand.tiles.size())
	_check_eq(round_.hand.tiles.size(), 10, "打完之后 10 张暗牌")
	_check_eq(round_.state, MahjongRoundS.State.AI_TURN, "玩家打完轮到电脑")
	round_.run_opponent_turn()
	_check_eq(round_.state, MahjongRoundS.State.READY, "轮回玩家摸牌")
	_check_eq(round_.tour, 3, "暗杠不额外消耗巡数")

	# 暗杠之后补摸的牌正好成牌
	var flowery := _rig_ready(32, _parse_hand("111m 234m 567m 789m 5p"))
	flowery.wall.stack_next(0, 0)   # 摸到第四张一万 → 暗杠
	flowery.wall.stack_next(13, 1)  # 补摸五筒，正好凑成将
	flowery.draw_tile()
	_check(flowery.declare_concealed_kong(), "暗杠成功")
	_check_eq(flowery.state, MahjongRoundS.State.WON, "补摸的牌正好成牌 → 杠上开花")
	_check_eq(flowery.result_text, "杠上开花 · 4 面子 + 1 将", "结算文案标明杠上开花")
	_check_eq(flowery.winning_hand_tiles().size(), 15, "暗杠过的牌型是 15 张")
	_check_eq(flowery.score_from_win, 3000, "杠上开花算自摸：15 张 × 10 分 × 20")
	_check_eq(flowery.score, 10 + 240 + 3000, "合计 = 打出 10 + 暗杠 240 + 胡牌 3000")


func _test_violet_swap() -> void:
	print("紫罗兰：每关（回合）开局换牌")
	_check_eq(FlowerTilesS.effect_key("紫罗兰"), "violet", "紫罗兰登记了「开局换牌」效果")
	_check(FlowerTilesS.is_epic("紫罗兰"), "紫罗兰是史诗花牌")
	_check_eq(FlowerTilesS.price("紫罗兰"), 14, "史诗花牌卖 14 两")

	# 没买就没有这个能力
	var plain := MahjongRoundS.new()
	plain.start(1, [], 1)
	_check(not plain.can_swap(), "没买紫罗兰就没有换牌")
	_check_eq(plain.swap_tiles([0]), 0, "没买的时候换了也不生效")

	var round_ := MahjongRoundS.new()
	round_.flowers.assign(["violet"])
	round_.start(1, [], 1)
	_check(round_.can_swap(), "买了紫罗兰，开局（第一巡）就能换牌")
	_check_eq(round_.hand.tiles.size(), 14, "庄家起手 14 张")

	# 弃两张、摸两张：手牌张数不变，牌进的是「弃置区」不是牌河
	var picked: Array = [round_.hand.tiles.size() - 1, round_.hand.tiles.size() - 2]
	var picked_kinds: Array = [round_.hand.tiles[picked[0]], round_.hand.tiles[picked[1]]]
	var seen_before := round_.visible_count(picked_kinds[0])
	var wall_before := round_.wall.remaining()
	var count := round_.swap_tiles(picked)
	_check_eq(count, 2, "换了两张")
	_check_eq(round_.hand.tiles.size(), 14, "换完手里还是 14 张")
	_check_eq(round_.wall.remaining(), wall_before - 2, "牌墙少了两张（换来的）")
	_check_eq(round_.discards.size(), 0, "弃掉的牌不进牌河")
	_check_eq(round_.ai_discards.size(), 0, "也不算电脑打出的牌")
	_check_eq(round_.swapped.size(), 2, "弃掉的牌记在弃置区里")
	_check_eq(round_.score, 0, "换牌不给分")
	_check_eq(round_.visible_count(picked_kinds[0]), seen_before,
		"露面张数不变：牌只是从手上挪到弃置区，不会再回来")
	_check(not round_.can_swap(), "一巡只能换一次")

	# 换进来的牌要能被界面认出来是哪几张（好播入场动画）
	var anim := MahjongRoundS.new()
	anim.flowers.assign(["violet"])
	anim.start(1, [], 1)
	anim.hand.reset(_parse_hand("1123m 4567p 1234s 12z"))
	anim.wall.stack_next(13, 0)   # 换进来的第一张是五筒
	_check_eq(anim.swap_tiles([anim.hand.tiles.find(12)]), 1, "弃掉四筒换来五筒")
	_check_eq(anim.swap_positions, [5] as Array[int],
		"新牌排在同种旧牌后面：五筒落在第 6 张（下标 5）")
	_check_eq(anim.hand.tiles[5], 13, "这个位置确实是新换来的五筒")

	# 一回合 = 一关：换过之后，这一关剩下的巡都不能再换
	round_.discard(0)
	round_.run_opponent_turn()
	_check_eq(round_.tour, 2, "进第二巡")
	_check(not round_.can_swap(), "换牌是按「回合」算的，进了下一巡也不能再换")
	round_.draw_tile()
	_check(not round_.can_swap(), "摸了牌当然也不能换")
	_check_eq(round_.swap_tiles([0]), 0, "摸完牌再换不生效")
	# 一路打到这一关结束，中途都不能再换
	var guard := 0
	while not round_.is_over() and guard < 40:
		if round_.can_draw():
			_check(not round_.can_swap(), "第 %d 巡也不能换" % round_.tour)
			round_.draw_tile()
		round_.discard(0)
		round_.run_opponent_turn()
		guard += 1
	_check(round_.is_over(), "这一关打完了")
	_check_eq(round_.swapped.size(), 2, "整关下来只换了开局那一次")

	# 下一个回合（下一关）开局，机会又有了
	var next_round := MahjongRoundS.new()
	next_round.flowers.assign(["violet"])
	next_round.start(3, [], 2)
	_check(next_round.can_swap(), "新的一关（回合）开局又能换牌")

	# 换牌之后依旧可以天胡：弃掉三筒、换来一筒，正好凑成将
	var heavenly := MahjongRoundS.new()
	heavenly.flowers.assign(["violet"])
	heavenly.start(1, _parse_hand("123m 456m 789m 999p 13p"), 1)
	_check_eq(heavenly.state, MahjongRoundS.State.DISCARDING, "起手不是成牌，正常等打牌")
	heavenly.wall.stack_next(9, 0)   # 换进来的第一张是一筒
	_check_eq(heavenly.swap_tiles([heavenly.hand.tiles.find(11)]), 1, "弃掉三筒换来一筒")
	_check_eq(heavenly.state, MahjongRoundS.State.WON, "换完凑成 14 张成牌 → 天胡")
	_check_eq(heavenly.result_text, "天胡 · 4 面子 + 1 将 · 过关（6720 分）",
		"换牌之后照样算天胡")
	_check_eq(heavenly.score, 6720, "天胡分不变：（14 张 × 10 分）× 48")
	_check_eq(heavenly.discards.size(), 0, "换掉的那张不进牌河")
	_check_eq(heavenly.swapped, [11] as Array[int], "弃置区里记着三筒")


func _test_scoring() -> void:
	print("计分")
	_check_eq(TileCodecS.base_score(0), 10, "每张牌基础分是 10 分")
	_check_eq(TileCodecS.base_score(33), 10, "白板也是 10 分")

	# 打出一张就 +10
	var by_discard := _rig_ready(41, _parse_hand("147m 147p 147s 1357z"))
	_check_eq(by_discard.score, 10, "第一巡打出的那张先记 10 分")
	by_discard.wall.stack_next(TileCodecS.kind_of(TileCodecS.Suit.WAN, 5), 0)  # 摸到五万
	by_discard.draw_tile()
	by_discard.discard(by_discard.hand.tiles.size())  # 打掉刚摸的五万
	_check_eq(by_discard.score, 20, "再打出一张，累计 20 分")
	_check_eq(by_discard.score_from_discards, 20, "都记在「打出」上")
	_check_eq(by_discard.last_score_reason, "打出 五万", "记录了得分来源")
	by_discard.run_opponent_turn()
	_check_eq(by_discard.score, 20, "电脑出牌不给玩家加分")

	# 碰：三张牌分值相加再翻倍 = (10+10+10)×2 = 60
	var by_pong := _rig_ready(11, _parse_hand("11m 4m 7m 1p 4p 7p 1s 4s 7s 1z 3z 5z"))
	by_pong.wall.stack_next(2, 0)
	by_pong.wall.stack_next(0, 1)
	by_pong.draw_tile()
	by_pong.discard(by_pong.hand.tiles.size())
	_check_eq(by_pong.score, 20, "碰之前是打出的 20 分")
	by_pong.opponent_discard_once()
	by_pong.declare_pong()
	_check_eq(by_pong.score, 80, "碰一万 =（10+10+10）×2 = 60 分，合计 80")
	_check_eq(by_pong.score_from_pongs, 60, "60 分记在「碰」上")
	_check_eq(by_pong.last_score_reason, "碰 一万（10+10+10）×2", "碰的算式写清楚了")

	# 碰完接着打牌，照样 +10
	by_pong.discard(0)
	_check_eq(by_pong.score, 90, "碰完再打一张，再 +10")
	_check_eq(by_pong.score_from_discards, 30, "打出累计 30 分")

	# 胡牌：14 张牌分值全部加起来，再 ×10
	var by_win := _rig_ready(1, _parse_hand("123m 456m 789m 123p 1z"))  # 听东
	by_win.wall.stack_next(27, 0)  # 摸到东，自摸
	by_win.draw_tile()
	_check_eq(by_win.state, MahjongRoundS.State.WON, "摸到东自摸胡牌")
	_check_eq(by_win.winning_hand_tiles().size(), 14, "算分的牌是 14 张")
	_check_eq(by_win.score_from_win, 2800, "自摸：（14 张 × 10 分）× 20 = 2800")
	_check_eq(by_win.score, 2810, "本局得分 = 打出 10 + 自摸 2800")
	_check_eq(by_win.last_score_reason, "自摸 14 张牌共 140 分 × 20", "胡牌算式写清楚了")

	# 天胡：庄家起手 14 张直接成牌，倍数最高
	var heavenly := MahjongRoundS.new()
	heavenly.start(1, _parse_hand("123m 456m 789m 123p 11z"))
	_check_eq(heavenly.state, MahjongRoundS.State.WON, "起手 14 张就成牌 → 天胡")
	_check_eq(heavenly.result_text, "天胡 · 4 面子 + 1 将 · 过关（6720 分）",
		"结算文案标明天胡，并附上过关结果")
	_check_eq(heavenly.tour, 1, "天胡发生在一开局，还没打过牌")
	_check_eq(heavenly.discards.size(), 0, "天胡时一张都没打出去")
	_check_eq(heavenly.score_from_win, 6720, "天胡：（14 张 × 10 分）× 48 = 6720")
	_check_eq(heavenly.score, 6720, "本局得分就是天胡分")

	# 荣和也一样，而且碰过一副之后仍然要凑满 14 张
	var melded := _rig_ready(12, _parse_hand("234m 567m 789m 55p 11m"))
	_check_eq(melded.hand.tiles.size(), 13, "手上 13 张")
	melded.wall.stack_next(8, 0)   # 自己摸九万，不胡
	melded.wall.stack_next(0, 1)   # 电脑第一张打一万 → 可以碰
	melded.wall.stack_next(27, 2)  # 电脑后两张打东、南，都碰不得
	melded.wall.stack_next(28, 3)
	melded.wall.stack_next(13, 4)  # 下一轮摸回五筒，自摸
	melded.draw_tile()
	melded.discard(melded.hand.tiles.size())
	melded.opponent_discard_once()
	_check(melded.can_pong, "一万可以碰")
	melded.declare_pong()
	_check_eq(melded.melds.size(), 1, "碰下了一副一万")
	_check_eq(melded.hand.tiles.size(), 11, "碰完手上 11 张暗牌")
	_check_eq(melded.winning_hand_tiles().size(), 14, "算分的牌 = 11 张暗牌 + 碰下的 3 张 = 14 张")

	melded.discard(melded.hand.tiles.find(13))  # 拆掉 55 筒，打出其中一张
	melded.run_opponent_turn()
	_check_eq(melded.state, MahjongRoundS.State.READY, "轮回玩家")
	melded.draw_tile()
	_check_eq(melded.state, MahjongRoundS.State.WON, "摸回五筒自摸")
	_check_eq(melded.winning_hand_tiles().size(), 14, "胡牌时算上碰下的三张，仍然是 14 张")
	_check_eq(melded.score_from_win, 2800, "自摸 2800（没算漏碰下的那副，否则只有 2200）")
	_check_eq(melded.score, 2890, "合计 = 打出 30 + 碰 60 + 自摸 2800")


func _test_winning_hands() -> void:
	print("胡牌判定")
	var cases := {
		"4 面子 + 1 将": "123m 456m 789m 123p 11z",
		"带刻子的标准型": "111m 234m 567m 999s 22p",
		"字一色": "111z 222z 333z 444z 55z",
		"七对子": "11m 22m 33m 44m 55m 66m 77m",
		"十三幺": "19m 19p 19s 1234567z 1m",
		"九莲宝灯": "1112345678999m 5m",
		"全带幺边张型": "123m 789m 123p 789p 11s",
	}
	for name in cases:
		var tiles := _parse_hand(cases[name])
		_check_eq(tiles.size(), 14, "%s 是 14 张" % name)
		_check(WinCheckerS.is_winning_hand(tiles), "%s 判定为胡牌" % name)


func _test_not_winning_hands() -> void:
	print("非胡牌判定")
	var cases := {
		"缺将": "123m 456m 789m 123p 45p",
		"孤张太多": "19m 19p 19s 1234567z 2m",
		"六对子不成七对": "11m 22m 33m 44m 55m 66m 78m",
		"顺子跨花色不成立": "789m 12p 3s 456m 11z 99p",
		"张数不对": "123m 456m 789m 123p",
	}
	for name in cases:
		var tiles := _parse_hand(cases[name])
		_check(not WinCheckerS.is_winning_hand(tiles), "%s 判定为不胡" % name)


func _test_tenpai() -> void:
	print("听牌计算")
	var single := _parse_hand("123m 456m 789m 123p 1z")
	_check_eq(single.size(), 13, "示例手牌是 13 张")
	_check_eq(TileCodecS.names_of(WinCheckerS.find_winning_tiles(single)), "東", "单骑听東")

	var ryanmen := _parse_hand("123m 456m 789m 22p 34p")
	_check_eq(TileCodecS.names_of(WinCheckerS.find_winning_tiles(ryanmen)), "二筒 五筒",
		"两面听二筒/五筒")

	var waits := WinCheckerS.find_winning_tiles(_parse_hand("19m 19p 19s 1234567z"))
	_check_eq(waits.size(), 13, "十三幺听 13 种牌")
	_check(WinCheckerS.is_tenpai(_parse_hand("19m 19p 19s 1234567z")), "十三幺听牌")

	# 提示行只在听牌之后才显示
	var not_ready := _rig_ready(3, _parse_hand("147m 147p 147s 1357z"))
	_check_eq(not_ready.tenpai_hint(), "", "没听牌时提示行是空的")

	var ready := _rig_ready(3, _parse_hand("123m 456m 789m 123p 1z"))
	_check_eq(ready.tenpai_hint(), "听：東(剩3)", "听牌之后才显示听什么")


func _test_seeded_round_is_deterministic() -> void:
	print("固定种子的发牌可复现")
	var a := MahjongRoundS.new()
	a.start(777)
	var b := MahjongRoundS.new()
	b.start(777)
	_check_eq(a.hand.tiles, b.hand.tiles, "同一种子发出同样的手牌")

	# 造一副听牌的手牌，塞一张东进去，应该立刻自摸
	var rigged := _rig_ready(1, _parse_hand("123m 456m 789m 123p 1z"))
	rigged.wall.stack_next(TileCodecS.kind_of(TileCodecS.Suit.WIND, 1))
	var tile := rigged.draw_tile()
	_check_eq(tile, 27, "摸到了东")
	_check_eq(rigged.state, MahjongRoundS.State.WON, "摸到东之后自摸胡牌")
	_check_eq(rigged.tour, 2, "还在第二巡")
	_check_eq(rigged.result_text, "自摸 · 4 面子 + 1 将", "牌型描述正确")


func _test_ui_scene_smoke() -> void:
	print("界面冒烟测试")
	var packed := load("res://scenes/main.tscn")
	if packed == null:
		_check(false, "主场景能加载")
		return
	_check(true, "主场景能加载")

	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	_check(instance is Control, "主场景根节点是 Control")
	_check(instance.get_script() != null, "主场景挂上了 main.gd")

	var round_ref: Variant = instance.get("round_")
	_check(round_ref != null, "界面启动后自动开了一局")
	if round_ref != null:
		instance.set("ai_discard_delay", 0.0)
		_check_eq(round_ref.hand.tiles.size(), 14, "界面上是庄家起手 14 张")
		_check_eq(round_ref.tour, 1, "界面从第一巡开始")
		instance.call("_on_draw_pressed")
		_check_eq(round_ref.hand.size(), 14, "第一巡不摸牌，点也没用")
		if round_ref.state != MahjongRoundS.State.WON:
			_check_eq(round_ref.ai_discards_this_turn().size(), 0, "界面：玩家还没打牌，电脑不出牌")
			_check_eq(instance.get("_right_pool").get_child_count(), 0, "界面：牌河还是空的")
			instance.call("_do_discard", 0)
			_check_eq(round_ref.hand.size(), 13, "第一巡打完剩 13 张")
			var guard := 0
			while guard < 900:
				await process_frame
				guard += 1
				if round_ref.state == MahjongRoundS.State.CLAIM:
					instance.call("_on_pass_pressed")
					continue
				if round_ref.state != MahjongRoundS.State.AI_TURN:
					break
			_check(round_ref.ai_discards.size() >= 1, "界面：玩家打完后电脑才出牌")
			_check_eq(round_ref.tour, 2, "界面：电脑出完进入第二巡")
			instance.call("_on_draw_pressed")
			_check_eq(round_ref.hand.size(), 14, "第二巡摸牌后 14 张")
			var in_pools: int = instance.get("_right_pool").get_child_count() \
				+ instance.get("_across_pool").get_child_count() \
				+ instance.get("_left_pool").get_child_count()
			_check_eq(in_pools, round_ref.ai_discards.size(), "界面：电脑打出的牌都进了各家的牌河")
			_check_eq(instance.get("_my_pool").get_child_count(), round_ref.discards.size(),
				"界面：自己打出的牌进了自己的牌河")

			# 进入新一关时，上一关的副露不能留在画面上
			round_ref.melds.append({"kind": 0, "kong": false})
			instance.call("_refresh")
			_check_eq(_count_melds(instance), 3, "界面：有副露时画出三张")
			_check_eq(_meld_matches_hand_size(instance), true,
				"界面：副露跟手牌同占一行，大小也一样")
			instance.call("_start_new_round")
			_check_eq(_count_melds(instance), 0, "界面：进新一关要清空副露")

			# 金币：过关继续累计，失败重开清零
			var settings := root.get_node_or_null("Settings")
			round_ref = instance.get("round_")  # 上面开过新局，引用要重新取
			settings.coins = 50
			round_ref.level = 1
			round_ref.state = MahjongRoundS.State.WON
			instance.call("_show_settlement", true)
			_check_eq(instance.get("_settle_button").text, "结算", "界面：过关时按钮是「结算」")
			_check(instance.get("_shop_page").visible == false, "界面：过关先看结算页，不是商店")
			instance.call("_on_settle_button_pressed")
			_check(instance.get("_shop_page").visible, "界面：点「结算」才进商店")
			instance.call("_show_settlement", true)
			settings.coins = 50
			instance.call("_on_restart_pressed")
			round_ref = instance.get("round_")
			_check_eq(settings.coins, 50, "界面：过关进下一关，金币继续累计")
			_check_eq(round_ref.level, 2, "界面：切到第 2 关")

			round_ref.state = MahjongRoundS.State.LOST
			instance.call("_show_settlement", false)
			_check_eq(instance.get("_settle_button").text, "重新开始", "界面：没达标时按钮是「重新开始」")
			_check(instance.get("_shop_page").visible == false, "界面：没达标不进商店")
			instance.call("_on_settle_button_pressed")
			round_ref = instance.get("round_")
			_check_eq(round_ref.level, 1, "界面：没达标从第 1 关重开")
			_check_eq(settings.coins, 0, "界面：没达标重开要把金币清零")
			_check(instance.get("_shop_page").visible == false, "界面：没达标点了也不会进商店")

			# 满天星：商店里买下来（14 两），下一关就要多三巡
			settings.coins = 50
			round_ref.level = 1
			round_ref.state = MahjongRoundS.State.WON
			instance.call("_on_settle_button_pressed")  # 进商店
			var flower_slot: Dictionary = instance.get("_flower_slots")[0]
			flower_slot["flower"] = {"id": "满天星", "path": "", "epic": true}
			flower_slot["bought"] = false
			instance.call("_on_buy_flower_pressed", 0)
			_check_eq(settings.coins, 36, "界面：满天星扣 14 两")
			_check(instance.get("_owned_flowers").has("满天星"), "界面：买到手了")
			instance.call("_on_restart_pressed")
			round_ref = instance.get("round_")
			_check_eq(round_ref.level, 2, "界面：进第 2 关")
			_check_eq(round_ref.total_tours, LevelTableS.tours(2) + 3, "界面：第 2 关变成 13 巡")
			_check_eq(round_ref.flowers.has("star"), true, "界面：花牌效果带进了新一关")
			_check_eq(instance.get("_remain_value").text, "12 巡", "界面：分数牌上写 12 巡")

			# 紫罗兰：界面上得能挑牌换牌
			var owned: Array = instance.get("_owned_flowers")
			owned.append("紫罗兰")
			round_ref.state = MahjongRoundS.State.WON
			instance.call("_on_restart_pressed")
			round_ref = instance.get("round_")
			_check_eq(instance.get("_swap_button").visible, true, "界面：有紫罗兰就出现「换牌」按钮")
			instance.call("_on_swap_pressed")
			_check_eq(instance.get("_swap_confirm_button").visible, true, "界面：进了换牌模式")
			_check_eq(instance.get("_draw_button").visible, false, "界面：挑牌的时候先不给摸牌")
			var hand_before: int = round_ref.hand.tiles.size()
			instance.call("_on_tile_pressed", 0)
			instance.call("_on_tile_pressed", 1)
			_check_eq(instance.get("_swap_selection").size(), 2, "界面：可以多选")
			_check_eq(instance.get("_swap_confirm_button").text, "确认换牌（2）", "界面：按钮上写着选了几张")
			instance.call("_on_swap_confirm_pressed")
			_check_eq(round_ref.hand.tiles.size(), hand_before, "界面：换完手牌张数不变")
			_check_eq(round_ref.discards.size(), 0, "界面：换掉的牌不进牌河")
			_check_eq(instance.get("_swap_mode"), false, "界面：换完自动退出换牌模式")
			_check_eq(instance.get("_swap_button").visible, false, "界面：这一巡换过了，按钮收起")
			# 换进来的牌要走跟开局发牌一样的入场动画（从上方落下）
			var row: Node = instance.get("_tile_row")
			var falling := 0
			for index in round_ref.swap_positions:
				var tile: Node = row.get_child(index)
				# 不写成 TileWidget 类型判断：那会把主场景的类拉进来，
				# 而无窗口跑测试时 Sfx 这些 autoload 还没注册，编译会挂
				var stack: Variant = tile.get("_stack")
				if stack != null and stack.offset_top < 0.0:
					falling += 1
			_check_eq(falling, round_ref.swap_positions.size(),
				"界面：换进来的牌都在往下落（入场动画）")

			# 买过的花牌要摆在牌桌最上面那一行
			owned.append("荷花")
			instance.call("_refresh")
			var flower_row: Node = instance.get("_flower_row")
			_check_eq(flower_row.get_child_count(), owned.size(), "界面：买过的花牌摆在牌桌顶上那一行")
			_check_eq(flower_row.get_child(0).custom_minimum_size,
				instance.get("_tile_row").get_child(0).custom_minimum_size,
				"界面：牌桌上花牌跟手牌一样大")

			# 花牌上限 5 张
			while owned.size() < FlowerTilesS.LIMIT:
				owned.append("占位%d" % owned.size())
			instance.call("_roll_flowers")
			var full_slot: Dictionary = instance.get("_flower_slots")[0]
			_check_eq(full_slot["name"].text, "花牌已满", "界面：带满 5 张之后商店不再摆花牌")
			full_slot["flower"] = {"id": "桃花", "path": "", "epic": false}
			full_slot["bought"] = false
			var coins_before: int = settings.coins
			instance.call("_on_buy_flower_pressed", 0)
			_check_eq(settings.coins, coins_before, "界面：带满 5 张之后点了也买不进来")

	instance.free()
