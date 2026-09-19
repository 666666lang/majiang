extends Control
## 主界面：发 13 张牌，用 18 次换牌机会试着胡牌。
##
## 版面按牌桌习惯排：电脑打出的牌在画面上方，玩家的手牌和副露在下方。
## 一轮的节奏：摸牌 → 玩家打出一张 → 电脑一张一张出牌（每张都检测
## 玩家能不能荣和 / 碰，能就停下来问）。

const BG_COLOR := UiStyle.BG
const GOLD := UiStyle.GOLD
const DIM := UiStyle.DIM
const EPIC := UiStyle.EPIC
const ACTION_GOLD := UiStyle.ACTION_GOLD
const ACTION_RED := UiStyle.ACTION_RED
const ACTION_SLATE := UiStyle.ACTION_SLATE
const ACTION_INK := UiStyle.ACTION_INK
const ACTION_LIGHT := UiStyle.ACTION_LIGHT
const AI_DISCARD_DELAY := 0.45  # 电脑两张牌之间的间隔（秒）
const DEAL_DELAY := 0.1         # 发牌时每张牌之间的间隔（秒）
const OPPONENT_HAND_SIZE := 13  # 别家手牌张数（纯装饰）
## 三家的牌用同一款，宽高比跟真牌一样（约 0.7），左右两家旋转 90 度
const OPPONENT_TILE := Vector2(30, 43)
## 牌河里的牌比手牌小一圈，四家的牌河才摆得下
const POOL_TILE := Vector2(26, 37)
## 听牌提示那一行的高度：一开始不显示，但位置要一直占着，免得出现的时候版面跳
const HINT_SLOT_HEIGHT := 30.0
## 副露（碰、杠）那一行的位置和大小：同样一直占着，出现副露时不推版面
const MELD_SLOT_HEIGHT := 66.0
const MELD_TILE := Vector2(44, 60)  # 比手牌小一圈，一眼能分出哪些是碰杠的
## 按钮在屏幕中线之上再抬这么高，跟自己的牌河拉开距离
const ACTION_RAISE := 48.0

var round_: MahjongRound
var ai_discard_delay: float = AI_DISCARD_DELAY  # 测试里会调成 0
var level: int = 1              # 当前第几关
var _selected_index: int = -1
var _has_selection: bool = false
var _ai_running: bool = false
var _draw_animated_for: int = -1  # 已经播过入场动画的那次摸牌

var _level_value: Label
var _wall_value: Label
var _tour_value: Label
var _remain_value: Label
var _target_value: Label
var _score_value: Label
var _tile_row: HBoxContainer
var _meld_row: HBoxContainer
var _hint_label: Label
var _action_row: HBoxContainer
var _center: Control
var _across_row: HBoxContainer
var _my_pool: DiscardPool
var _across_pool: DiscardPool
var _left_pool: DiscardPool
var _right_pool: DiscardPool
var _draw_button: Button
var _discard_button: Button
var _ron_button: Button
var _pong_button: Button
var _kong_button: Button
var _concealed_kong_button: Button
var _pass_button: Button
var _settle_panel: PanelContainer
var _settle_title: Label
var _settle_score: Label
var _settle_target: Label
var _settle_coin: Label
var _settle_total: Label
var _settle_coin_row: Control
var _settle_total_row: Control
var _settle_tours: Label
var _settle_score_row: Control
var _settle_target_row: Control
var _settle_tours_row: Control
var _settle_tour_bonus: Label
var _settle_tour_bonus_row: Control
var _settle_button: Button
var _coin_value: Label
var _combo_value: Label
var _combo_row: Control
var _settle_page: VBoxContainer
var _shop_page: VBoxContainer
var _shop_balance: Label
var _shop_slots: Array = []
var _flower_slots: Array = []
var _shop_next_button: Button
var _run_bonus := {"wan": 0, "tong": 0, "tiao": 0, "honor": 0}
var _owned_flowers: Array[String] = []    # 本局买到的花牌（按图片名，花牌只卖一次）
var _settled_round: MahjongRound = null  # 已经结过算的那一局，防止重复发银两
var _hint_discards: Array = []            # 这一手打出去能听牌的牌


func _ready() -> void:
	Settings.reset_coins()  # 金币每次游戏从 0 开始算
	_apply_theme()
	if "--flowers" in OS.get_cmdline_user_args():
		_build_flower_sheet()
		if "--shot" in OS.get_cmdline_user_args():
			UiStyle.capture_and_quit(self)
		return
	if "--sheet" in OS.get_cmdline_user_args():
		_build_tile_sheet()
		if "--shot" in OS.get_cmdline_user_args():
			_capture_and_quit()
		return
	_build_ui()
	_start_new_round()
	if "--shot" in OS.get_cmdline_user_args():
		_setup_debug_shot()
		_capture_and_quit()


func _unhandled_input(event: InputEvent) -> void:
	# 按 Esc 回主界面（设置在那里）
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _build_tile_sheet() -> void:
	## 调试用：把 34 种牌面一次性铺出来，方便检查图案。
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var grid := HFlowContainer.new()
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)
	for kind in TileCodec.KIND_COUNT:
		var tile := TileWidget.new()
		tile.setup(kind)
		tile.custom_minimum_size = Vector2(128, 180)
		grid.add_child(tile)
	# 最后补几张牌背，方便单独检查背面的样子
	for i in 3:
		var back := TileWidget.new()
		back.setup_back(Vector2(128, 180))
		grid.add_child(back)


func _build_flower_sheet() -> void:
	## 调试用：把花牌图片按大牌铺出来，检查贴在牌面上的效果
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var wrap := CenterContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(wrap)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	wrap.add_child(row)
	for flower in FlowerTiles.available():
		var tile := TileWidget.new()
		tile.setup_flower(flower["path"], Vector2(400, 622))
		row.add_child(tile)


func _apply_theme() -> void:
	UiStyle.apply_cjk_theme(self)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 28)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	# ---- 牌桌 + 右侧分数牌 ----
	var main_row := HBoxContainer.new()
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 18)
	column.add_child(main_row)

	# 左列：牌桌 + 自己的手牌（手牌跟牌桌同宽，不会伸到分数牌下面）
	var play_column := VBoxContainer.new()
	play_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play_column.add_theme_constant_override("separation", 12)
	main_row.add_child(play_column)

	# 牌桌：三家的手牌做背景，中央放牌河和按钮
	var table := HBoxContainer.new()
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table.add_theme_constant_override("separation", 14)
	play_column.add_child(table)

	table.add_child(_make_side_wall(PI * 0.5))  # 上家（左）

	# 中央区域自己算坐标：四家牌河要按座位方向摆，容器排不出来
	_center = Control.new()
	_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_center.resized.connect(_layout_table)
	table.add_child(_center)

	# 对家的手牌
	_across_row = HBoxContainer.new()
	_across_row.add_theme_constant_override("separation", 0)  # 牌与牌紧靠，不留缝
	_center.add_child(_across_row)
	for i in OPPONENT_HAND_SIZE:
		_across_row.add_child(_make_back_tile(OPPONENT_TILE))

	# 四家牌河：朝向分别是 自己 / 对面 / 上家 / 下家
	_my_pool = _make_pool(0.0)
	_across_pool = _make_pool(PI)
	_left_pool = _make_pool(PI * 0.5)
	_right_pool = _make_pool(-PI * 0.5)

	# ---- 操作按钮：摆在画面正中，只在需要做决定的时候出现 ----
	_action_row = HBoxContainer.new()
	_action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_action_row.add_theme_constant_override("separation", 20)
	_action_row.size = Vector2.ZERO
	_center.add_child(_action_row)

	_draw_button = _make_action_button("摸牌", _on_draw_pressed, ACTION_GOLD, ACTION_INK)
	_action_row.add_child(_draw_button)
	_discard_button = _make_action_button("打出", _on_discard_pressed, ACTION_GOLD, ACTION_INK)
	_action_row.add_child(_discard_button)
	_ron_button = _make_action_button("荣和", _on_ron_pressed, ACTION_RED, ACTION_LIGHT)
	_action_row.add_child(_ron_button)
	_kong_button = _make_action_button("杠", _on_kong_pressed, ACTION_RED, ACTION_LIGHT)
	_action_row.add_child(_kong_button)
	_pong_button = _make_action_button("碰", _on_pong_pressed, ACTION_RED, ACTION_LIGHT)
	_action_row.add_child(_pong_button)
	_concealed_kong_button = _make_action_button("暗杠", _on_concealed_kong_pressed, ACTION_RED, ACTION_LIGHT)
	_action_row.add_child(_concealed_kong_button)
	_pass_button = _make_action_button("过", _on_pass_pressed, ACTION_SLATE, ACTION_LIGHT)
	_action_row.add_child(_pass_button)
	table.add_child(_make_side_wall(-PI * 0.5))  # 下家（右）
	main_row.add_child(_build_scoreboard())
	_build_settlement()

	# ---- 下方：玩家的手牌与副露 ----
	var hand_box := VBoxContainer.new()
	hand_box.add_theme_constant_override("separation", 8)
	play_column.add_child(hand_box)

	# 顺序：听牌提示 → 手牌 → 副露。
	# 提示在手牌上方、副露在最底部，这样手牌能贴着屏幕下方，底部不留空档。
	var hint_slot := Control.new()
	hint_slot.custom_minimum_size = Vector2(0.0, HINT_SLOT_HEIGHT)
	hint_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_box.add_child(hint_slot)

	_hint_label = _make_label("", 18, DIM)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	hint_slot.add_child(_hint_label)

	var row_wrap := CenterContainer.new()
	hand_box.add_child(row_wrap)
	_tile_row = HBoxContainer.new()
	_tile_row.add_theme_constant_override("separation", 4)
	row_wrap.add_child(_tile_row)

	# 碰过 / 杠过的牌单独一行，放在手牌下面，免得手牌被挤窄
	var meld_slot := Control.new()
	meld_slot.custom_minimum_size = Vector2(0.0, MELD_SLOT_HEIGHT)
	meld_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_box.add_child(meld_slot)
	_meld_row = HBoxContainer.new()
	_meld_row.add_theme_constant_override("separation", 0)  # 跟牌河一样紧靠不留缝
	_meld_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	_meld_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_meld_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meld_slot.add_child(_meld_row)


func _make_side_wall(rotated: float) -> Control:
	## 左右两家的一排手牌：13 张背面朝上，竖着排，纯背景。
	var wall := VBoxContainer.new()
	wall.alignment = BoxContainer.ALIGNMENT_CENTER
	wall.add_theme_constant_override("separation", 0)  # 牌与牌紧靠，不留缝
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in OPPONENT_HAND_SIZE:
		wall.add_child(_make_back_tile(OPPONENT_TILE, rotated))
	return wall


func _make_back_tile(tile_size: Vector2, rotated: float = 0.0) -> Control:
	var tile := TileWidget.new()
	tile.setup_back(tile_size)
	if is_zero_approx(rotated):
		return tile
	# 侧边的牌是竖着摆的：外面套一层壳负责占位，牌本体绕自己的中心转 90 度
	var wrapper := Control.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.custom_minimum_size = Vector2(tile_size.y, tile_size.x)
	tile.rotation = rotated
	tile.pivot_offset = tile_size * 0.5
	tile.position = (wrapper.custom_minimum_size - tile_size) * 0.5
	wrapper.add_child(tile)
	return wrapper


func _make_pool(facing: float) -> DiscardPool:
	var pool := DiscardPool.new()
	pool.setup(POOL_TILE, facing)
	pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.add_child(pool)
	return pool


func _layout_table() -> void:
	## 中央区域是手动排的：对家手牌贴顶，我的牌河贴底，左右两家牌河贴两侧，
	## 按钮放在中间偏上一点。
	if _center == null:
		return
	var area := _center.size
	if area.x < 40.0 or area.y < 40.0:
		return
	var cx := area.x * 0.5

	_across_row.size = _across_row.get_combined_minimum_size()
	_across_row.position = Vector2(cx - _across_row.size.x * 0.5, 0.0)

	var pool_size := _my_pool.size            # 牌河未旋转时的尺寸
	var depth := pool_size.y                  # 牌河朝中心方向的深度
	var across_depth := pool_size.x           # 旋转 90 度后视觉上的深度

	# 对家：紧贴自己手牌的下方，往中心长
	_across_pool.position = Vector2(cx - pool_size.x * 0.5, _across_row.size.y + 8.0)
	# 自己：紧贴区域底部，往中心长（就在自己手牌上方）
	_my_pool.position = Vector2(cx - pool_size.x * 0.5, area.y - pool_size.y)
	# 上家、下家：贴左右两侧，垂直居中
	var side_y := area.y * 0.5
	_left_pool.position = Vector2(across_depth * 0.5, side_y) - pool_size * 0.5
	_right_pool.position = Vector2(area.x - across_depth * 0.5, side_y) - pool_size * 0.5

	# 按钮：屏幕中线再往上抬一点，正好落在上下两条牌河中间（换算成局部坐标）
	_action_row.size = _action_row.get_combined_minimum_size()
	var screen_center_y := get_viewport_rect().size.y * 0.5
	var local_center_y := screen_center_y - ACTION_RAISE - _center.global_position.y
	_action_row.position = Vector2(cx - _action_row.size.x * 0.5,
		local_center_y - _action_row.size.y * 0.5)


func _rebuild_pools() -> void:
	_my_pool.set_discards(round_.discards)

	# 电脑每轮打三张，按顺序分给三家：下家 → 对家 → 上家
	var to_right: Array[int] = []
	var to_across: Array[int] = []
	var to_left: Array[int] = []
	for i in round_.ai_discards.size():
		var kind: int = round_.ai_discards[i]
		match i % 3:
			0:
				to_right.append(kind)
			1:
				to_across.append(kind)
			_:
				to_left.append(kind)

	var claiming := round_.state == MahjongRound.State.CLAIM
	var last_slot := (round_.ai_discards.size() - 1) % 3
	_right_pool.set_discards(to_right)
	_right_pool.highlight_last(claiming and last_slot == 0)
	_across_pool.set_discards(to_across)
	_across_pool.highlight_last(claiming and last_slot == 1)
	_left_pool.set_discards(to_left)
	_left_pool.highlight_last(claiming and last_slot == 2)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_action_button(text: String, handler: Callable, base: Color, text_color: Color,
		min_size := Vector2(176, 58)) -> Button:
	var button := UiStyle.button(text, base, text_color, min_size)
	button.pressed.connect(handler)
	return button


func _build_scoreboard() -> PanelContainer:
	## 右侧常驻的分数牌：当前巡 / 剩余巡 / 目标分数 / 当前得分
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(236, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL  # 跟牌桌一样高，做成一条侧栏
	var style := StyleBoxFlat.new()
	style.bg_color = UiStyle.PANEL
	style.set_corner_radius_all(16)
	style.set_border_width_all(3)
	style.border_color = UiStyle.GOLD.darkened(0.4)
	style.set_content_margin_all(20.0)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	_level_value = _add_score_row(box, "当前关卡")
	_tour_value = _add_score_row(box, "当前巡")
	_remain_value = _add_score_row(box, "剩余巡")
	_target_value = _add_score_row(box, "目标分数")
	_score_value = _add_score_row(box, "当前得分", 44)  # 得分最显眼
	_wall_value = _add_score_row(box, "牌墙剩余")
	_coin_value = _add_score_row(box, "银两")
	_combo_value = _add_score_row(box, "桃花连击")
	_combo_row = _combo_value.get_parent()
	return panel


func _build_settlement() -> void:
	## 过关结算板：从屏幕左侧抽屉式滑出
	const PANEL_W := 440.0
	const PANEL_H := 620.0
	var panel := PanelContainer.new()
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -PANEL_W
	panel.offset_right = 0.0
	panel.offset_top = -PANEL_H * 0.5
	panel.offset_bottom = PANEL_H * 0.5
	panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = UiStyle.PANEL
	style.set_corner_radius_all(16)
	style.set_border_width_all(3)
	style.border_color = UiStyle.GOLD.darkened(0.4)
	style.set_content_margin_all(24.0)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 5)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	_settle_panel = panel

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	_settle_page = VBoxContainer.new()
	_settle_page.alignment = BoxContainer.ALIGNMENT_CENTER
	_settle_page.add_theme_constant_override("separation", 16)
	box.add_child(_settle_page)

	_settle_title = _make_label("过关！", 46, GOLD)
	_settle_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settle_page.add_child(_settle_title)

	_settle_score = _add_score_row(_settle_page, "本关得分", 36)
	_settle_target = _add_score_row(_settle_page, "目标分数", 36)
	_settle_score_row = _settle_score.get_parent()
	_settle_target_row = _settle_target.get_parent()
	_settle_tours = _add_score_row(_settle_page, "剩余巡数", 36)
	_settle_tour_bonus = _add_score_row(_settle_page, "剩余巡奖励", 36)
	_settle_coin = _add_score_row(_settle_page, "过关奖励", 36)
	_settle_total = _add_score_row(_settle_page, "银两总数", 36)
	_settle_tours_row = _settle_tours.get_parent()
	_settle_tour_bonus_row = _settle_tour_bonus.get_parent()
	_settle_coin_row = _settle_coin.get_parent()
	_settle_total_row = _settle_total.get_parent()

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settle_page.add_child(gap)

	_settle_button = _make_action_button("结算", _on_settle_button_pressed, ACTION_GOLD, ACTION_INK,
		Vector2(240, 64))
	_settle_page.add_child(_settle_button)

	_shop_page = _build_shop_page()
	_shop_page.visible = false
	box.add_child(_shop_page)


func _show_settlement(won: bool) -> void:
	const PANEL_W := 440.0
	const TARGET_LEFT := 24.0
	_settle_page.visible = true
	_shop_page.visible = false
	var first_time := _settled_round != round_
	_settled_round = round_
	if won:
		var base_reward := LevelTable.clear_reward(round_.level)
		var tour_bonus := round_.remaining_tours()
		var reward := base_reward + tour_bonus
		if first_time:
			Settings.add_coins(reward)
		_settle_title.text = "过关！"
		_settle_title.add_theme_color_override("font_color", GOLD)
		# 过关只写银两信息：剩余巡数、剩余巡奖励、过关奖励、总数
		_settle_tours.text = "%d 巡" % tour_bonus
		_settle_tour_bonus.text = "+%d" % tour_bonus
		_settle_coin.text = "+%d" % base_reward
		_settle_score_row.visible = false
		_settle_target_row.visible = false
		_settle_tours_row.visible = true
		_settle_tour_bonus_row.visible = true
		_settle_coin_row.visible = true
		_settle_total_row.visible = true
	else:
		_settle_title.text = "没达标"
		_settle_title.add_theme_color_override("font_color", ACTION_RED)
		_settle_coin.text = "+0"
		_settle_score_row.visible = true
		_settle_target_row.visible = true
		_settle_tours_row.visible = false
		_settle_tour_bonus_row.visible = false
		_settle_coin_row.visible = false
		_settle_total_row.visible = false
	_settle_score.text = "%d" % round_.score
	_settle_target.text = "%d" % round_.target_score
	_settle_total.text = "%d" % Settings.coins
	# 过关 → 「结算」进商店；没达标 → 「重新开始」，不给进商店
	_settle_button.text = "结算" if won else "重新开始"
	_refresh()

	_settle_panel.visible = true
	_settle_panel.offset_left = -PANEL_W
	_settle_panel.offset_right = 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_settle_panel, "offset_left", TARGET_LEFT, 0.32)
	tween.parallel().tween_property(_settle_panel, "offset_right", TARGET_LEFT + PANEL_W, 0.32)


func _hide_settlement() -> void:
	const PANEL_W := 440.0
	if not _settle_panel.visible:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_settle_panel, "offset_left", -PANEL_W, 0.24)
	tween.parallel().tween_property(_settle_panel, "offset_right", 0.0, 0.24)
	tween.tween_callback(func() -> void: _settle_panel.visible = false)


func _build_shop_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", 14)

	var title := _make_label("商店", 46, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(title)

	_shop_balance = _make_label("", 22, DIM)
	_shop_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(_shop_balance)

	# 第一行：花牌（图片在 assets/tiles/flowers/ 里）
	var row_one := HBoxContainer.new()
	row_one.alignment = BoxContainer.ALIGNMENT_CENTER
	row_one.add_theme_constant_override("separation", 14)
	for i in 2:
		var slot := _build_flower_slot(i)
		_flower_slots.append(slot)
		row_one.add_child(slot["root"])
	page.add_child(row_one)

	# 第二行：两件随机道具
	var row_two := HBoxContainer.new()
	row_two.alignment = BoxContainer.ALIGNMENT_CENTER
	row_two.add_theme_constant_override("separation", 14)
	for i in 2:
		var slot := _build_shop_slot(i)
		_shop_slots.append(slot)
		row_two.add_child(slot["root"])
	page.add_child(row_two)

	_shop_next_button = _make_action_button("下一关", _on_restart_pressed,
		ACTION_GOLD, ACTION_INK, Vector2(240, 64))
	page.add_child(_shop_next_button)
	return page


func _slot_panel(width: float, height: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, height)
	var style := StyleBoxFlat.new()
	style.bg_color = UiStyle.BG
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = UiStyle.GOLD.darkened(0.55)
	style.set_content_margin_all(12.0)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _build_flower_slot(index: int) -> Dictionary:
	var panel := _slot_panel(186.0, 204.0)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var wrap := CenterContainer.new()
	box.add_child(wrap)
	var tile := TileWidget.new()
	tile.setup_flower("")
	wrap.add_child(tile)

	var name_label := _make_label("花牌", 15, DIM)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)

	var effect := _make_label("效果待定", 13, DIM)
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(effect)

	var price := _make_label("%d 两" % FlowerTiles.PRICE, 18, GOLD)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(price)

	var buy := _make_action_button("购买", _on_buy_flower_pressed.bind(index),
		ACTION_GOLD, ACTION_INK, Vector2(150, 46))
	box.add_child(buy)
	return {
		"root": panel, "tile": tile, "name": name_label, "effect": effect,
		"price": price, "buy": buy, "flower": {},
	}


func _roll_flowers() -> void:
	## 第一行摆花牌：目录里有几张图就随机抽两张
	var flowers := FlowerTiles.roll(2, null, _owned_flowers)
	for i in _flower_slots.size():
		var slot: Dictionary = _flower_slots[i]
		var tile: TileWidget = slot["tile"]
		var name_label: Label = slot["name"]
		var effect: Label = slot["effect"]
		var price: Label = slot["price"]
		var buy: Button = slot["buy"]
		if i >= flowers.size():
			slot["flower"] = {}
			slot["bought"] = false
			tile.setup_flower("")
			if _owned_flowers.is_empty():
				name_label.text = "还没有花牌图片"
				effect.text = "放进 assets/tiles/flowers/"
			else:
				name_label.text = "已全部拥有"
				effect.text = "花牌只卖一次"
			price.text = "—"
			buy.disabled = true
			continue
		var flower: Dictionary = flowers[i]
		slot["flower"] = flower
		slot["bought"] = false
		tile.setup_flower(flower["path"])
		# 史诗花牌名字后面带个标签，一眼看出不是普通货
		if FlowerTiles.is_epic(flower["id"]):
			name_label.text = "%s · 史诗" % flower["id"]
			name_label.add_theme_color_override("font_color", EPIC)
		else:
			name_label.text = flower["id"]
			name_label.add_theme_color_override("font_color", DIM)
		var desc := FlowerTiles.effect_desc(flower["id"])
		effect.text = desc if desc != "" else "效果待定"
		_update_flower_slot(i)


func _update_flower_slot(index: int) -> void:
	var slot: Dictionary = _flower_slots[index]
	var flower: Dictionary = slot["flower"]
	var price: Label = slot["price"]
	var buy: Button = slot["buy"]
	if flower.is_empty():
		buy.disabled = true
		return
	if slot["bought"]:
		price.text = "已购买"
		buy.disabled = true
		return
	var id: String = flower["id"]
	price.text = "%d 两" % FlowerTiles.price(id)
	# 效果还没登记的花牌先不让买，免得花冤枉钱
	var key := FlowerTiles.effect_key(id)
	buy.disabled = key == "" or Settings.coins < FlowerTiles.price(id)


func _on_buy_flower_pressed(index: int) -> void:
	if index < 0 or index >= _flower_slots.size():
		return
	var slot: Dictionary = _flower_slots[index]
	var flower: Dictionary = slot["flower"]
	if flower.is_empty() or slot["bought"]:
		return
	var key := FlowerTiles.effect_key(flower["id"])
	var cost := FlowerTiles.price(flower["id"])
	if key == "" or Settings.coins < cost:
		return
	Settings.add_coins(-cost)
	_owned_flowers.append(flower["id"])
	slot["bought"] = true
	_shop_balance.text = "银两 %d" % Settings.coins
	_update_flower_slot(index)
	_refresh()


func _build_shop_slot(index: int) -> Dictionary:
	var panel := _slot_panel(186.0, 204.0)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var wrap := CenterContainer.new()
	box.add_child(wrap)
	var tile := TileWidget.new()
	tile.setup(0)
	tile.set_tile_size(Vector2(52, 72))
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(tile)

	var desc := _make_label("", 15, DIM)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(158, 42)
	box.add_child(desc)

	var price := _make_label("", 18, GOLD)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(price)

	var buy := _make_action_button("购买", _on_buy_pressed.bind(index), ACTION_GOLD, ACTION_INK,
		Vector2(150, 46))
	box.add_child(buy)

	return {
		"root": panel, "tile": tile, "desc": desc, "price": price, "buy": buy,
		"item": -1, "bought": false,
	}


func _roll_shop() -> void:
	## 每次打开商店都现抽两件
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var picks := ShopItems.roll(2, rng)
	for i in _shop_slots.size():
		var slot: Dictionary = _shop_slots[i]
		slot["item"] = picks[i]
		slot["bought"] = false
		var item: Dictionary = ShopItems.POOL[picks[i]]
		var tile: TileWidget = slot["tile"]
		tile.setup(item["tile"])
		tile.set_tile_size(Vector2(52, 72))
		var desc: Label = slot["desc"]
		desc.text = item["desc"]
		_update_shop_slot(i)


func _update_shop_slot(index: int) -> void:
	var slot: Dictionary = _shop_slots[index]
	var price: Label = slot["price"]
	var buy: Button = slot["buy"]
	if slot["bought"]:
		price.text = "已购买"
		buy.disabled = true
	else:
		price.text = "%d 两" % ShopItems.PRICE
		buy.disabled = Settings.coins < ShopItems.PRICE


func _on_settle_pressed() -> void:
	_settle_page.visible = false
	_shop_page.visible = true
	_roll_shop()
	_roll_flowers()
	_shop_balance.text = "银两 %d" % Settings.coins


func _on_settle_button_pressed() -> void:
	## 结算板上的按钮：过关才去商店，没达标就直接重开一局
	if round_.state == MahjongRound.State.WON:
		_on_settle_pressed()
	else:
		_on_restart_pressed()


func _on_buy_pressed(index: int) -> void:
	if index < 0 or index >= _shop_slots.size():
		return
	var slot: Dictionary = _shop_slots[index]
	if slot["bought"] or Settings.coins < ShopItems.PRICE:
		return
	Settings.add_coins(-ShopItems.PRICE)
	var item: Dictionary = ShopItems.POOL[slot["item"]]
	var key: String = item["key"]
	_run_bonus[key] = int(_run_bonus.get(key, 0)) + int(item["bonus"])
	slot["bought"] = true
	_shop_balance.text = "银两 %d" % Settings.coins
	_update_shop_slot(index)
	_refresh()


func _add_score_row(parent: Node, title: String, value_size: int = 32) -> Label:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	var caption := _make_label(title, 16, DIM)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(caption)
	var value := _make_label("-", value_size, GOLD)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)
	parent.add_child(row)
	return value


# ---------------------------------------------------------------- 操作

func _start_new_round() -> void:
	_selected_index = -1
	_has_selection = false
	_ai_running = false
	_draw_animated_for = -1
	_hide_settlement()
	round_ = MahjongRound.new()
	round_.changed.connect(_refresh)
	round_.finished.connect(_on_round_finished)
	# 花牌要在 start() 之前登记：满天星会给这一关多加三巡，start() 里就要算进去
	round_.flowers.clear()
	for id in _owned_flowers:
		var effect := FlowerTiles.effect_key(id)
		if effect != "":
			round_.flowers.append(effect)
	round_.start(randi(), [], level)
	# 把本局买到的道具加成带进新的一关
	for key in _run_bonus:
		round_.apply_bonus(key, _run_bonus[key])
	Music.play_track(LevelTable.bgm_name(level))
	_refresh()
	_play_deal_animation()


func _play_deal_animation() -> void:
	## 开局把 14 张牌一张一张放下来，每张相差 0.1 秒，落一张响一声。
	var index := 0
	for child in _tile_row.get_children():
		if child is TileWidget:
			var delay := index * DEAL_DELAY
			child.play_deal(delay)
			_play_sound_later(delay, "draw")
			index += 1


func _play_sound_later(delay: float, sound: String) -> void:
	## 延时播音效：发牌是「落一张响一声」，所以要跟每张牌的落下对齐
	if delay <= 0.0:
		Sfx.play(sound)
		return
	await get_tree().create_timer(delay).timeout
	Sfx.play(sound)


func _on_restart_pressed() -> void:
	if round_.state == MahjongRound.State.WON:
		if round_.level >= LevelTable.MAX_LEVEL:
			level = 1
			Settings.reset_coins()  # 通关之后重开一局，金币也重算
			_reset_run_bonus()
		else:
			level = round_.level + 1  # 过关进下一关，金币继续累计
	else:
		level = 1                  # 本关失败就从头开始
		Settings.reset_coins()     # 重开一局，金币清零
		_reset_run_bonus()
	_start_new_round()


func _reset_run_bonus() -> void:
	for key in _run_bonus:
		_run_bonus[key] = 0
	_owned_flowers.clear()


func _on_draw_pressed() -> void:
	if not round_.can_draw():
		return
	_selected_index = -1
	_has_selection = false
	round_.draw_tile()  # 内部会发 changed 信号刷新界面


func _on_discard_pressed() -> void:
	if not _has_selection:
		return
	_do_discard(_selected_index)


func _on_ron_pressed() -> void:
	round_.declare_ron()


func _on_pong_pressed() -> void:
	if round_.declare_pong():
		Sfx.play("pong")


func _on_kong_pressed() -> void:
	if round_.declare_kong():
		Sfx.play("kong")


func _on_concealed_kong_pressed() -> void:
	if round_.declare_concealed_kong():
		Sfx.play("kong")


func _on_round_finished(won: bool, description: String) -> void:
	## 三种胡法各配一个音效；「胡牌」给荣和，「自摸胡」给自摸和杠上开花。
	_show_settlement(won)
	if not won:
		return
	if description.begins_with("荣和"):
		Sfx.play("win")
	elif description.begins_with("天胡"):
		Sfx.play("tenhou", "tsumo")
	elif description.begins_with("自摸") or description.begins_with("杠上开花"):
		Sfx.play("tsumo")
	else:
		# 只是分数达标，并不是胡牌，不能借用「胡了」的音效。
		# 想给过关配声音，往 effect/ 放一个 过关.mp3（或 clear.mp3）就会响；
		# 没放的话这里就是安静的。
		Sfx.play("clear")


func _on_pass_pressed() -> void:
	if round_.state != MahjongRound.State.CLAIM:
		return
	round_.pass_claim()
	_refresh()
	_run_ai_turn()


func _on_tile_pressed(index: int) -> void:
	if round_.state != MahjongRound.State.DISCARDING:
		return
	if _has_selection and _selected_index == index:
		_do_discard(index)
		return
	_selected_index = index
	_has_selection = true
	_refresh()


func _do_discard(index: int) -> void:
	_selected_index = -1
	_has_selection = false
	Sfx.play("discard")
	round_.discard(index)
	_run_ai_turn()


func _run_ai_turn() -> void:
	## 电脑一张一张地出牌，每出一张都会检测玩家能不能荣和 / 碰。
	if _ai_running:
		return
	_ai_running = true
	_refresh()
	while not round_.opponent_turn_finished():
		await get_tree().create_timer(ai_discard_delay).timeout
		if round_.state != MahjongRound.State.AI_TURN:
			break
		round_.opponent_discard_once()
		_refresh()
		if round_.state == MahjongRound.State.CLAIM:
			_ai_running = false
			return
	_ai_running = false
	if not round_.is_over():
		round_.end_opponent_turn()
	_refresh()


# ---------------------------------------------------------------- 渲染

func _refresh() -> void:
	_hint_discards = round_.tenpai_discards()
	# 分数牌：当前关卡 / 当前巡 / 剩余巡 / 目标分数 / 当前得分 / 牌墙剩余
	_level_value.text = "第 %d 关" % round_.level
	_tour_value.text = "第 %d 巡" % round_.tour
	_remain_value.text = "%d 巡" % maxi(0, round_.total_tours - round_.tour)
	_target_value.text = "%d" % round_.target_score
	_score_value.text = "%d" % round_.score
	_wall_value.text = "%d 张" % round_.wall.remaining()
	_coin_value.text = "%d" % Settings.coins
	# 买了桃花才显示连击数
	_combo_row.visible = round_.has_flower("combo")
	if _combo_row.visible:
		_combo_value.text = "×%d" % maxi(1, round_.combo_streak)
	_rebuild_tiles()
	_rebuild_pools()
	_layout_table()
	_update_hint()

	# 按钮只在该做决定的时候出现：该摸牌就只给摸牌，该打牌就只给打出
	var state := round_.state
	var claiming := state == MahjongRound.State.CLAIM
	_draw_button.visible = state == MahjongRound.State.READY
	_discard_button.visible = state == MahjongRound.State.DISCARDING
	_ron_button.visible = claiming and round_.can_ron
	_kong_button.visible = claiming and round_.can_kong
	# 能杠的时候就不给碰了，杠优先
	_pong_button.visible = claiming and round_.can_pong and not round_.can_kong
	# 暗杠发生在自己摸完牌、还没打出去的时候
	_concealed_kong_button.visible = state == MahjongRound.State.DISCARDING and round_.can_concealed_kong()
	_pass_button.visible = claiming

	_draw_button.disabled = not round_.can_draw()
	_discard_button.disabled = not _has_selection


func _rebuild_tiles() -> void:
	for child in _tile_row.get_children():
		_tile_row.remove_child(child)
		child.queue_free()

	var count := round_.hand.tiles.size()
	var win_index := -1
	if round_.state == MahjongRound.State.WON and round_.winning_tile >= 0 and not round_.hand.has_drawn():
		win_index = round_.hand.tiles.find(round_.winning_tile)
	for index in count:
		_tile_row.add_child(_make_tile(index, round_.hand.tiles[index], false, index == win_index))

	if round_.hand.has_drawn():
		_add_gap(20)
		var drawn := _make_tile(count, round_.hand.drawn_tile, true)
		_tile_row.add_child(drawn)
		# 刚摸进来的那张要有入场动画，但要避免每次刷新都重播
		var showing_draw := round_.state == MahjongRound.State.DISCARDING \
			or round_.state == MahjongRound.State.WON
		if showing_draw and _draw_animated_for != round_.draw_serial:
			_draw_animated_for = round_.draw_serial
			drawn.play_draw()
			Sfx.play("draw")

	# 无条件重建：副露可能在上一关还存在，这一关已经清空了，
	# 不重建的话旧牌会留在画面上。
	_rebuild_melds()


func _rebuild_melds() -> void:
	for child in _meld_row.get_children():
		_meld_row.remove_child(child)
		child.queue_free()
	var first := true
	for meld in round_.melds:
		first = false
		for i in round_.meld_tile_count(meld):
			_meld_row.add_child(_make_meld_tile(meld["kind"], meld.get("concealed", false)))


func _add_gap(width: int) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(width, 1)
	_tile_row.add_child(gap)


func _make_tile(index: int, kind: int, drawn: bool, highlight: bool = false) -> TileWidget:
	var widget := TileWidget.new()
	widget.setup(kind, drawn)
	widget.set_hinted(_hint_discards.has(kind))
	widget.set_selected(highlight or (_has_selection and _selected_index == index))
	widget.pressed.connect(_on_tile_pressed.bind(index))
	return widget


func _make_meld_tile(kind: int, concealed: bool = false) -> TileWidget:
	var widget := TileWidget.new()
	widget.setup(kind, false, false, true)
	widget.set_tile_size(MELD_TILE)
	widget.set_concealed(concealed)
	widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return widget


func _update_hint() -> void:
	## 手牌下面只有听牌提示这一行，没听牌的时候整行收起。
	var hint := round_.tenpai_hint()
	_hint_label.text = hint
	_hint_label.visible = hint != ""

# ---------------------------------------------------------------- 调试

func _setup_debug_shot() -> void:
	var args := OS.get_cmdline_user_args()
	if "--rig" in args:
		# 听牌很多的牌，检查提示文字很长时排版会不会乱
		round_.hand.reset([0, 8, 9, 17, 18, 26, 27, 28, 29, 30, 31, 32, 33])
		_debug_skip_first_tour()
	elif "--ron" in args:
		# 手里听完，电脑第一张就打出来
		round_.hand.reset([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 27])
		_debug_skip_first_tour()
		round_.wall.stack_next(4, 0)
		round_.wall.stack_next(27, 1)
		round_.draw_tile()
		round_.discard(round_.hand.tiles.size())
		round_.opponent_discard_once()
	elif "--win" in args:
		# 造一个自摸胡牌的画面
		round_.hand.reset([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 27])
		_debug_skip_first_tour()
		round_.wall.stack_next(27, 0)
		round_.draw_tile()
	elif "--tenho" in args:
		# 天胡：庄家起手 14 张直接成牌
		round_.start(1, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 27, 27])
	elif "--pong" in args:
		# 手里一对一万，电脑第一张就打一万
		round_.hand.reset([0, 0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 29, 31])
		_debug_skip_first_tour()
		round_.wall.stack_next(2, 0)
		round_.wall.stack_next(0, 1)
		round_.draw_tile()
		round_.discard(round_.hand.tiles.size())
		round_.opponent_discard_once()
	elif "--ponged" in args:
		# 已经碰下了一副，看副露怎么显示
		round_.hand.reset([0, 0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 29, 31])
		_debug_skip_first_tour()
		round_.wall.stack_next(2, 0)
		round_.wall.stack_next(0, 1)
		round_.draw_tile()
		round_.discard(round_.hand.tiles.size())
		round_.opponent_discard_once()
		round_.declare_pong()
	elif "--kong" in args or "--konged" in args:
		# 手里三张一万，电脑第一张就打一万 → 可以杠
		round_.hand.reset([0, 0, 0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 29])
		_debug_skip_first_tour()
		round_.wall.stack_next(2, 0)
		round_.wall.stack_next(0, 1)
		round_.wall.stack_next(26, 2)
		round_.draw_tile()
		round_.discard(round_.hand.tiles.size())
		round_.opponent_discard_once()
		if "--konged" in args:
			round_.declare_kong()
	elif "--ankong" in args or "--ankonged" in args:
		# 手里三张一万，摸到第四张 → 可以暗杠
		round_.hand.reset([0, 0, 0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 29])
		_debug_skip_first_tour()
		round_.wall.stack_next(0, 0)
		round_.wall.stack_next(26, 1)
		round_.draw_tile()
		if "--ankonged" in args:
			round_.declare_concealed_kong()
	elif "--turn" in args:
		# 走完一整轮：摸牌 → 打牌 → 电脑逐张出牌
		_debug_play_one_tour()
		round_.run_opponent_turn()
	elif "--ai" in args:
		# 停在电脑出牌的过程中
		_debug_skip_first_tour()
		round_.draw_tile()
		_do_discard(round_.hand.tiles.size())
	elif "--mid" in args:
		# 快进几轮，把四家牌河填起来，方便检查方向和排列
		for i in 6:
			if round_.is_over():
				break
			_debug_play_one_tour()
			round_.run_opponent_turn()
	elif "--clear" in args or "--clear2" in args or "--shop" in args:
		# 一直打到本关达标，看过关画面
		while not round_.is_over():
			_debug_play_one_tour()
			if round_.state == MahjongRound.State.AI_TURN:
				round_.run_opponent_turn()
		if "--shop" in args:
			Settings.coins = 30  # 调试用：给点银两，方便看购买键
			_on_settle_pressed()  # 点「结算」翻到商店
		elif "--clear2" in args:
			_on_restart_pressed()  # 点「下一关」
	elif "--clear3" in args:
		# 复现「打出的那张刚好达标」：走界面真实的打出流程（会经过电脑回合收尾）
		round_.score = 90
		round_.hand.reset([0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 28, 29, 30, 31])
		_do_discard(0)
	elif "--clear4" in args:
		# 第一巡就打到达标，看剩余巡奖励
		round_.score = 90
		round_.hand.reset([0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 28, 29, 30, 31])
		_do_discard(0)
	elif "--lose" in args:
		# 在第 2 关直接推到最后一巡再打，模拟「巡数用完没达标」
		level = 2
		_start_new_round()
		round_.tour = round_.total_tours
		_do_discard(0)
	elif "--melds" in args:
		# 两副副露，检查紧靠之后还分不分得清
		round_.melds.append({"kind": 0, "kong": false})
		round_.melds.append({"kind": 22, "kong": true, "concealed": true})
	elif "--hint" in args:
		# 手里有「打掉就能听牌」的选择，看红描边
		round_.hand.reset([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 9, 22, 23])
		_debug_skip_first_tour()
		round_.wall.stack_next(22, 0)  # 摸到五条
		round_.draw_tile()
	elif "--combo" in args:
		# 买了桃花：连打两次刚摸到的牌，看连击显示
		round_.flowers.assign(["combo"])
		_debug_skip_first_tour()
		round_.draw_tile()
		round_.discard(round_.hand.tiles.size())
		round_.run_opponent_turn()
		round_.draw_tile()
	elif "--draw" in args:
		_debug_skip_first_tour()
		round_.draw_tile()
	# 有动画正在播的模式不要再刷新，否则刚建好的牌会被重建、动画白做
	var keeps_animation := "--draw" in args or "--konged" in args \
		or "--ankonged" in args or "--ai" in args
	if not keeps_animation:
		_refresh()
	if "--hover" in args:
		# 放在 _refresh 之后，不然刚建好的牌又被重建掉了
		var tiles := _tile_row.get_children()
		if tiles.size() > 2 and tiles[2] is TileWidget:
			tiles[2].preview_hover(true)


func _debug_skip_first_tour() -> void:
	## 调试用：把局面推到「第二巡、可以摸牌」，不动牌墙，方便摆各种画面
	round_.tour = 2
	round_.state = MahjongRound.State.READY


func _debug_play_one_tour() -> void:
	## 调试用：按当前状态走完玩家这一半（该摸就摸，该打就打）
	if round_.state == MahjongRound.State.READY:
		round_.draw_tile()
	if round_.state == MahjongRound.State.DISCARDING:
		if round_.hand.has_drawn():
			round_.discard(round_.hand.tiles.size())
		else:
			round_.discard(round_.hand.tiles.size() - 1)


func _capture_and_quit() -> void:
	## 调试用：godot --path . -- --shot 会把界面截图存到 res://.dev/screenshot.png
	if "--deal" in OS.get_cmdline_user_args():
		# _setup_debug_shot 会重建手牌，这里重新放一次再停在动画中间
		_play_deal_animation()
		await get_tree().create_timer(1.2).timeout
	if "--ai" in OS.get_cmdline_user_args():
		# 电脑第一张牌在 0.45 秒时落下，停在这一下中间
		await get_tree().create_timer(0.52).timeout
	if "--lose" in OS.get_cmdline_user_args():
		# 等电脑把最后一巡的三张出完，触发失败结算
		await get_tree().create_timer(2.2).timeout
		if "--again" in OS.get_cmdline_user_args():
			_on_restart_pressed()  # 点「重试本关」
			await get_tree().create_timer(0.4).timeout
	# 想抓动画中间帧的调试模式，少等几帧
	var frames := 3 if "--draw" in OS.get_cmdline_user_args() else 4
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var dir := "res://.dev"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	image.save_png(dir + "/screenshot.png")
	print("screenshot saved to ", dir + "/screenshot.png")
	get_tree().quit()
