class_name UiStyle
extends RefCounted
## 界面配色和控件样式，菜单和牌桌共用一套，改一处两边都变。

const BG := Color(0.055, 0.231, 0.18)
const GOLD := Color(0.95, 0.79, 0.36)
const DIM := Color(0.75, 0.85, 0.8)
const PANEL := Color(0.075, 0.28, 0.22)
const EPIC := Color(0.827, 0.635, 0.98)   # 史诗花牌的标签颜色

const ACTION_GOLD := Color(0.898, 0.706, 0.278)
const ACTION_RED := Color(0.784, 0.263, 0.204)
const ACTION_SLATE := Color(0.255, 0.345, 0.322)
const ACTION_INK := Color(0.145, 0.129, 0.075)
const ACTION_LIGHT := Color(0.98, 0.965, 0.94)
## 书法风的字体：行楷最像毛笔，没有就退到楷体
const BRUSH_FONT_NAMES := [
	"STXingkai", "华文行楷", "STKaiti", "KaiTi", "楷体", "Microsoft YaHei",
]

static var _brush_font: Font


static func brush_font() -> Font:
	if _brush_font == null:
		var font := SystemFont.new()
		font.font_names = PackedStringArray(BRUSH_FONT_NAMES)
		font.allow_system_fallback = true
		_brush_font = font
	return _brush_font


static func brush_label(text: String, font_size: int, color: Color) -> Label:
	## 书法风的文字（按钮上的「下一关」这类）
	var node := label(text, font_size, color)
	node.add_theme_font_override("font", brush_font())
	return node


static func label(text: String, font_size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	return node


static func apply_cjk_theme(node: Control) -> void:
	## Godot 默认字体没有中文字形，换成一串系统中文字体
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "PingFang SC",
	])
	font.allow_system_fallback = true
	var ui_theme := Theme.new()
	ui_theme.default_font = font
	ui_theme.default_font_size = 20
	node.theme = ui_theme


static func button(text: String, base: Color, text_color: Color,
		min_size := Vector2(176, 58)) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_stylebox_override("normal", box(base, false))
	button.add_theme_stylebox_override("hover", box(base.lightened(0.12), true))
	button.add_theme_stylebox_override("pressed", box(base.darkened(0.12), false))
	button.add_theme_stylebox_override("disabled", box(base.darkened(0.5), false))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_disabled_color", Color(text_color, 0.4))
	return button


static func box(base: Color, hovered: bool) -> StyleBoxFlat:
	## 圆角 + 描边 + 投影，和麻将牌一个路子
	var style := StyleBoxFlat.new()
	style.bg_color = base
	style.set_corner_radius_all(16)
	style.set_border_width_all(2)
	style.border_color = base.lightened(0.35)
	style.content_margin_left = 30.0
	style.content_margin_right = 30.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 9 if hovered else 5
	style.shadow_offset = Vector2(0, 4)
	return style


static func slider() -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(320, 36)
	slider.focus_mode = Control.FOCUS_NONE
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# 轨道：深色圆角条；已选部分：金色；滑块：金色小圆点
	slider.add_theme_stylebox_override("slider", _track(Color(0.04, 0.16, 0.13)))
	slider.add_theme_stylebox_override("grabber_area", _track(ACTION_GOLD))
	slider.add_theme_stylebox_override("grabber_area_highlight", _track(ACTION_GOLD.lightened(0.15)))
	slider.add_theme_icon_override("grabber", _grabber(ACTION_GOLD))
	slider.add_theme_icon_override("grabber_highlight", _grabber(ACTION_GOLD.lightened(0.2)))
	slider.add_theme_icon_override("grabber_disabled", _grabber(ACTION_GOLD.darkened(0.4)))
	return slider


static func _track(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(5)
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


static func _grabber(color: Color) -> Texture2D:
	## 用代码画一个小圆点当滑块，省得为它准备图片资源
	var size := 20
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(size * 0.5, size * 0.5)
	for y in size:
		for x in size:
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if distance <= size * 0.5 - 1.5:
				image.set_pixel(x, y, color)
			elif distance <= size * 0.5:
				image.set_pixel(x, y, Color(color, 0.45))
	return ImageTexture.create_from_image(image)


static func capture_and_quit(node: Node) -> void:
	## 调试用：截图存到 res://.dev/screenshot.png 然后退出
	for i in 4:
		await node.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := node.get_viewport().get_texture().get_image()
	var dir := "res://.dev"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	image.save_png(dir + "/screenshot.png")
	print("screenshot saved to ", dir + "/screenshot.png")
	node.get_tree().quit()
