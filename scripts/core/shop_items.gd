class_name ShopItems
extends RefCounted
## 商店道具。
##
## 商店每次摆两行，每行两件：
##   第一行：还没定，先空着（占位）
##   第二行：从下面这个池子里随机抽两件
##
## 每件 5 两银两。买下之后，对应花色的「每张牌基础分」永久加上去
## （本局有效，重开一局清零）。

const PRICE := 6

const POOL := [
	{
		"key": "tiao",
		"tile": 26,  # 九条，先用牌面当图标
		"bonus": 2,
		"desc": "所有条牌基础分 +2",
	},
	{
		"key": "tong",
		"tile": 17,  # 九筒
		"bonus": 2,
		"desc": "所有筒牌基础分 +2",
	},
	{
		"key": "wan",
		"tile": 8,   # 九万
		"bonus": 2,
		"desc": "所有万牌基础分 +2",
	},
	{
		"key": "honor",
		"tile": 27,  # 东
		"bonus": 3,
		"desc": "所有字牌基础分 +3",
	},
]


static func roll(count: int, rng: RandomNumberGenerator = null) -> Array:
	## 从池子里不重复地抽 count 件，返回下标
	var generator := rng
	if generator == null:
		generator = RandomNumberGenerator.new()
		generator.randomize()
	var indices: Array[int] = []
	for i in POOL.size():
		indices.append(i)
	for i in range(indices.size() - 1, 0, -1):
		var j := generator.randi_range(0, i)
		var swap := indices[i]
		indices[i] = indices[j]
		indices[j] = swap
	var out: Array[int] = []
	for i in mini(count, indices.size()):
		out.append(indices[i])
	return out
