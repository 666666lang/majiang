class_name LevelTable
extends RefCounted
## 关卡参数表，共 24 关。
##
##   目标分数：第 1 关 100 分，前三关每关 +40（140、180），
##              第 4~6 关每关 +60（240、300、360），
##              第 7 关跳到 450，7~9 关每关 +100（550、650），
##              第 10 关再跳到 800，之后每关 +200（1000、1200 …… 第 24 关 3600）
##   巡数：第 1 关 10 巡，之后每 3 关 +1（第 4 关 11 巡、第 7 关 12 巡 ……）
##
## 只靠每巡打出的 10 分，第 1 关刚好是 10 巡 × 10 分 = 100 分，
## 往后的缺口就得靠碰、杠、胡牌来补——这是关卡难度的来源。

const MAX_LEVEL := 24
const BASE_TARGET := 100
const TARGET_STEP_EARLY := 40   # 第 2、3 关的步进
const TARGET_STEP_MID := 60     # 第 4~6 关的步进
const TARGET_STEP_LATE := 100   # 第 7~9 关的步进
const LATE_BASE_TARGET := 450   # 第 7 关本身的目标分
const TARGET_STEP_FINAL := 200  # 第 10 关往后每关的步进
const FINAL_BASE_TARGET := 800  # 第 10 关本身的目标分
const BASE_TOURS := 10
const LEVELS_PER_EXTRA_TOUR := 3


static func target_score(level: int) -> int:
	var l := clampi(level, 1, MAX_LEVEL)
	if l <= 3:
		return BASE_TARGET + (l - 1) * TARGET_STEP_EARLY
	if l <= 6:
		return BASE_TARGET + 2 * TARGET_STEP_EARLY + (l - 3) * TARGET_STEP_MID
	if l <= 9:
		return LATE_BASE_TARGET + (l - 7) * TARGET_STEP_LATE
	return FINAL_BASE_TARGET + (l - 10) * TARGET_STEP_FINAL


static func tours(level: int) -> int:
	@warning_ignore("integer_division")
	var extra := (clampi(level, 1, MAX_LEVEL) - 1) / LEVELS_PER_EXTRA_TOUR
	return BASE_TOURS + extra


static func bgm_name(level: int) -> String:
	## 三首曲子按关卡轮换：第 1 关 small、第 2 关 big、第 3 关 boss，
	## 第 4 关又是 small，依此类推。
	match (clampi(level, 1, MAX_LEVEL) - 1) % 3:
		0:
			return "small"
		1:
			return "big"
		_:
			return "boss"


static func clear_reward(level: int) -> int:
	## 过关奖励：一般是 8 金币，第 3、6、9……这些「boss 关」给 10。
	return 10 if clampi(level, 1, MAX_LEVEL) % 3 == 0 else 8
