class_name TileFace
extends Control
## 牌面图案：用绘制指令画出真正的牌面。
##
## - 万子：数字 + 萬（真牌上本来就是字）
## - 筒子：圆点图案，按 1~9 的经典排列
## - 条子：竹节图案，按 1~9 的经典排列
## - 风牌 / 中发白：字形（真牌上也是字），白板画成空心方框
##
## 所有图形都画在一块 100 × 140 的设计画布上，再按控件实际大小等比缩放，
## 所以手牌（大）和牌河（小）共用同一套图案。

const DESIGN := Vector2(100, 140)

const INK := Color(0.169, 0.169, 0.2)
const RED := Color(0.702, 0.157, 0.114)
const GREEN := Color(0.122, 0.478, 0.239)
const BLUE := Color(0.122, 0.373, 0.659)

## 花牌贴图那层圆角遮罩
const ROUND_MASK := preload("res://scripts/ui/flower_mask.gdshader")
## 牌身的圆角是牌宽的 14%（见 tile_body.gd），牌面左右各留 10% 的边，
## 所以牌面宽 = 牌宽的 80%，牌身圆角换算到牌面里就是 14% ÷ 80% = 17.5%。
const TILE_CORNER_RATIO := 0.14
const FACE_INSET_RATIO := 0.1
## 花牌贴图自己的圆角再收一点，比牌身的圆角小一圈，看着更秀气
## （1.0 = 跟牌身圆角一样大，越小越接近直角）
const FLOWER_CORNER_SCALE := 0.7
## 花牌贴图比留给它的位置再放大一点：标准牌（宽 64 像素）上宽高各多 3 像素，
## 牌大了按比例跟着多，小牌也是一样的观感。
const FLOWER_GROW := Vector2(3.0, 3.0)
const DESIGN_TILE_WIDTH := 64.0

## 真牌上的「五」用的是大写「伍」，其余用普通写法
const NUMERALS := ["一", "二", "三", "四", "伍", "六", "七", "八", "九"]
const WINDS := ["東", "南", "西", "北"]
## 条子的竹节：中间收腰的程度（0 = 直筒，越大腰越细）
const STICK_PINCH := 0.42

var kind: int = -1
var _detail: bool = true
var _face_down: bool = false
var _texture: Texture2D = null
var _round_material: ShaderMaterial
## 牌面上的字用毛笔楷体，跟真牌一致（所有牌共用一份）
static var _glyph_font: Font


func setup(tile_kind: int, face_down: bool = false, texture: Texture2D = null) -> void:
	kind = tile_kind
	_face_down = face_down
	_texture = texture
	# 花牌图片带 mipmap，得显式开「线性 + mipmap」的采样，
	# 不然牌面缩到几十像素宽的时候边缘会闪、圆角也看不出来。
	texture_filter = (CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if texture != null
		else CanvasItem.TEXTURE_FILTER_PARENT_NODE)
	if texture != null:
		# 每张花牌自己一份材质，圆角半径是跟着牌的大小算的，不能共用
		if _round_material == null:
			_round_material = ShaderMaterial.new()
			_round_material.shader = ROUND_MASK
		material = _round_material
	else:
		material = null
	queue_redraw()


func _draw() -> void:
	if _texture != null:
		_draw_texture()
		return
	if _face_down:
		_draw_back()
		return
	if kind < 0 or kind >= TileCodec.KIND_COUNT:
		return
	if size.x < 2.0 or size.y < 2.0:
		return

	var scale := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_detail = scale >= 0.42  # 太小的时候就少画细节，免得糊成一团
	draw_set_transform((size - DESIGN * scale) * 0.5, 0.0, Vector2(scale, scale))

	var rank := TileCodec.rank_of(kind)
	var suit := TileCodec.suit_of(kind)
	if suit == TileCodec.Suit.WAN:
		_draw_wan(rank)
	elif suit == TileCodec.Suit.TONG:
		_draw_tong(rank)
	elif suit == TileCodec.Suit.TIAO:
		_draw_tiao(rank)
	elif suit == TileCodec.Suit.WIND:
		_draw_wind(rank)
	else:
		_draw_dragon(rank)


func _draw_texture() -> void:
	## 花牌：图片按自己的比例贴满牌面（不拉伸），四角交给着色器裁圆角，
	## 所以 9:12、9:14 甚至别的比例丢进来都能贴，不用改代码。
	if size.x < 2.0 or size.y < 2.0:
		return
	var art := _texture.get_size()
	if art.x < 1.0 or art.y < 1.0:
		return
	# 先把「可贴的范围」撑大 3 像素，再按图片比例塞进去（不拉伸）
	var tile_w := size.x / (1.0 - 2.0 * FACE_INSET_RATIO)
	var room := size + FLOWER_GROW * (tile_w / DESIGN_TILE_WIDTH)
	var scale := minf(room.x / art.x, room.y / art.y)
	var box := art * scale
	var rect := Rect2((size - box) * 0.5, box)
	if _round_material != null:
		_round_material.set_shader_parameter("mask_rect", rect)
		_round_material.set_shader_parameter("corner_radius",
			size.x * TILE_CORNER_RATIO / (1.0 - 2.0 * FACE_INSET_RATIO) * FLOWER_CORNER_SCALE)
	draw_texture_rect(_texture, rect, false)


func _draw_back() -> void:
	## 牌背：底色由 TileBody 给，这里只压一个浅色内框，看起来像背面花纹。
	if size.x < 2.0 or size.y < 2.0:
		return
	var scale := minf(size.x / DESIGN.x, size.y / DESIGN.y)
	draw_set_transform((size - DESIGN * scale) * 0.5, 0.0, Vector2(scale, scale))
	draw_rect(Rect2(13.0, 13.0, 74.0, 114.0), Color(1.0, 1.0, 1.0, 0.22), false, 6.0)
	# 中间一个菱形，像传统牌背的花纹
	var mid := Vector2(50.0, 70.0)
	var radius := 20.0
	var diamond := PackedVector2Array([
		mid + Vector2(0.0, -radius),
		mid + Vector2(radius, 0.0),
		mid + Vector2(0.0, radius),
		mid + Vector2(-radius, 0.0),
		mid + Vector2(0.0, -radius),
	])
	draw_polyline(diamond, Color(1.0, 1.0, 1.0, 0.22), 4.0, true)


# ---------------------------------------------------------------- 字形

func _text(text: String, baseline_y: float, font_size: int, color: Color) -> void:
	draw_string(_brush_font(), Vector2(0, baseline_y), text,
		HORIZONTAL_ALIGNMENT_CENTER, DESIGN.x, font_size, color)


static func _brush_font() -> Font:
	if _glyph_font == null:
		var font := SystemFont.new()
		font.font_names = PackedStringArray([
			"KaiTi", "STKaiti", "Kaiti SC", "楷体", "SimSun", "宋体", "Microsoft YaHei",
		])
		font.allow_system_fallback = true
		_glyph_font = font
	return _glyph_font


func _draw_wan(rank: int) -> void:
	# 真牌的样子：上面一个黑色的数字，下面一个红色的「萬」，两者差不多大
	_text(NUMERALS[rank - 1], 64.0, 58, INK)
	_text("萬", 126.0, 56, RED)


func _draw_wind(rank: int) -> void:
	_text(WINDS[rank - 1], 98.0, 76, INK)


func _draw_dragon(rank: int) -> void:
	if rank == 1:
		_text("中", 98.0, 76, RED)
	elif rank == 2:
		_text("發", 98.0, 76, GREEN)
	else:
		# 白板：真牌上就是一块空白，画个空心方框
		draw_rect(Rect2(28.0, 46.0, 44.0, 58.0), BLUE, false, 6.0)


# ---------------------------------------------------------------- 筒子

func _draw_dot(center: Vector2, radius: float, accent: bool) -> void:
	var color := RED if accent else BLUE
	if not _detail:
		draw_circle(center, radius, color)
		return
	draw_arc(center, radius * 0.8, 0.0, TAU, 32, color, maxf(1.5, radius * 0.3), true)
	draw_circle(center, radius * 0.26, color)


func _draw_tong(rank: int) -> void:
	var dots: Array[Vector2] = []
	var radius := 15.0
	var accent_index := -1
	match rank:
		1:
			dots = [Vector2(50, 70)]
			radius = 31.0
		2:
			dots = [Vector2(50, 44), Vector2(50, 96)]
			radius = 21.0
		3:
			dots = [Vector2(30, 34), Vector2(50, 70), Vector2(70, 106)]
			radius = 19.0
		4:
			dots = [Vector2(32, 45), Vector2(68, 45), Vector2(32, 95), Vector2(68, 95)]
			radius = 20.0
		5:
			dots = [Vector2(30, 40), Vector2(70, 40), Vector2(50, 70), Vector2(30, 100), Vector2(70, 100)]
			radius = 17.0
			accent_index = 2
		6:
			dots = [
				Vector2(32, 32), Vector2(68, 32),
				Vector2(32, 70), Vector2(68, 70),
				Vector2(32, 108), Vector2(68, 108),
			]
			radius = 16.0
		7:
			dots = [
				Vector2(30, 30), Vector2(50, 44), Vector2(70, 58),
				Vector2(32, 92), Vector2(68, 92),
				Vector2(32, 122), Vector2(68, 122),
			]
			radius = 14.0
			accent_index = -2
		8:
			dots = [
				Vector2(32, 26), Vector2(68, 26),
				Vector2(32, 58), Vector2(68, 58),
				Vector2(32, 90), Vector2(68, 90),
				Vector2(32, 122), Vector2(68, 122),
			]
			radius = 13.0
		9:
			dots = [
				Vector2(28, 32), Vector2(50, 32), Vector2(72, 32),
				Vector2(28, 70), Vector2(50, 70), Vector2(72, 70),
				Vector2(28, 108), Vector2(50, 108), Vector2(72, 108),
			]
			radius = 14.5
		_:
			return

	for i in dots.size():
		var accent := accent_index >= 0 and i == accent_index
		if accent_index == -2 and i < 3:
			accent = true  # 七筒最上面三个是红的
		_draw_dot(dots[i], radius, accent)


# ---------------------------------------------------------------- 条子

func _draw_stick(center: Vector2, dim: Vector2, accent: bool) -> void:
	## 真牌的条子是「勾线」画法：一笔轮廓，中间收腰，里面留牌面本色。
	var color := RED if accent else GREEN
	var outline := _stick_outline(center, dim)
	if _detail:
		draw_polyline(outline, color, maxf(1.8, dim.x * 0.3), true)
	else:
		# 牌太小的时候描边会糊，直接用实心
		draw_colored_polygon(outline, color)


func _stick_outline(center: Vector2, dim: Vector2) -> PackedVector2Array:
	var rx := dim.x * 0.5
	var ry := dim.y * 0.5
	var points := PackedVector2Array()
	var steps := 28
	for i in steps:
		var phi := TAU * float(i) / float(steps)
		# 椭圆两侧在腰部收进去，就成了竹节的样子
		var pinch := 1.0 - STICK_PINCH * pow(cos(phi), 2.0)
		points.append(center + Vector2(rx * pinch * cos(phi), ry * sin(phi)))
	points.append(points[0])
	return points


func _draw_tiao(rank: int) -> void:
	var sticks: Array[Vector2] = []
	var dim := Vector2(18.0, 72.0)
	var accent_index := -1
	match rank:
		1:
			sticks = [Vector2(50, 70)]
			dim = Vector2(26, 104)
		2:
			sticks = [Vector2(33, 70), Vector2(67, 70)]
			dim = Vector2(18, 76)
		3:
			sticks = [Vector2(26, 70), Vector2(50, 70), Vector2(74, 70)]
			dim = Vector2(16, 68)
		4:
			sticks = [Vector2(32, 45), Vector2(68, 45), Vector2(32, 95), Vector2(68, 95)]
			dim = Vector2(20, 42)
		5:
			sticks = [Vector2(30, 40), Vector2(70, 40), Vector2(50, 70), Vector2(30, 100), Vector2(70, 100)]
			dim = Vector2(19, 38)
			accent_index = 2
		6:
			sticks = [
				Vector2(26, 50), Vector2(50, 50), Vector2(74, 50),
				Vector2(26, 94), Vector2(50, 94), Vector2(74, 94),
			]
			dim = Vector2(16, 36)
		7:
			sticks = [
				Vector2(50, 26),
				Vector2(26, 70), Vector2(50, 70), Vector2(74, 70),
				Vector2(26, 112), Vector2(50, 112), Vector2(74, 112),
			]
			dim = Vector2(15, 32)
			accent_index = 0
		8:
			sticks = [
				Vector2(19, 50), Vector2(40, 50), Vector2(61, 50), Vector2(82, 50),
				Vector2(19, 94), Vector2(40, 94), Vector2(61, 94), Vector2(82, 94),
			]
			dim = Vector2(13, 36)
		9:
			sticks = [
				Vector2(26, 32), Vector2(50, 32), Vector2(74, 32),
				Vector2(26, 70), Vector2(50, 70), Vector2(74, 70),
				Vector2(26, 108), Vector2(50, 108), Vector2(74, 108),
			]
			dim = Vector2(15, 30)
		_:
			return

	for i in sticks.size():
		_draw_stick(sticks[i], dim, i == accent_index)
