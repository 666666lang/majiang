class_name TileWidget
extends Button
## 单张牌。
##
## 结构：Button 只负责接收鼠标（悬停 / 按下 / 点击），本身不画东西；
## 里面套一层 _stack，放了 TileBody（立体外形）和 TileFace（牌面图案）。
## 鼠标移上来的时候移动 _stack，牌就整块往上抬一点，牌桌感就出来了。

const TILE_SIZE := Vector2(64, 88)
const COMPACT_SIZE := Vector2(44, 60)
const FACE_COLOR := Color(0.949, 0.933, 0.878)
const FACE_COLOR_DRAWN := Color(1.0, 0.973, 0.859)
const BORDER_COLOR := Color(0.725, 0.694, 0.612)
const DRAWN_BORDER := Color(0.902, 0.686, 0.2)
const MELD_BORDER := Color(0.29, 0.55, 0.65)
const CONCEALED_BORDER := Color(0.52, 0.34, 0.68)
const HINT_BORDER := Color(0.87, 0.26, 0.2)   # 提示「打这张能听牌」的红描边
const FLOWER_FACE := Color(0.98, 0.93, 0.86)  # 花牌：底色偏暖一点
const SELECT_BORDER := Color(1.0, 0.79, 0.2)
const BACK_COLOR := Color(0.157, 0.549, 0.475)
const BACK_BORDER := Color(0.055, 0.243, 0.208)
const HOVER_LIFT := 9.0    # 鼠标悬停时抬起的高度（像素）
const LIFT_TIME := 0.1     # 抬起 / 落下的时间（秒）
const DEAL_DROP := 66.0    # 发牌时从多高处落下来
const DEAL_TIME := 0.3     # 落下来的时间
const DRAW_DROP := 54.0    # 摸牌时从多高处落到手上
const DRAW_TIME := 0.24
const JUMP_HEIGHT := 20.0  # 花牌生效时往上跳多高（牌桌顶上那行花牌贴边，跳太高会被屏幕裁掉）
const JUMP_TIME := 0.16    # 跳上去的时间
const JUMP_FALL := 0.26    # 落回来的时间
const JUMP_SCALE := 1.10   # 跳的时候顺带放大一点，跳完回原样

var kind: int = -1
var selected: bool = false
var is_drawn: bool = false
var is_melded: bool = false
var is_concealed: bool = false
var hinted: bool = false
var face_down: bool = false

var _stack: Control
var _body: TileBody
var _face: TileFace
var _hovered: bool = false
var _held: bool = false
var _thickness: float = 5.0
var _tile_size: Vector2 = TILE_SIZE
var _flower_texture: Texture2D = null
var is_flower: bool = false
var _tween: Tween


func _init() -> void:
	custom_minimum_size = TILE_SIZE
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# 外形和牌面都自己画，Button 自带的样式全部清空
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())


func setup(tile_kind: int, drawn: bool = false, compact: bool = false, melded: bool = false) -> void:
	kind = tile_kind
	is_drawn = drawn
	is_melded = melded
	text = ""  # 牌面不用文字
	_tile_size = COMPACT_SIZE if compact else TILE_SIZE
	custom_minimum_size = _tile_size
	_thickness = clampf(_tile_size.y * 0.09, 4.0, 10.0)
	_build_children(compact)
	_apply_state()


func setup_back(tile_size: Vector2) -> void:
	## 牌背朝上（别家的手牌）：只有外形，纯装饰，不接受操作。
	kind = -1
	face_down = true
	text = ""
	_tile_size = tile_size
	custom_minimum_size = _tile_size
	_thickness = clampf(tile_size.y * 0.14, 4.5, 9.0)  # 别家的牌小，厚度占更大比例才看得出立体
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	_build_children(false)
	_apply_state()


func set_tile_size(tile_size: Vector2, thickness_ratio: float = 0.12) -> void:
	## 牌河这类自定义尺寸用：先 setup 出牌面，再按需要缩放。
	_tile_size = tile_size
	custom_minimum_size = tile_size
	_thickness = clampf(tile_size.y * thickness_ratio, 3.0, 9.0)
	_apply_state()


func setup_flower(texture_path: String, tile_size: Vector2 = TILE_SIZE) -> void:
	## 花牌：牌面用图片。找不到图片就留一块空白牌，不会报错。
	is_flower = true
	kind = -1
	face_down = false
	text = ""
	_tile_size = tile_size
	custom_minimum_size = tile_size
	_thickness = clampf(tile_size.y * 0.12, 4.0, 9.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	_flower_texture = null
	if texture_path != "":
		_flower_texture = FlowerTiles.face_texture(texture_path)
	_build_children(false)
	_apply_state()


func set_concealed(value: bool) -> void:
	## 暗杠：牌还是自己扣下的，用另一种颜色标出来
	is_concealed = value
	_apply_state()


func set_hinted(value: bool) -> void:
	## 听牌提示：这张打出去就能听牌
	hinted = value
	_apply_state()


func _build_children(compact: bool) -> void:
	if _stack != null:
		return
	_stack = Control.new()
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.anchor_right = 1.0
	_stack.anchor_bottom = 1.0
	add_child(_stack)

	_body = TileBody.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.anchor_right = 1.0
	_body.anchor_bottom = 1.0
	_stack.add_child(_body)

	_face = TileFace.new()
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.anchor_right = 1.0
	_face.anchor_bottom = 1.0
	_stack.add_child(_face)

	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))
	button_down.connect(_on_pressed_changed.bind(true))
	button_up.connect(_on_pressed_changed.bind(false))


func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	pivot_offset = _tile_size * 0.5
	scale = Vector2(1.08, 1.08) if selected else Vector2.ONE
	_apply_state()


func preview_hover(value: bool) -> void:
	## 调试用：截图时手动摆出「鼠标悬停」的样子（不走动画，方便截图）。
	_hovered = value
	_apply_state()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var lifted := -HOVER_LIFT if value else 0.0
	_stack.offset_top = lifted
	_stack.offset_bottom = lifted


func play_deal(delay: float) -> void:
	play_drop(DEAL_DROP, DEAL_TIME, delay)


func play_draw(delay: float = 0.0) -> void:
	## 摸牌动画：从牌墙方向落到手上，比发牌快一点。
	play_drop(DRAW_DROP, DRAW_TIME, delay)


func play_drop(from_height: float, duration: float, delay: float = 0.0) -> void:
	## 从上方落下来，落地弹一下，像把牌放到桌上。
	if _stack == null or not is_inside_tree():
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_stack.offset_top = -from_height
	_stack.offset_bottom = -from_height
	modulate.a = 0.0

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.12).set_delay(delay)
	_tween.tween_property(_stack, "offset_top", 0.0, duration) \
		.set_delay(delay).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_stack, "offset_bottom", 0.0, duration) \
		.set_delay(delay).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func play_jump() -> void:
	## 花牌生效时跳一下：先弹上去、再落回原位，顺带放大一点点。
	## 走 _stack 的偏移，不会跟容器排版打架。
	if _stack == null or not is_inside_tree():
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	pivot_offset = _tile_size * 0.5
	_stack.offset_top = 0.0
	_stack.offset_bottom = 0.0

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_stack, "offset_top", -JUMP_HEIGHT, JUMP_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_stack, "offset_bottom", -JUMP_HEIGHT, JUMP_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2(JUMP_SCALE, JUMP_SCALE), JUMP_TIME)
	_tween.set_parallel(false)
	_tween.tween_property(_stack, "offset_top", 0.0, JUMP_FALL) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_stack, "offset_bottom", 0.0, JUMP_FALL) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "scale", Vector2.ONE, JUMP_FALL) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- 状态

func _on_hover_changed(value: bool) -> void:
	if _hovered == value:
		return
	_hovered = value
	if value:
		Sfx.play("impact")  # 鼠标压到牌上的那一刻
	_apply_state()


func _on_pressed_changed(value: bool) -> void:
	_held = value
	_apply_lift()


func _apply_state() -> void:
	var face := FACE_COLOR_DRAWN if is_drawn else FACE_COLOR
	if is_flower:
		face = FLOWER_FACE
	if face_down:
		face = BACK_COLOR
	if _hovered:
		face = face.lightened(0.05)

	var edge := BORDER_COLOR
	var edge_width := 1.5
	if face_down:
		edge = BACK_BORDER
	elif is_concealed:
		edge = CONCEALED_BORDER
	elif is_melded:
		edge = MELD_BORDER
	elif is_drawn:
		edge = DRAWN_BORDER
	if selected:
		edge = SELECT_BORDER
		edge_width = 3.5
	elif _hovered:
		edge = SELECT_BORDER
		edge_width = 2.0
	elif hinted:
		edge = HINT_BORDER
		edge_width = 3.0

	var inset := _tile_size.x * 0.1
	_body.visible = true
	_face.offset_left = inset
	_face.offset_top = inset
	_face.offset_right = -inset
	_face.offset_bottom = -(inset + _thickness)
	_face.setup(kind, face_down, _flower_texture)
	_body.configure(face, face.darkened(0.32), edge, edge_width, _thickness, _hovered)
	_apply_lift()


func _apply_lift() -> void:
	## 悬停时抬起，按住时压下去一点。
	var target := 0.0
	if _held:
		target = HOVER_LIFT * 0.3
	elif _hovered:
		target = HOVER_LIFT

	if not is_inside_tree():
		_stack.offset_top = -target
		_stack.offset_bottom = -target
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_stack, "offset_top", -target, LIFT_TIME)
	_tween.tween_property(_stack, "offset_bottom", -target, LIFT_TIME)
