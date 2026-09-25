class_name FlowerTiles
extends RefCounted
## 花牌：图案用 assets/tiles/flowers/ 里的图片。
##
## 目录里的每张图算一种花牌，代码自动扫描、不需要登记。
## 文件名就是花牌的名字（比如 春.png → 「春」）。

const DIR := "res://assets/tiles/flowers/"
const PRICE := 10        # 普通花牌
const EPIC_PRICE := 14   # 史诗花牌，效果更强所以更贵
const LIMIT := 5         # 一局最多带 5 张花牌
const EXTS := [".png", ".webp", ".jpg", ".jpeg"]

## 史诗花牌：售价 14 钱，商店里会标出来
const EPIC_IDS := ["满天星", "紫罗兰"]

## 花牌效果登记表：左边是文件名（去掉扩展名），右边是效果代号。
## 效果代号按「效果」命名、不跟花名绑：以后换图、或者加一张同效果的花牌，代码都不用动。
## 没登记的花牌就是「效果待定」，商店里不让买。
const EFFECT_KEYS := {
	"桃花": "combo",    # 连击
	"taohua": "combo",  # 兼容拼音文件名
	"荷花": "repeat",   # 牌河重张 ×5
	"hehua": "repeat",
	"满天星": "star",
	"mantianxing": "star",
	"紫罗兰": "violet",
	"ziluolan": "violet",
	"梅花": "meld_double",
	"meihua": "meld_double",
	"梨花": "discard_bonus",
	"lihua": "discard_bonus",
	"百合": "pair_bonus",
	"baihe": "pair_bonus",
	"芍药": "honor_base",
	"shaoyao": "honor_base",
}
## 效果代号对应的说明文字（也给商店显示用）
const EFFECT_DESCS := {
	"combo": "打出的就是刚摸到的那张 → 倍率 +2",
	"repeat": "打出时牌河已有同样的牌 → 倍率 +4",
	"star": "每关额外增加 3 巡",
	"violet": "每关开始可弃牌摸等量",
	"meld_double": "碰、杠的倍率 ×2",
	"discard_bonus": "打出牌 → 倍率 +1",
	"pair_bonus": "打出后手牌里还有同样的牌 → 倍率 +4",
	"honor_base": "手里每有一张字牌，打出的底分 +10",
}

## 图片最长边超过这个值就先缩下来。原图动辄 1300×2000，
## 缩过之后显存省一大截，缩到牌面大小的时候也不容易糊。
const MAX_SIDE := 720

static var _face_cache := {}


static func face_texture(path: String) -> Texture2D:
	## 取花牌的牌面贴图（四角已经按圆角抠成透明），同一张只处理一次
	if _face_cache.has(path):
		return _face_cache[path]
	var masked: Texture2D = null
	if path != "" and ResourceLoader.exists(path):
		var res := load(path)
		if res is Texture2D:
			masked = _rounded(res)
	_face_cache[path] = masked
	return masked


static func _rounded(texture: Texture2D) -> Texture2D:
	## 图片预处理：太大的先缩小，再生成 mipmap。
	## 圆角不在这里抠——牌面上的花牌只有几十像素宽，抠在图片上会被缩小采样糊掉，
	## 交给牌面的着色器按当时的尺寸实时裁（见 tile_face.gd）。
	var image := texture.get_image()
	if image == null:
		return texture
	image = image.duplicate()
	image.convert(Image.FORMAT_RGBA8)
	var longest := maxi(image.get_width(), image.get_height())
	if longest > MAX_SIDE:
		var ratio := float(MAX_SIDE) / float(longest)
		image.resize(int(roundf(image.get_width() * ratio)), int(roundf(image.get_height() * ratio)),
			Image.INTERPOLATE_LANCZOS)
	# 生成 mipmap：牌面上的花牌只有几十像素宽，没有 mipmap 的话
	# 缩小采样会又闪又糊。
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


static func effect_key(id: String) -> String:
	return EFFECT_KEYS.get(id, "")


static func effect_desc(id: String) -> String:
	return EFFECT_DESCS.get(effect_key(id), "")


static func is_epic(id: String) -> bool:
	## 史诗花牌：更贵、更强，商店里带「史诗」标签
	return EPIC_IDS.has(id)


static func price(id: String) -> int:
	## 这张花牌卖多少钱
	return EPIC_PRICE if is_epic(id) else PRICE


static func rarity_name(id: String) -> String:
	return "史诗" if is_epic(id) else "普通"


static func path_of(id: String) -> String:
	## 按花牌名字找图片路径；找不到就返回空字符串（牌面留白，不报错）
	for entry in available():
		if entry["id"] == id:
			return entry["path"]
	return ""


static func available() -> Array:
	## 返回 [{"id": 名字, "path": 图片路径, "epic": 是否史诗}, ...]，按名字排序
	var out: Array = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and not file.begins_with("."):
			var lower := file.to_lower()
			for ext in EXTS:
				if lower.ends_with(ext):
					var id := file.get_basename()
					out.append({"id": id, "path": DIR + file, "epic": is_epic(id)})
					break
		file = dir.get_next()
	dir.list_dir_end()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	return out


static func roll(count: int, rng: RandomNumberGenerator = null, exclude_ids: Array = []) -> Array:
	## 随机抽 count 种花牌；不够就有多少给多少。
	## exclude_ids 里的是已经买过的——花牌只卖一次，不会再摆出来。
	var all: Array = []
	for entry in available():
		if not exclude_ids.has(entry["id"]):
			all.append(entry)
	var generator := rng
	if generator == null:
		generator = RandomNumberGenerator.new()
		generator.randomize()
	for i in range(all.size() - 1, 0, -1):
		var j := generator.randi_range(0, i)
		var swap: Dictionary = all[i]
		all[i] = all[j]
		all[j] = swap
	var out: Array = []
	for i in mini(count, all.size()):
		out.append(all[i])
	return out
