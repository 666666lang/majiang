class_name TileBody
extends Control
## 牌的立体外形：投影 + 侧面厚度 + 正面 + 顶部倒角高光。
##
## 画法是从下往上叠：
##   1. 先画一层柔和的投影，让牌「浮」在桌面上
##   2. 再画底面（比正面深一点的骨色），位置往下错开一个厚度
##   3. 正面盖上去，只在下方露出那条厚度，就成了牌的侧边
##   4. 最后在正面顶部压一条高光，做出倒角

var face_color := Color(0.949, 0.933, 0.878)
var side_color := Color(0.66, 0.64, 0.58)
var edge_color := Color(0.725, 0.694, 0.612)
var edge_width := 1.5
var highlight_color := Color(1.0, 1.0, 1.0, 0.55)
var thickness := 5.0
var raised := false


func configure(p_face: Color, p_side: Color, p_edge: Color, p_edge_width: float, p_thickness: float,
		p_raised: bool = false) -> void:
	face_color = p_face
	side_color = p_side
	edge_color = p_edge
	edge_width = p_edge_width
	thickness = p_thickness
	raised = p_raised
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 8.0 or h < 8.0:
		return
	# 圆角按牌宽等比走，大牌小牌看起来才是同一个造型
	var radius := w * 0.14
	var bottom := Rect2(0.0, thickness, w, h - thickness)

	draw_style_box(_shadow_box(radius, w, h), Rect2(Vector2.ZERO, Vector2(w, h)))
	draw_style_box(_plain_box(side_color, radius), bottom)
	draw_style_box(_plain_box(face_color, radius, edge_width, edge_color),
		Rect2(0.0, 0.0, w, h - thickness))
	# 顶部高光，做出倒角
	draw_style_box(_plain_box(highlight_color, maxf(2.0, radius - 3.0)),
		Rect2(3.0, 2.0, w - 6.0, maxf(2.5, (h - thickness) * 0.075)))


func _plain_box(bg: Color, radius: float, border_width: float = 0.0,
		border_color: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(int(round(radius)))
	style.set_border_width_all(int(round(border_width)))
	style.border_color = border_color
	return style


func _shadow_box(radius: float, w: float, h: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)  # 只要阴影，不要实体
	style.set_corner_radius_all(int(round(radius)))
	# 阴影跟着牌的大小走，小牌用大阴影会糊成一团
	var shadow_size := clampf(w * 0.09, 3.0, 7.0)
	var shadow_dy := clampf(h * 0.045, 2.0, 5.0)
	var shadow_alpha := 0.30
	if raised:
		# 抬起来的时候阴影更大更淡，像真的离开桌面
		shadow_size += 3.0
		shadow_dy += 2.0
		shadow_alpha -= 0.05
	style.shadow_color = Color(0, 0, 0, shadow_alpha)
	style.shadow_size = int(round(shadow_size))
	style.shadow_offset = Vector2(0, shadow_dy)
	return style
