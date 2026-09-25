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
## 对家牌河贴顶的留白
const ACROSS_POOL_TOP := 8.0
## 牌河里的牌比手牌小一圈，四家的牌河才摆得下
const POOL_TILE := Vector2(26, 37)
## 听牌提示那一行的高度：一开始不显示，但位置要一直占着，免得出现的时候版面跳
const HINT_SLOT_HEIGHT := 30.0
## 版面尺寸：左右边距、牌桌和分数牌之间的距离、分数牌宽度
## （副露并到手牌那一行之后，分数牌收窄了一点，把位置让给牌）
const PANEL_MARGIN := 28.0
const TABLE_SEPARATION := 18.0
const SCOREBOARD_WIDTH := 210.0
## 手牌之间的缝、摸到的那张和手牌之间的缝、手牌和副露之间的缝
const TILE_GAP := 4.0
const DRAWN_GAP := 20.0
const MELD_GAP := 18.0
## 牌桌最上面那行「买到的花牌」：跟手牌一样大，
## 高度一直占着（哪怕一张都没买），这样买第一张花牌时版面不会跳
const FLOWER_TILE := TileWidget.TILE_SIZE
const FLOWER_STRIP_HEIGHT := 100.0

# ---- 商店里的悬停气泡（美术在 assets/ui/itemPopup.png，2048×2048 透明 PNG）----
const UI_ITEM_POPUP := "res://assets/ui/itemPopup.png"
const UI_PRICE_PLATE := "res://assets/ui/priceBackground.png"
const UI_ITEM_CARD := "res://assets/ui/itemBackground.png"
const UI_SCORE_BOARD := "res://assets/ui/score.png"
const UI_SHOP_WINDOW := "res://assets/ui/shopBackground.png"
const UI_NEXT_BUTTON := "res://assets/ui/nextButton.png"
const UI_DELETE_BUTTON := "res://assets/ui/delebutton.png"
const UI_REFRESH_BUTTON := "res://assets/ui/refreshButton.png"
## 商店底下那排两个按钮的尺寸
const NEXT_BUTTON_SIZE := Vector2(250.0, 40.0)
const DELETE_BUTTON_SIZE := Vector2(84.0, 52.0)
## 刷新按钮（挂在窗框右侧屋檐下）：图自带一块名牌，价格写在那里
const REFRESH_BUTTON_SIZE := Vector2(84.0, 84.0)
## 价格写在图自带的名牌上：框比名牌高一点，字才不会被裁掉下沿；
## 竖直位置比名牌中心略高（上移过）
const REFRESH_PLAQUE := Rect2(0.30, 0.60, 0.40, 0.20)
## 刷新按钮相对「宣纸右上角」的微调（x 正 = 右移，y 负 = 上移）
const REFRESH_OFFSET := Vector2(25.0, -21.0)

# ---- 删牌（构筑的核心）：把牌库铺成网格，选若干张永久删掉 ----
const DELETE_GRID_TILE := Vector2(28.0, 39.0)
const DELETE_COLUMNS := 15      # 一行摆多少张
const DELETE_LIMIT := 4         # 每次进商店最多删几张
const DELETE_MIN_DECK := 8      # 牌库至少留这么多张，免得摸不出牌
## 窗框里那块宣纸占整张图的比例（量出来的，货架摆在这个范围里）
const SHOP_PAPER := Rect2(0.159, 0.164, 0.686, 0.716)
## 得分飘窗：木牌挂在屏幕上方，底数和倍率分开写
const SCORE_BOARD_SIZE := Vector2(360.0, 117.0)
const SCORE_FONT_SIZE := 40      # 底数 / 乘号 / 倍率共用一个字号
## 牌桌最上面那行是买到的花牌（含计分时冒出来的字样），飘分板排在它下面，
## 免得演出的时候把花牌盖住
const SCORE_POPUP_TOP := 178.0
## 进场时从多高的地方滑下来
const SCORE_POPUP_DROP := 44.0
const BOARD_INK := Color(0.26, 0.15, 0.07)
const BOARD_RED := Color(0.64, 0.18, 0.09)
## 计分时花牌的动画（小丑牌那种反馈）：花牌跳一下、底下冒出「+1 倍率」，
## 全部冒完之后飘分板才出来
const GAIN_TEXT_SIZE := 18              # 「+10 底分 / +1 倍率」这类字样的字号（界面体）
## 多朵花之间的间隔：留够一次数字滚动（0.22 秒）的时间，不然两笔加成会挤在一起
const FLOWER_FX_STEP := 0.3
const FLOWER_FX_TAIL := 0.45            # 最后一朵花跳完到收起飘分板的停顿
const FLOWER_FX_RISE := 12.0            # 字样往上飘的距离（飘太多会叠到花牌上）
const FLOWER_FX_HOLD := 0.18            # 字样先冒出来、停留一小会儿
const FLOWER_FX_FADE := 0.55            # 字样往上飘着淡出的时间
## 碰 / 杠 / 胡：一张一张牌冒「+N」的节奏。牌多的时候每一步快一点，
## 整段控制在 0.9 秒左右，不至于等太久
const TILE_GAIN_TOTAL := 0.9
const TILE_GAIN_STEP_MIN := 0.05
const TILE_GAIN_STEP_MAX := 0.16
const TILE_GAIN_TAIL := 0.3             # 最后一张加完，等数字滚到位
const TILE_GAIN_RISE := 16.0            # 牌上方那行字往上飘的距离
## 飘分板的节奏：滑下来用 SCORE_POPUP_IN，统计完停 SCORE_POPUP_HOLD 再淡出。
## 花牌加成的数字滚动用 SCORE_ROLL_TIME
const SCORE_POPUP_IN := 0.24
const SCORE_POPUP_HOLD := 0.8
const SCORE_ROLL_TIME := 0.22
## 调试截图：--fx 停在计分演出的哪一刻（开局那几帧很慢，量出来大约 0.5 秒时正滚底分）
const FX_SHOT_WAIT := 0.75
## 商品卡片的实际图形（裁掉透明留白）。卡片尺寸按这张图的比例来，整张贴不打九宫格，
## 免得角上的折角被拉伸。
const CARD_REGION := Rect2(470.0, 235.0, 1108.0, 1572.0)
## 卡片比价格牌窄一点，价格牌就会从卡片两侧探出去（参考图就是这样）
const CARD_SIZE := Vector2(132.0, 196.0)
## 卡片里那张插画：花牌用牌面本身，道具用麻将牌当图标
const CARD_ART := Vector2(80.0, 107.0)
const CARD_ICON := Vector2(74.0, 101.0)
## 卡片里内容的边距：左右几乎贴边、上面留一点、下面不留（价格牌要盖住卡片底边）
const CARD_SIDE_MARGIN := 2
const CARD_TOP_MARGIN := 10
const CARD_BOTTOM_OVERLAP := 5
## 价格牌（招财进宝那张）：裁掉透明留白，价格写在金币右边的绿底上
const PLATE_REGION := Rect2(13.0, 649.0, 2015.0, 675.0)
const PLATE_SIZE := Vector2(148.0, 50.0)
## 价钱写在金币右边那截绿底上（左右都是占牌宽的比例）
const PLATE_TEXT_LEFT := 0.36
const PLATE_TEXT_RIGHT := 0.90
## 气泡在画布里的实际位置、内胆（能写字的地方）占气泡的比例
const POPUP_REGION := Rect2(85.0, 266.0, 1879.0, 1511.0)
const POPUP_TEXT := Rect2(0.044, 0.060, 0.912, 0.862)
const POPUP_SIZE := Vector2(150.0, 121.0)
const POPUP_TAIL := 0.08     # 下面尖角占气泡高度的比例，气泡要压住卡片一点点
## 米色内胆上的字用深色
const INK_DARK := Color(0.20, 0.14, 0.09)
const INK_MID := Color(0.44, 0.34, 0.23)
## 按钮在屏幕中线之上再抬这么高，跟自己的牌河拉开距离
const ACTION_RAISE := 24.0

var round_: MahjongRound
var ai_discard_delay: float = AI_DISCARD_DELAY  # 测试里会调成 0
var level: int = 1              # 当前第几关
var _selected_index: int = -1
var _has_selection: bool = false
var _ai_running: bool = false
var _draw_animated_for: int = -1  # 已经播过入场动画的那次摸牌

## 本局的牌库：删牌删掉的牌永久消失、跨关继承（重开一局才重置成 136 张）
var _deck: Array[int] = []
var _delete_overlay: Control
var _delete_window: Control
var _delete_grid: GridContainer
var _delete_title: Label
var _delete_confirm: Button
var _delete_cancel: Button
var _delete_tiles: Array[int] = []        # 弹窗里铺出来的牌（牌库排序后的快照）
var _delete_widgets: Array = []
var _delete_selection: Array[int] = []
var _delete_used: bool = false            # 这次进商店删过了没
var _delete_dim: ColorRect
var _delete_tween: Tween

var _level_value: Label
var _wall_value: Label
var _tour_value: Label
var _remain_value: Label
var _target_value: Label
var _score_value: Label
var _tile_row: HBoxContainer
var _row_scale: float = 1.0     # 手牌 + 副露这一行放不下时整体缩一点
var _flower_row: HBoxContainer
var _hint_label: Label
var _action_row: HBoxContainer
var _center: Control
var _my_pool: DiscardPool
var _across_pool: DiscardPool
var _left_pool: DiscardPool
var _right_pool: DiscardPool
var _discard_button: Button
var _ron_button: Button
var _pong_button: Button
var _kong_button: Button
var _concealed_kong_button: Button
var _swap_button: Button
var _swap_confirm_button: Button
var _swap_cancel_button: Button
var _pass_button: Button
var _settle_panel: PanelContainer
var _settle_title: Label
var _settle_score: Label
var _settle_target: Label
var _settle_coin: Label
var _settle_flower_bonus: Label
var _settle_total: Label
var _settle_coin_row: Control
var _settle_flower_row: Control
var _settle_total_row: Control
var _settle_tours: Label
var _settle_score_row: Control
var _settle_target_row: Control
var _settle_tours_row: Control
var _settle_tour_bonus: Label
var _settle_tour_bonus_row: Control
var _settle_button: Button
var _coin_value: Label
var _settle_page: VBoxContainer
var _shop_page: VBoxContainer
var _shop_overlay: Control
var _shop_window: Control    # 窗框 + 货架，进场时整块从下往上滑
var _shop_frame: TextureRect
var _shop_dim: ColorRect
var _shop_tween: Tween
var _shop_slots: Array = []
var _flower_slots: Array = []
var _item_popup: Control
var _popup_body: Label
var _popup_token: int = 0
var _score_popup: Control
var _score_board: Control
var _score_popup_base: Label
var _score_popup_mult: Label
var _score_popup_tween: Tween
var _score_shown_serial: int = 0
var _flower_widgets: Array = []        # 牌桌上摆出来的花牌（跟 _owned_flowers 一一对应）
var _flower_built: Array[String] = []  # 已经摆出来的花牌名单，没变就不重建
var _row_widgets: Array = []           # 手牌那一行的牌面（手牌 + 刚摸的 + 副露，按摆放顺序）
var _score_sequence: int = 0           # 计分动画的编号：又得一次分就把上一次的动画作废
var _score_sequence_done: int = 0      # 已经演完的那个编号（跟上面相等就是没在演）
var _score_base_roll: Tween            # 底分滚动（花牌加底分的时候）
var _score_mult_roll: Tween            # 倍率滚动
var _score_base_pulse: Tween           # 数字变化时蹦一下
var _score_mult_pulse: Tween
var _shop_next_button: Button
var _shop_delete_button: Button
var _shop_refresh_button: Button
var _shop_refresh_price: Label
var _shop_refresh_holder: Control
var _refresh_cost: int = 1     # 刷新价钱：每次进商店从 1 钱起，每刷一次 +1
var _run_bonus := {"wan": 0, "tong": 0, "tiao": 0, "honor": 0}
var _owned_flowers: Array[String] = []    # 本局买到的花牌（按图片名，花牌只卖一次）
var _settled_round: MahjongRound = null  # 已经结过算的那一局，防止重复发铜钱
var _hint_discards: Array = []            # 这一手打出去能听牌的牌
var _swap_mode: bool = false              # 紫罗兰：正在挑要弃掉的牌
var _swap_selection: Array[int] = []      # 挑中的手牌下标


func _ready() -> void:
	Settings.reset_coins()  # 金币每次游戏从 0 开始算
	_reset_deck()           # 牌库：本局从 136 张起（删牌是局内的构筑）
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
		margin.add_theme_constant_override("margin_%s" % side, int(PANEL_MARGIN))
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	# ---- 牌桌 + 右侧分数牌 ----
	var main_row := HBoxContainer.new()
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", int(TABLE_SEPARATION))
	column.add_child(main_row)

	# 左列：牌桌 + 自己的手牌（手牌跟牌桌同宽，不会伸到分数牌下面）
	var play_column := VBoxContainer.new()
	play_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play_column.add_theme_constant_override("separation", 12)
	main_row.add_child(play_column)

	# 牌桌最上面一行：本局买到的花牌，就摆在这儿
	var flower_slot := Control.new()
	flower_slot.custom_minimum_size = Vector2(0.0, FLOWER_STRIP_HEIGHT)
	flower_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_column.add_child(flower_slot)
	var flower_wrap := CenterContainer.new()
	flower_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	flower_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flower_slot.add_child(flower_wrap)
	_flower_row = HBoxContainer.new()
	_flower_row.add_theme_constant_override("separation", 6)
	_flower_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flower_wrap.add_child(_flower_row)

	# 牌桌：只留四家的牌河，中央自己算坐标摆牌河和按钮
	var table := HBoxContainer.new()
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	table.add_theme_constant_override("separation", 14)
	play_column.add_child(table)

	# 中央区域自己算坐标：四家牌河要按座位方向摆，容器排不出来
	_center = Control.new()
	_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_center.resized.connect(_layout_table)
	table.add_child(_center)

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

	_discard_button = _make_action_button("打出", _on_discard_pressed, ACTION_GOLD, ACTION_INK)
	_action_row.add_child(_discard_button)
	# 紫罗兰：每关开局换牌（按钮平时都藏着，能用的时候才出现）
	_swap_button = _make_action_button("换牌", _on_swap_pressed, ACTION_SLATE, ACTION_LIGHT)
	_action_row.add_child(_swap_button)
	_swap_confirm_button = _make_action_button("确认换牌", _on_swap_confirm_pressed,
		ACTION_GOLD, ACTION_INK)
	_action_row.add_child(_swap_confirm_button)
	_swap_cancel_button = _make_action_button("取消", _on_swap_cancel_pressed,
		ACTION_SLATE, ACTION_LIGHT)
	_action_row.add_child(_swap_cancel_button)
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
	main_row.add_child(_build_scoreboard())
	_build_settlement()
	_build_shop_overlay()
	_build_delete_overlay()

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
	_tile_row.add_theme_constant_override("separation", int(TILE_GAP))
	row_wrap.add_child(_tile_row)

	# 悬停气泡要盖在所有东西最上面，所以放在最后建
	_build_item_popup()
	_build_score_popup()


func _build_score_popup() -> void:
	## 得分飘窗：打一张牌、碰一下、胡一把，都在屏幕上方弹一下再消失
	_score_popup = Control.new()
	_score_popup.custom_minimum_size = SCORE_BOARD_SIZE
	_score_popup.size = SCORE_BOARD_SIZE
	_score_popup.pivot_offset = SCORE_BOARD_SIZE * 0.5
	_score_popup.visible = false
	_score_popup.z_index = 9
	_score_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_score_popup)

	# 牌子本体单独一层：外壳负责「挂在屏幕哪个位置」，
	# 本体负责「从上面滑下来」，两边互不打架
	_score_board = Control.new()
	_score_board.custom_minimum_size = SCORE_BOARD_SIZE
	_score_board.size = SCORE_BOARD_SIZE
	_score_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_popup.add_child(_score_board)

	var board := TextureRect.new()
	board.texture = load(UI_SCORE_BOARD)
	_crisp(board)
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_board.add_child(board)

	# 底数和倍率分开写：10 ／ 30 × 2 ／ 140 × 10
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_board.add_child(row)

	# 底数、乘号、倍率用同一个字号，看着才是一整句
	_score_popup_base = _make_label("", SCORE_FONT_SIZE, BOARD_INK)
	_score_popup_base.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_score_popup_base)

	_score_popup_mult = _make_label("", SCORE_FONT_SIZE, BOARD_RED)
	_score_popup_mult.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_score_popup_mult)


func _play_score_sequence(start_base: int, start_multiplier: int,
		base: int, multiplier: int, effects: Array,
		tiles: Array = [], kind: String = "discard") -> void:
	## 得分的整套演出（小丑牌那套节奏）：
	##   1. 飘分板先滑下来，亮出「花牌生效之前」的数字（比如 10）
	##   2. 碰 / 杠 / 胡：攒分的那几张牌从左到右一张张冒「+10」，
	##      底分跟着 0 → 10 → 20 → 30… 滚上去
	##   3. 一张花牌一张花牌地点：牌跳一下、冒出「+N 倍率」，
	##      飘分板上的数字同时滚到加上去之后的值（比如 10 → 20）
	##   4. 全部点完，停一会儿再收起飘分板
	## 又一次得分会 ++_score_sequence，把上一次没演完的作废。
	_score_sequence += 1
	var token := _score_sequence
	# 打出的那张不算「逐张攒分」，只有碰 / 杠 / 胡才演
	var has_tiles := not tiles.is_empty() and kind != "discard"
	if effects.is_empty() and not has_tiles:
		# 没什么要演的：滑进来 → 停一会儿 → 淡出，一条时间线走完
		_show_score_popup(start_base, start_multiplier, SCORE_POPUP_HOLD)
		_score_sequence_done = token
		return
	# 有东西要演：先只负责把牌子滑下来，什么时候收由演完的时候说了算
	_show_score_popup(start_base, start_multiplier)
	# 花牌和手牌都是这一帧刚摆好的，容器的位置还没算出来——先等版面排完再量坐标，
	# 不然那些「+10 / +1 倍率」会冒到屏幕左上角去
	await get_tree().process_frame
	await get_tree().process_frame
	if token != _score_sequence or not is_inside_tree():
		return
	# 等牌子滑到位再开始一个个加
	await get_tree().create_timer(SCORE_POPUP_IN).timeout
	var shown_base := start_base
	var shown_multiplier := start_multiplier
	# 第一步：碰 / 杠 / 胡的那些牌，从左到右一张张冒「+N」，底分跟着涨
	if has_tiles:
		var widgets := _tiles_to_widgets(tiles.size(), kind)
		var step := clampf(TILE_GAIN_TOTAL / float(tiles.size()),
			TILE_GAIN_STEP_MIN, TILE_GAIN_STEP_MAX)
		for i in tiles.size():
			if token != _score_sequence or not is_inside_tree():
				return
			var gain := round_.tile_score(tiles[i])
			if i < widgets.size():
				var widget: Control = widgets[i]
				_spawn_gain_label("+%d" % gain, widget, true, TILE_GAIN_RISE)
			_roll_score_value(shown_base, shown_base + gain, false)
			shown_base += gain
			if i >= tiles.size() - 1:
				break
			await get_tree().create_timer(step).timeout
		# 等最后一张的数字滚到位
		await get_tree().create_timer(TILE_GAIN_TAIL).timeout
		if token != _score_sequence or not is_inside_tree():
			return
	# 第二步：花牌，严格按牌桌上从左到右的顺序演：谁摆在左边，谁先跳、先加
	var ordered := _ordered_flower_effects(effects)
	for i in ordered.size():
		if token != _score_sequence or not is_inside_tree():
			return
		var effect: Dictionary = ordered[i]
		_flash_flower_effect(effect)
		var delta := int(effect.get("delta", 0))
		if str(effect.get("kind", "mult")) == "base":
			_roll_score_value(shown_base, shown_base + delta, false)
			shown_base += delta
		elif delta != 0:
			_roll_score_value(shown_multiplier, shown_multiplier + delta, true)
			shown_multiplier += delta
		if i >= ordered.size() - 1:
			break
		await get_tree().create_timer(FLOWER_FX_STEP).timeout
	# 等最后一张花牌跳完、数字也滚到位
	await get_tree().create_timer(FLOWER_FX_TAIL).timeout
	if token != _score_sequence or not is_inside_tree():
		return
	# 收尾按算好的最终值写死，免得滚动中间差一点点
	_write_score_value(_score_popup_base, base, false)
	_write_score_value(_score_popup_mult, multiplier, true)
	_dismiss_score_popup()
	_score_sequence_done = token


func _score_fx_running() -> bool:
	## 计分演出还在演吗（结算板要等它演完再出来）
	return _score_sequence_done != _score_sequence


func _tiles_to_widgets(count: int, kind: String) -> Array:
	## 得分的这几张牌，对应桌面上哪几个牌面：
	##   碰 / 杠：副露排在那一行的最后面，取末尾这几张
	##   胡牌：整行从手牌一路到副露，顺序跟 last_score_tiles 完全一致
	var out: Array = []
	if count <= 0 or _row_widgets.is_empty():
		return out
	var start := maxi(0, _row_widgets.size() - count) if kind == "meld" else 0
	var stop := mini(_row_widgets.size(), start + count)
	for i in range(start, stop):
		var widget = _row_widgets[i]
		if is_instance_valid(widget) and widget.is_inside_tree():
			out.append(widget)
	return out


func _ordered_flower_effects(effects: Array) -> Array:
	## 花牌效果按「牌桌上从左到右」排序：牌桌上摆的顺序就是买到的顺序
	## （core 那边是按底分、倍率这种逻辑顺序记的，这里只负责演出顺序）
	var ordered: Array = effects.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _flower_table_index(str(a.get("key", ""))) \
			< _flower_table_index(str(b.get("key", ""))))
	return ordered


func _flower_table_index(key: String) -> int:
	## 这张花牌在牌桌上排第几（从左数、0 起）；找不到就排到最后
	if key == "":
		return 9999
	for i in _owned_flowers.size():
		if FlowerTiles.effect_key(_owned_flowers[i]) == key:
			return i
	return 9999


func _roll_score_value(from: int, to: int, is_multiplier: bool) -> void:
	## 飘分板上的数字滚到新值——「花牌加底分 / 加倍率」的变化过程就靠它演
	if _score_popup == null or not _score_popup.visible:
		return
	var label: Label = _score_popup_mult if is_multiplier else _score_popup_base
	if label == null:
		return
	var previous: Tween = _score_mult_roll if is_multiplier else _score_base_roll
	if previous != null and previous.is_valid():
		previous.kill()
	if from == to:
		_write_score_value(label, to, is_multiplier)
		_pulse_score_label(label, is_multiplier)
		return
	# 倍率从 1 往上滚的时候先把「× N」露出来，滚动过程中就看得见它在涨
	if is_multiplier and to > 1:
		label.visible = true
	var roll := create_tween()
	roll.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	roll.tween_method(func(value: float) -> void:
		_write_score_value(label, int(roundf(value)), is_multiplier), float(from), float(to),
		SCORE_ROLL_TIME)
	roll.tween_callback(func() -> void:
		_write_score_value(label, to, is_multiplier))
	if is_multiplier:
		_score_mult_roll = roll
	else:
		_score_base_roll = roll
	_pulse_score_label(label, is_multiplier)


func _write_score_value(label: Label, value: int, is_multiplier: bool) -> void:
	if label == null:
		return
	if is_multiplier:
		label.text = "× %d" % value
		label.visible = value > 1
	else:
		label.text = "%d" % value


func _pulse_score_label(label: Label, is_multiplier: bool) -> void:
	## 数字变了就轻轻蹦一下，跟花牌跳的是一个节奏
	if label == null:
		return
	var previous: Tween = _score_mult_pulse if is_multiplier else _score_base_pulse
	if previous != null and previous.is_valid():
		previous.kill()
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(1.25, 1.25)
	var pulse := create_tween()
	pulse.tween_property(label, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_multiplier:
		_score_mult_pulse = pulse
	else:
		_score_base_pulse = pulse


func _flash_flower_effect(effect: Dictionary) -> void:
	## 一朵花牌起了作用：牌自己跳一下，底下冒出「+1 倍率」这样的字，字往上飘着淡出
	var tile := _flower_widget_for(str(effect.get("key", "")))
	if tile == null:
		return
	tile.play_jump()
	_spawn_gain_label(str(effect.get("text", "")), tile, false, FLOWER_FX_RISE)


func _spawn_gain_label(text: String, widget: Control, above: bool, rise: float) -> void:
	## 牌上（above）或牌下冒出一行「+10 / +1 倍率」这样的字，往上飘着淡出。
	## 字体用界面体——加底分、加倍率的字要一眼看懂，不用书法体。
	if text == "" or widget == null or not is_instance_valid(widget):
		return
	if not widget.is_inside_tree():
		return
	var label := UiStyle.label(text, GAIN_TEXT_SIZE, GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", BOARD_INK)
	label.z_index = 30
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.size = label.get_minimum_size()
	var anchor := widget.global_position - global_position + widget.size * 0.5
	var top := 0.0
	if above:
		# 手牌在屏幕最下面，字只能往牌上方冒
		top = anchor.y - widget.size.y * 0.5 - label.size.y - 2.0
	else:
		# 花牌在屏幕最上面，字排在「花牌那一整条」的下方：牌自己会往上跳，
		# 字要是贴着牌底，跳起来的时候就叠到牌面上了
		top = anchor.y + widget.size.y * 0.5
		var strip := _flower_row.get_parent() as Control
		if strip != null and strip.is_inside_tree():
			top = maxf(top, strip.global_position.y - global_position.y + strip.size.y)
		top += 2.0
	var start := Vector2(anchor.x - label.size.x * 0.5, top)
	label.position = start
	label.modulate.a = 0.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, 0.12)
	tween.tween_property(label, "position:y", start.y - rise * 0.3, FLOWER_FX_HOLD) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_property(label, "position:y", start.y - rise, FLOWER_FX_FADE) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, FLOWER_FX_FADE)
	tween.tween_callback(func() -> void:
		if is_instance_valid(label):
			label.queue_free())


func _flower_widget_for(key: String) -> TileWidget:
	## 按效果代号找牌桌上是哪一张花牌（同一种效果只会买一张）
	if key == "":
		return null
	for i in _owned_flowers.size():
		if i >= _flower_widgets.size():
			break
		if FlowerTiles.effect_key(_owned_flowers[i]) != key:
			continue
		var tile = _flower_widgets[i]
		if is_instance_valid(tile) and tile.is_inside_tree():
			return tile
	return null


func _show_score_popup(base: int, multiplier: int, hold: float = -1.0) -> void:
	## 飘分板从屏幕上方滑下来落位，亮出「底数 × 倍率」。
	## hold < 0：只演进场，之后由 _play_score_sequence 跟着花牌往上加、演完再收
	## hold ≥ 0：进来之后停 hold 秒自己淡出（没有花牌生效时走这条）
	if _score_popup == null:
		return
	_write_score_value(_score_popup_base, base, false)
	_write_score_value(_score_popup_mult, multiplier, true)
	_score_popup.visible = true
	if _score_popup_tween != null and _score_popup_tween.is_valid():
		_score_popup_tween.kill()
	_layout_score_popup()
	# 从上面滑下来落位：牌子先抬高 44 像素、透明，然后滑到位并显形
	_score_board.position = Vector2(0.0, -SCORE_POPUP_DROP)
	_score_popup.modulate.a = 0.0
	_score_popup_tween = create_tween()
	_score_popup_tween.set_parallel(true)
	_score_popup_tween.tween_property(_score_board, "position", Vector2.ZERO, SCORE_POPUP_IN) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_score_popup_tween.tween_property(_score_popup, "modulate:a", 1.0, 0.16)
	if hold < 0.0:
		return
	# 自己收尾：等进场滑到位再开始计停留时间（同一帧就把进场掐掉的话，
	# 牌子会停在屏幕外、还是全透明的，等于没弹）
	_score_popup_tween.set_parallel(false)
	_score_popup_tween.tween_interval(hold)
	_score_popup_tween.tween_property(_score_popup, "modulate:a", 0.0, 0.3)
	_score_popup_tween.tween_callback(func() -> void:
		_score_popup.visible = false
		_score_board.position = Vector2.ZERO)


func _hide_score_popup() -> void:
	## 直接把飘分板收掉（商店这种整屏弹窗上来的时候用）
	if _score_popup == null:
		return
	if _score_popup_tween != null and _score_popup_tween.is_valid():
		_score_popup_tween.kill()
	_score_popup.visible = false
	_score_board.position = Vector2.ZERO


func _dismiss_score_popup(hold: float = SCORE_POPUP_HOLD) -> void:
	## 统计完停一会儿，再把牌子淡掉收起来
	if _score_popup == null or not _score_popup.visible:
		return
	if _score_popup_tween != null and _score_popup_tween.is_valid():
		_score_popup_tween.kill()
	_score_popup_tween = create_tween()
	_score_popup_tween.tween_interval(hold)
	_score_popup_tween.tween_property(_score_popup, "modulate:a", 0.0, 0.3)
	_score_popup_tween.tween_callback(func() -> void:
		_score_popup.visible = false
		_score_board.position = Vector2.ZERO)


func _layout_score_popup() -> void:
	## 飘窗挂在牌桌正上方的屏幕顶上
	if _score_popup == null or _center == null:
		return
	_score_popup.position = Vector2(
		_center.global_position.x + _center.size.x * 0.5 - _score_popup.size.x * 0.5,
		SCORE_POPUP_TOP)


func _make_pool(facing: float) -> DiscardPool:
	var pool := DiscardPool.new()
	pool.setup(POOL_TILE, facing)
	pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.add_child(pool)
	return pool


func _layout_table() -> void:
	## 中央区域是手动排的：对家牌河贴顶，我的牌河贴底，左右两家牌河贴两侧，
	## 按钮放在中间偏上一点。
	if _center == null:
		return
	var area := _center.size
	if area.x < 40.0 or area.y < 40.0:
		return
	var cx := area.x * 0.5

	var pool_size := _my_pool.size            # 牌河未旋转时的尺寸
	var depth := pool_size.y                  # 牌河朝中心方向的深度
	var across_depth := pool_size.x           # 旋转 90 度后视觉上的深度

	# 对家：贴顶，往中心长
	_across_pool.position = Vector2(cx - pool_size.x * 0.5, ACROSS_POOL_TOP)
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

	# 飘分板挂在牌桌正上方的屏幕顶上（这里跟着一起重算，避免开局时位置还没定下来）
	_layout_score_popup()


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
	panel.custom_minimum_size = Vector2(SCOREBOARD_WIDTH, 0)
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
	_coin_value = _add_score_row(box, "铜钱")
	return panel


## 结算板/商店那块抽屉的高度：多一行「花牌奖励」就要高一点，
## 不然内容顶出去，按钮会被屏幕边缘切掉
const SETTLE_PANEL_H := 590.0
const SETTLE_PANEL_H_FLOWER := 670.0


func _build_settlement() -> void:
	## 过关结算板：从屏幕左侧抽屉式滑出
	const PANEL_W := 440.0
	const PANEL_H := SETTLE_PANEL_H   # 商店去掉标题和铜钱之后，抽屉收回刚好装得下的高度
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
	_settle_flower_bonus = _add_score_row(_settle_page, "花牌奖励", 36)
	_settle_total = _add_score_row(_settle_page, "铜钱总数", 36)
	_settle_tours_row = _settle_tours.get_parent()
	_settle_tour_bonus_row = _settle_tour_bonus.get_parent()
	_settle_coin_row = _settle_coin.get_parent()
	_settle_flower_row = _settle_flower_bonus.get_parent()
	_settle_total_row = _settle_total.get_parent()

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settle_page.add_child(gap)

	_settle_button = _make_action_button("结算", _on_settle_button_pressed, ACTION_GOLD, ACTION_INK,
		Vector2(240, 64))
	_settle_page.add_child(_settle_button)


func _show_settlement(won: bool) -> void:
	const PANEL_W := 440.0
	const TARGET_LEFT := 24.0
	_settle_page.visible = true
	_hide_shop()
	_hide_item_popup()
	var first_time := _settled_round != round_
	_settled_round = round_
	if won:
		var base_reward := LevelTable.clear_reward(round_.level)
		var tour_bonus := round_.remaining_tours()
		# 花牌奖励：目前是牡丹——过关时手里每有一张字牌多给 4 钱
		var flower_bonus := round_.flower_coin_bonus()
		var reward := base_reward + tour_bonus + flower_bonus
		if first_time:
			Settings.add_coins(reward)
		_settle_title.text = "过关！"
		_settle_title.add_theme_color_override("font_color", GOLD)
		# 过关只写铜钱信息：剩余巡数、剩余巡奖励、过关奖励、总数
		_settle_tours.text = "%d 巡" % tour_bonus
		_settle_tour_bonus.text = "+%d" % tour_bonus
		_settle_coin.text = "+%d" % base_reward
		_settle_flower_bonus.text = "+%d" % flower_bonus
		_set_settle_panel_height(SETTLE_PANEL_H_FLOWER if flower_bonus > 0 else SETTLE_PANEL_H)
		_settle_score_row.visible = false
		_settle_target_row.visible = false
		_settle_tours_row.visible = true
		_settle_tour_bonus_row.visible = true
		_settle_coin_row.visible = true
		# 没有花牌给钱就不占这一行，免得结算板白白变长
		_settle_flower_row.visible = flower_bonus > 0
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
		_settle_flower_row.visible = false
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


func _set_settle_panel_height(height: float) -> void:
	## 抽屉是上下居中挂着的，改高度就是改这两个偏移
	if _settle_panel == null:
		return
	_settle_panel.offset_top = -height * 0.5
	_settle_panel.offset_bottom = height * 0.5


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
	page.add_theme_constant_override("separation", 18)

	# 第一行：花牌（图片在 assets/tiles/flowers/ 里）
	var row_one := HBoxContainer.new()
	row_one.alignment = BoxContainer.ALIGNMENT_CENTER
	# 价格牌比卡片宽、会从两侧各探出一点，卡片之间要留够，
	# 让「牌子之间的净空」跟「上下两行的净空」看起来差不多
	row_one.add_theme_constant_override("separation", 30)
	for i in 2:
		var slot := _build_flower_slot(i)
		_flower_slots.append(slot)
		row_one.add_child(slot["root"])
	page.add_child(row_one)

	# 第二行：两件随机道具
	var row_two := HBoxContainer.new()
	row_two.alignment = BoxContainer.ALIGNMENT_CENTER
	row_two.add_theme_constant_override("separation", 30)
	for i in 2:
		var slot := _build_shop_slot(i)
		_shop_slots.append(slot)
		row_two.add_child(slot["root"])
	page.add_child(row_two)

	# 底下这排：左边删除按钮、右边「下一关」条
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(buttons)

	_shop_delete_button = _build_image_button(UI_DELETE_BUTTON, DELETE_BUTTON_SIZE,
		_on_shop_delete_pressed)
	buttons.add_child(_shop_delete_button)

	_shop_next_button = _build_image_button(UI_NEXT_BUTTON, NEXT_BUTTON_SIZE,
		_on_restart_pressed, "下一关")
	buttons.add_child(_shop_next_button)
	return page


func _build_image_button(texture_path: String, target_size: Vector2, handler: Callable,
		label_text: String = "", label_size: int = 26) -> Button:
	## 用一张图当底的按钮：图按原比例铺满（不拉伸），字写在上面
	var button := Button.new()
	button.custom_minimum_size = target_size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(handler)

	var art := TextureRect.new()
	art.texture = load(texture_path)
	_crisp(art)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(art)
	button.set_meta("art", art)

	if label_text != "":
		# 书法体的字，写在图中间
		var text := UiStyle.brush_label(label_text, label_size, INK_DARK)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text.set_anchors_preset(Control.PRESET_FULL_RECT)
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(text)
		button.set_meta("label", text)

	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			art.modulate = Color(1.12, 1.12, 1.12))
	button.mouse_exited.connect(func() -> void:
		art.modulate = Color.WHITE if not button.disabled else Color(0.62, 0.62, 0.62))
	if button.disabled:
		art.modulate = Color(0.62, 0.62, 0.62)
	return button


static func _crisp(node: CanvasItem) -> void:
	## 大图缩小显示（2048 → 几十像素）时得开 mipmap 采样，不然边缘又闪又糊
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _on_shop_delete_pressed() -> void:
	## 删牌：弹窗把牌库铺出来，选几张永久删掉（杀戮尖塔式的构筑）
	_open_delete_popup()


func _build_delete_overlay() -> void:
	## 删牌弹窗：跟商店一样的窗框，里面把牌库铺成网格
	_delete_overlay = Control.new()
	_delete_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_delete_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_delete_overlay.visible = false
	add_child(_delete_overlay)
	_delete_overlay.resized.connect(_layout_delete)

	_delete_dim = ColorRect.new()
	_delete_dim.color = Color(0.0, 0.0, 0.0, 0.55)
	_delete_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_delete_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_delete_overlay.add_child(_delete_dim)

	_delete_window = Control.new()
	_delete_window.set_anchors_preset(Control.PRESET_FULL_RECT)
	_delete_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_delete_overlay.add_child(_delete_window)

	var frame := TextureRect.new()
	frame.texture = load(UI_SHOP_WINDOW)
	_crisp(frame)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_delete_window.add_child(frame)

	var page := VBoxContainer.new()
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", 8)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_delete_window.add_child(page)
	_delete_window.set_meta("page", page)

	_delete_title = UiStyle.brush_label("删牌", 26, INK_DARK)
	_delete_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_delete_title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page.add_child(_delete_title)

	_delete_grid = GridContainer.new()
	_delete_grid.columns = DELETE_COLUMNS
	_delete_grid.add_theme_constant_override("h_separation", 2)
	_delete_grid.add_theme_constant_override("v_separation", 2)
	_delete_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_delete_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(_delete_grid)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(buttons)

	_delete_confirm = _build_image_button(UI_NEXT_BUTTON, Vector2(190, 32),
		_on_delete_confirm_pressed, "删除", 20)
	buttons.add_child(_delete_confirm)

	_delete_cancel = _make_action_button("取消", _close_delete_popup,
		ACTION_SLATE, ACTION_LIGHT, Vector2(100, 36))
	_delete_cancel.add_theme_font_size_override("font_size", 18)
	buttons.add_child(_delete_cancel)


func _layout_delete() -> void:
	if _delete_window == null:
		return
	var page: Control = _delete_window.get_meta("page")
	var view := get_viewport_rect().size
	var side := minf(view.x, view.y)
	var origin := Vector2((view.x - side) * 0.5, (view.y - side) * 0.5)
	page.position = origin + Vector2(side * SHOP_PAPER.position.x, side * SHOP_PAPER.position.y)
	page.size = side * SHOP_PAPER.size


func _allowed_delete_count() -> int:
	## 这一次最多能删几张：既受「一次 4 张」限制，也得给牌库留够底
	return clampi(DELETE_LIMIT, 0, _deck.size() - DELETE_MIN_DECK)


func _open_delete_popup() -> void:
	if _delete_used or _allowed_delete_count() <= 0:
		return
	_delete_tiles = _deck.duplicate()
	_delete_tiles.sort()
	_delete_selection.clear()
	_rebuild_delete_grid()
	_delete_overlay.visible = true
	_layout_delete()
	# 从屏幕下方滑上来（跟商店弹窗一个动作）
	if _delete_tween != null and _delete_tween.is_valid():
		_delete_tween.kill()
	_delete_window.position.y = get_viewport_rect().size.y
	_delete_dim.color.a = 0.0
	_delete_tween = create_tween()
	_delete_tween.set_parallel(true)
	_delete_tween.tween_property(_delete_window, "position:y", 0.0, 0.34) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_delete_tween.tween_property(_delete_dim, "color:a", 0.55, 0.22)


func _close_delete_popup() -> void:
	if _delete_tween != null and _delete_tween.is_valid():
		_delete_tween.kill()
	if _delete_overlay != null:
		_delete_overlay.visible = false
	if _delete_window != null:
		_delete_window.position.y = 0.0
	_delete_selection.clear()


func _rebuild_delete_grid() -> void:
	for child in _delete_grid.get_children():
		_delete_grid.remove_child(child)
		child.queue_free()
	_delete_widgets.clear()
	for index in _delete_tiles.size():
		var tile := TileWidget.new()
		tile.setup(_delete_tiles[index])
		tile.set_tile_size(DELETE_GRID_TILE)
		tile.pressed.connect(_on_delete_tile_pressed.bind(index))
		_delete_grid.add_child(tile)
		_delete_widgets.append(tile)
	_update_delete_ui()


func _update_delete_ui() -> void:
	var allow := _allowed_delete_count()
	for index in _delete_widgets.size():
		var tile: TileWidget = _delete_widgets[index]
		tile.set_selected(_delete_selection.has(index))
	_delete_title.text = "删牌：最多选 %d 张（牌库 %d 张）" % [allow, _deck.size()]
	_delete_confirm.disabled = _delete_selection.is_empty()
	var label: Label = _delete_confirm.get_meta("label")
	label.text = "删除 %d 张" % _delete_selection.size() if not _delete_selection.is_empty() else "删除"


func _on_delete_tile_pressed(index: int) -> void:
	if _delete_selection.has(index):
		_delete_selection.erase(index)
	elif _delete_selection.size() < _allowed_delete_count():
		_delete_selection.append(index)
	else:
		return   # 已经选满了
	Sfx.play("impact")
	_update_delete_ui()


func _on_delete_confirm_pressed() -> void:
	if _delete_selection.is_empty():
		return
	var picked: Array[int] = _delete_selection.duplicate()
	picked.sort()
	# 从后往前删，免得下标错位
	for i in range(picked.size() - 1, -1, -1):
		_deck.remove_at(picked[i])
	_delete_used = true
	Sfx.play("discard")
	_close_delete_popup()
	_update_delete_button()


func _update_delete_button() -> void:
	if _shop_delete_button == null:
		return
	var art: TextureRect = _shop_delete_button.get_meta("art")
	_shop_delete_button.disabled = _delete_used or _allowed_delete_count() <= 0
	art.modulate = Color.WHITE if not _shop_delete_button.disabled else Color(0.62, 0.62, 0.62)


func _slot_panel() -> Control:
	## 商品卡片：底图整张铺（itemBackground），上面摆插画和价格牌。
	## 卡片尺寸就是照这张图的比例定的，整贴不会变形，也就不需要九宫格。
	var panel := Control.new()
	panel.custom_minimum_size = CARD_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var atlas := AtlasTexture.new()
	atlas.atlas = load(UI_ITEM_CARD)
	atlas.region = CARD_REGION
	var bg := TextureRect.new()
	bg.texture = atlas
	_crisp(bg)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bg)

	return panel


func _place_in_card(card: Control, node: Control, node_size: Vector2,
		center_y: float = -1.0) -> void:
	## 卡片里的东西一律按卡片坐标摆：
	## 横向取卡片正中，纵向默认摆在「插画区」正中（卡片顶边到价格牌上沿之间）。
	## 之所以不用容器：卡片比价格牌窄，容器算出来的宽度会把插画挤到一边。
	var area_top := float(CARD_TOP_MARGIN)
	var area_bottom := CARD_SIZE.y - PLATE_SIZE.y + CARD_BOTTOM_OVERLAP
	node.size = node_size
	node.position = Vector2((CARD_SIZE.x - node_size.x) * 0.5,
		center_y if center_y >= 0.0 else area_top + (area_bottom - area_top - node_size.y) * 0.5)
	card.add_child(node)


func _place_price_plate(card: Control, plate: Button) -> void:
	## 价格牌比卡片宽，要按卡片居中、底部压住卡片下沿
	plate.position = Vector2((CARD_SIZE.x - PLATE_SIZE.x) * 0.5,
		CARD_SIZE.y - PLATE_SIZE.y + CARD_BOTTOM_OVERLAP)
	card.add_child(plate)


func _build_flower_slot(index: int) -> Dictionary:
	var panel := _slot_panel()

	# 插画：摆在卡片上半部分的正中
	var tile := TileWidget.new()
	tile.setup_flower("", CARD_ART)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_in_card(panel, tile, CARD_ART)

	# 只有「已满 / 已全部拥有」这类状态才写字，平时不占位置
	var name_label := _make_label("", 13, INK_DARK)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.visible = false
	_place_in_card(panel, name_label, Vector2(CARD_SIZE.x - CARD_SIDE_MARGIN * 2.0, 20.0))

	# 下半：一整条价格牌，点它就是购买
	var price_ui := _build_price_plate(_on_buy_flower_pressed.bind(index))
	_place_price_plate(panel, price_ui["button"])
	# 卡片上不写效果了，鼠标压上去用气泡讲
	_connect_slot_hover(panel, price_ui["button"])
	return {
		"root": panel, "tile": tile, "name": name_label,
		"price": price_ui["label"], "plate": price_ui["plate"],
		"buy": price_ui["button"], "flower": {},
	}


func _build_price_plate(handler: Callable) -> Dictionary:
	## 价格牌：底图是招财进宝那张价格牌，价钱写在金币右边；
	## 整块牌子就是一个按钮，点它＝买下这件东西。
	var button := Button.new()
	button.custom_minimum_size = PLATE_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# 牌子由下面的图片画，按钮自己什么都不画
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(handler)

	var plate := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load(UI_PRICE_PLATE)
	atlas.region = PLATE_REGION
	plate.texture = atlas
	_crisp(plate)
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(plate)

	# 价格用金色写在深绿底上
	var label := _make_label("", 17, GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(PLATE_SIZE.x * PLATE_TEXT_LEFT, 0.0)
	label.size = Vector2(PLATE_SIZE.x * (PLATE_TEXT_RIGHT - PLATE_TEXT_LEFT), PLATE_SIZE.y)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)

	# 鼠标压上来亮一点；买不起（按钮禁用）的时候压暗
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			plate.modulate = Color(1.12, 1.12, 1.12))
	button.mouse_exited.connect(func() -> void:
		plate.modulate = _plate_modulate(button))
	return {"button": button, "label": label, "plate": plate}


static func _plate_modulate(button: Button) -> Color:
	return Color(0.68, 0.68, 0.68) if button.disabled else Color.WHITE


static func _show_slot_text(label: Label, text: String) -> void:
	## 卡片上平时一个字都不写；只有「已满 / 已全部拥有」这类状态才显示一行
	label.text = text
	label.visible = text != ""


func _roll_flowers() -> void:
	## 第一行摆花牌：目录里有几张图就随机抽两张
	var full := _owned_flowers.size() >= FlowerTiles.LIMIT
	var flowers := FlowerTiles.roll(2, null, _owned_flowers)
	for i in _flower_slots.size():
		var slot: Dictionary = _flower_slots[i]
		var tile: TileWidget = slot["tile"]
		var name_label: Label = slot["name"]
		var price: Label = slot["price"]
		var buy: Button = slot["buy"]
		if full:
			# 花牌带满了：这一行不再摆货
			slot["flower"] = {}
			slot["bought"] = false
			tile.setup_flower("", CARD_ART)
			_show_slot_text(name_label, "花牌已满")
			price.text = "—"
			buy.disabled = true
			_set_slot_popup(slot, "")
			continue
		if i >= flowers.size():
			slot["flower"] = {}
			slot["bought"] = false
			tile.setup_flower("", CARD_ART)
			_show_slot_text(name_label,
				"还没有花牌图片" if _owned_flowers.is_empty() else "已全部拥有")
			price.text = "—"
			buy.disabled = true
			_set_slot_popup(slot, "")
			continue
		var flower: Dictionary = flowers[i]
		slot["flower"] = flower
		slot["bought"] = false
		tile.setup_flower(flower["path"], CARD_ART)
		# 卡片上不写名字也不写效果：插画看牌面，效果靠悬停气泡
		_show_slot_text(name_label, "")
		var desc := FlowerTiles.effect_desc(flower["id"])
		# 效果不写在卡片上：鼠标压上去弹气泡，气泡里只写效果
		_set_slot_popup(slot, desc if desc != "" else "效果待定")
		_update_flower_slot(i)


func _update_flower_slot(index: int) -> void:
	var slot: Dictionary = _flower_slots[index]
	var flower: Dictionary = slot["flower"]
	var price: Label = slot["price"]
	var buy: Button = slot["buy"]
	if flower.is_empty():
		buy.disabled = true
		_refresh_price_plate(slot)
		return
	if slot["bought"]:
		price.text = "已购买"
		buy.disabled = true
		_refresh_price_plate(slot)
		return
	var id: String = flower["id"]
	price.text = "%d 钱" % FlowerTiles.price(id)
	# 效果还没登记的花牌先不让买，免得花冤枉钱
	var key := FlowerTiles.effect_key(id)
	# 带满了也不给买
	var full := _owned_flowers.size() >= FlowerTiles.LIMIT
	buy.disabled = key == "" or Settings.coins < FlowerTiles.price(id) or full
	_refresh_price_plate(slot)


func _refresh_price_plate(slot: Dictionary) -> void:
	## 买不起 / 已经买过的时候，把价格牌压暗，一眼能看出按了没用
	var plate: TextureRect = slot.get("plate")
	var buy: Button = slot["buy"]
	if plate != null:
		plate.modulate = _plate_modulate(buy)


func _on_buy_flower_pressed(index: int) -> void:
	if index < 0 or index >= _flower_slots.size():
		return
	var slot: Dictionary = _flower_slots[index]
	var flower: Dictionary = slot["flower"]
	if flower.is_empty() or slot["bought"]:
		return
	if _owned_flowers.size() >= FlowerTiles.LIMIT:
		return
	var key := FlowerTiles.effect_key(flower["id"])
	var cost := FlowerTiles.price(flower["id"])
	if key == "" or Settings.coins < cost:
		return
	Settings.add_coins(-cost)
	_owned_flowers.append(flower["id"])
	slot["bought"] = true
	_update_flower_slot(index)
	_update_refresh_button()
	_refresh()


func _build_shop_slot(index: int) -> Dictionary:
	var panel := _slot_panel()

	var tile := TileWidget.new()
	tile.setup(0)
	tile.set_tile_size(CARD_ICON)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_in_card(panel, tile, CARD_ICON)

	var price_ui := _build_price_plate(_on_buy_pressed.bind(index))
	_place_price_plate(panel, price_ui["button"])
	# 道具卡片上也不写效果了，同样是悬停看气泡
	_connect_slot_hover(panel, price_ui["button"])

	return {
		"root": panel, "tile": tile, "price": price_ui["label"],
		"plate": price_ui["plate"], "buy": price_ui["button"],
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
		tile.set_tile_size(CARD_ICON)
		# 效果写在悬停气泡里（气泡里也只有效果）
		_set_slot_popup(slot, item["desc"])
		_update_shop_slot(i)


func _update_shop_slot(index: int) -> void:
	var slot: Dictionary = _shop_slots[index]
	var price: Label = slot["price"]
	var buy: Button = slot["buy"]
	if slot["bought"]:
		price.text = "已购买"
		buy.disabled = true
	else:
		price.text = "%d 钱" % ShopItems.PRICE
		buy.disabled = Settings.coins < ShopItems.PRICE
	_refresh_price_plate(slot)


# ---------------------------------------------------------------- 商店的悬停气泡

func _build_item_popup() -> void:
	## 鼠标压到商品上时弹出来的气泡：卡片上不写效果，都在这儿讲
	## 用普通 Control 当壳——用 PanelContainer 的话它自带的深色底板会从
	## 气泡图的透明处（圆角、尖角两侧）露出来，看上去像一层黑遮罩。
	_item_popup = Control.new()
	_item_popup.custom_minimum_size = POPUP_SIZE
	_item_popup.size = POPUP_SIZE
	_item_popup.visible = false
	_item_popup.z_index = 10
	_item_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_item_popup)

	var bubble := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = load(UI_ITEM_POPUP)
	atlas.region = POPUP_REGION
	bubble.texture = atlas
	bubble.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bubble.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bubble.set_anchors_preset(Control.PRESET_FULL_RECT)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_popup.add_child(bubble)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", int(POPUP_SIZE.x * POPUP_TEXT.position.x))
	margin.add_theme_constant_override("margin_right",
		int(POPUP_SIZE.x * (1.0 - POPUP_TEXT.position.x - POPUP_TEXT.size.x)))
	margin.add_theme_constant_override("margin_top", int(POPUP_SIZE.y * POPUP_TEXT.position.y))
	margin.add_theme_constant_override("margin_bottom",
		int(POPUP_SIZE.y * (1.0 - POPUP_TEXT.position.y - POPUP_TEXT.size.y)))
	_item_popup.add_child(margin)

	_popup_body = _make_label("", 13, INK_DARK)
	_popup_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_popup_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(_popup_body)


func _connect_slot_hover(panel: Control, buy: Button) -> void:
	## 压在卡片上、或者压到购买键上，都算「正在看这件货」
	panel.mouse_entered.connect(_on_slot_hover_in.bind(panel))
	panel.mouse_exited.connect(_on_slot_hover_out)
	buy.mouse_entered.connect(_on_slot_hover_in.bind(panel))
	buy.mouse_exited.connect(_on_slot_hover_out)


func _set_slot_popup(slot: Dictionary, text: String) -> void:
	var panel: Control = slot["root"]
	panel.set_meta("popup_text", text)


func _on_slot_hover_in(slot_root: Control) -> void:
	if _item_popup == null:
		return
	_popup_token += 1
	var text := str(slot_root.get_meta("popup_text", ""))
	if text == "":
		_item_popup.visible = false
		return
	_popup_body.text = text
	_item_popup.visible = true
	# 气泡摆在卡片正上方，下面那个尖角压住卡片一点点
	var view := get_viewport_rect().size
	var pos := slot_root.global_position \
		+ Vector2(slot_root.size.x * 0.5 - _item_popup.size.x * 0.5,
			-_item_popup.size.y + POPUP_SIZE.y * POPUP_TAIL)
	pos.x = clampf(pos.x, 8.0, maxf(8.0, view.x - _item_popup.size.x - 8.0))
	pos.y = maxf(pos.y, 8.0)
	_item_popup.global_position = pos


func _on_slot_hover_out() -> void:
	## 稍微等一下再收：从卡片挪到购买键上时不闪
	_popup_token += 1
	var token := _popup_token
	await get_tree().create_timer(0.1).timeout
	if token == _popup_token and _item_popup != null:
		_item_popup.visible = false


func _hide_item_popup() -> void:
	_popup_token += 1
	if _item_popup != null:
		_item_popup.visible = false


func _on_settle_pressed() -> void:
	_hide_settlement()   # 结算板收起来，换成商店弹窗
	_show_shop()


func _build_shop_overlay() -> void:
	## 商店是一整块弹窗：压暗背景 + 中式窗框，货架摆在窗框中间那块宣纸上
	_shop_overlay = Control.new()
	_shop_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_shop_overlay.visible = false
	add_child(_shop_overlay)
	_shop_overlay.resized.connect(_layout_shop)

	_shop_dim = ColorRect.new()
	_shop_dim.color = Color(0.0, 0.0, 0.0, 0.45)
	_shop_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_overlay.add_child(_shop_dim)

	# 窗框和货架装在一个壳里，进场动画只需要动这个壳
	_shop_window = Control.new()
	_shop_window.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_overlay.add_child(_shop_window)

	_shop_frame = TextureRect.new()
	_shop_frame.texture = load(UI_SHOP_WINDOW)
	_crisp(_shop_frame)
	_shop_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shop_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_shop_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_window.add_child(_shop_frame)

	_shop_page = _build_shop_page()
	_shop_page.visible = false
	_shop_window.add_child(_shop_page)
	_build_shop_refresh()


func _build_shop_refresh() -> void:
	## 刷新按钮挂在窗框右侧、屋檐下面（不在宣纸上，压在窗框的木头边框上）
	var holder := Control.new()
	holder.custom_minimum_size = REFRESH_BUTTON_SIZE
	holder.size = REFRESH_BUTTON_SIZE
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_window.add_child(holder)
	_shop_refresh_holder = holder

	_shop_refresh_button = Button.new()
	_shop_refresh_button.custom_minimum_size = REFRESH_BUTTON_SIZE
	_shop_refresh_button.size = REFRESH_BUTTON_SIZE
	_shop_refresh_button.focus_mode = Control.FOCUS_NONE
	_shop_refresh_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		_shop_refresh_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_shop_refresh_button.pressed.connect(_on_refresh_pressed)
	holder.add_child(_shop_refresh_button)

	var art := TextureRect.new()
	art.texture = load(UI_REFRESH_BUTTON)
	_crisp(art)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_refresh_button.add_child(art)
	_shop_refresh_button.set_meta("art", art)

	# 价格写在图自带的那块小名牌上
	_shop_refresh_price = _make_label("", 11, GOLD)
	_shop_refresh_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_refresh_price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_shop_refresh_price.position = Vector2(
		REFRESH_BUTTON_SIZE.x * REFRESH_PLAQUE.position.x,
		REFRESH_BUTTON_SIZE.y * REFRESH_PLAQUE.position.y)
	_shop_refresh_price.size = Vector2(
		REFRESH_BUTTON_SIZE.x * REFRESH_PLAQUE.size.x,
		REFRESH_BUTTON_SIZE.y * REFRESH_PLAQUE.size.y)
	_shop_refresh_price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_refresh_button.add_child(_shop_refresh_price)

	_shop_refresh_button.mouse_entered.connect(func() -> void:
		if not _shop_refresh_button.disabled:
			art.modulate = Color(1.12, 1.12, 1.12))
	_shop_refresh_button.mouse_exited.connect(_update_refresh_button)
	holder.set_meta("art", art)


func _update_refresh_button() -> void:
	if _shop_refresh_button == null:
		return
	var art: TextureRect = _shop_refresh_button.get_meta("art")
	_shop_refresh_price.text = "%d 钱" % _refresh_cost
	_shop_refresh_button.disabled = Settings.coins < _refresh_cost
	art.modulate = Color(1.0, 1.0, 1.0) if not _shop_refresh_button.disabled \
		else Color(0.6, 0.6, 0.6)


func _on_refresh_pressed() -> void:
	## 花铜钱重抽一次货：第一次 1 钱，之后 2、3……（每次进商店重新从 1 起）
	if Settings.coins < _refresh_cost:
		return
	Settings.add_coins(-_refresh_cost)
	Sfx.play("refresh")
	_refresh_cost += 1
	_roll_shop()
	_roll_flowers()
	_update_refresh_button()


func _layout_shop() -> void:
	## 窗框按屏幕短边等比铺满、居中；货架摆进窗框中间那块宣纸范围
	if _shop_page == null:
		return
	var view := get_viewport_rect().size
	var side := minf(view.x, view.y)
	var origin := Vector2((view.x - side) * 0.5, (view.y - side) * 0.5)
	_shop_page.position = origin \
		+ Vector2(side * SHOP_PAPER.position.x, side * SHOP_PAPER.position.y)
	_shop_page.size = side * SHOP_PAPER.size
	# 刷新按钮挂在窗框右侧、屋檐底下那点空位上（宣纸的右上角）
	if _shop_refresh_holder != null:
		var paper_right := origin.x + side * (SHOP_PAPER.position.x + SHOP_PAPER.size.x)
		_shop_refresh_holder.size = REFRESH_BUTTON_SIZE
		# 往右挪到「一半压在宣纸上、一半探出到窗框」的位置
		_shop_refresh_holder.position = Vector2(
			paper_right - REFRESH_BUTTON_SIZE.x * 0.5,
			origin.y + side * SHOP_PAPER.position.y) + REFRESH_OFFSET


func _show_shop() -> void:
	# 商店是整屏盖上去的，飘分板别再飘在上面挡着商品
	_hide_score_popup()
	_settle_page.visible = false
	_shop_page.visible = true
	_set_settle_panel_height(SETTLE_PANEL_H)   # 商店没有花牌奖励那一行，抽屉收回标准高度
	_shop_overlay.visible = true
	_refresh_cost = 1          # 每次进商店，刷新价从 1 钱重新起算
	_delete_used = false       # 每次进商店可以删一次牌
	_roll_shop()
	_roll_flowers()
	_update_refresh_button()
	_update_delete_button()
	_hide_item_popup()
	_layout_shop()
	# 从屏幕下方滑上来，同时把背景压暗淡入
	if _shop_tween != null and _shop_tween.is_valid():
		_shop_tween.kill()
	_shop_window.position.y = get_viewport_rect().size.y
	_shop_dim.color.a = 0.0
	_shop_tween = create_tween()
	_shop_tween.set_parallel(true)
	_shop_tween.tween_property(_shop_window, "position:y", 0.0, 0.38) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_shop_tween.tween_property(_shop_dim, "color:a", 0.45, 0.24)


func _hide_shop() -> void:
	_close_delete_popup()
	if _shop_tween != null and _shop_tween.is_valid():
		_shop_tween.kill()
	if _shop_overlay != null:
		_shop_overlay.visible = false
	if _shop_page != null:
		_shop_page.visible = false
	if _shop_window != null:
		_shop_window.position.y = 0.0
	_hide_item_popup()


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
	_update_shop_slot(index)
	_update_refresh_button()
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
	_score_shown_serial = 0
	_score_sequence_done = _score_sequence   # 上一关没演完的计分动画别再等了
	_hide_settlement()
	_hide_shop()
	round_ = MahjongRound.new()
	round_.changed.connect(_refresh)
	round_.finished.connect(_on_round_finished)
	# 花牌要在 start() 之前登记：满天星会给这一关多加两巡，start() 里就要算进去
	round_.flowers.clear()
	for id in _owned_flowers:
		var effect := FlowerTiles.effect_key(id)
		if effect != "":
			round_.flowers.append(effect)
	round_.start(randi(), [], level, _deck)
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
	_reset_deck()


func _reset_deck() -> void:
	## 重开一局：牌库回到 136 张（删牌是本局内的构筑，不跨局）
	_deck = []
	for kind in TileCodec.KIND_COUNT:
		for copy in TileCodec.COPIES_PER_KIND:
			_deck.append(kind)


func _auto_draw() -> void:
	## 轮到玩家该摸牌了，就自己摸——不用玩家再点一下「摸牌」
	if round_ == null or round_.is_over():
		return
	if round_.state != MahjongRound.State.READY or not round_.can_draw():
		return
	_selected_index = -1
	_has_selection = false
	round_.draw_tile()  # 内部会发 changed 信号刷新界面


func _on_discard_pressed() -> void:
	if not _has_selection:
		return
	_do_discard(_selected_index)


func _on_swap_pressed() -> void:
	## 紫罗兰：进入「挑要弃掉的牌」模式
	if not round_.can_swap():
		return
	_swap_mode = true
	_swap_selection.clear()
	_selected_index = -1
	_has_selection = false
	_refresh()


func _on_swap_cancel_pressed() -> void:
	_exit_swap_mode()
	_refresh()


func _on_swap_confirm_pressed() -> void:
	if not _swap_mode or _swap_selection.is_empty():
		return
	var count := round_.swap_tiles(_swap_selection)
	var positions := round_.swap_positions.duplicate()
	_exit_swap_mode()
	_refresh()
	if count > 0:
		_play_swap_animation(positions)


func _play_swap_animation(positions: Array) -> void:
	## 换进来的牌跟开局发牌一样从上面落下来：一张一张，每张相差 0.1 秒，落一张响一声
	var order := 0
	for index in _tile_row.get_child_count():
		var child := _tile_row.get_child(index)
		if not (child is TileWidget) or not positions.has(index):
			continue
		var delay := order * DEAL_DELAY
		order += 1
		child.play_deal(delay)
		_play_sound_later(delay, "draw")


func _exit_swap_mode() -> void:
	_swap_mode = false
	_swap_selection.clear()


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
	_play_finish_sound(won, description)
	# 计分演出还在演（碰 / 杠 / 胡要一张张冒 +10）：等它演完再掀结算板，
	# 不然结算板一上来就把牌上那些「+10」压在底下，看着很乱
	if _score_fx_running():
		await _wait_score_animation()
		if not is_inside_tree():
			return
	_show_settlement(won)


func _wait_score_animation() -> void:
	## 等计分演出演完。加个上限，万一哪一步没走完也不会一直卡着
	var waited := 0.0
	while _score_fx_running() and waited < 8.0 and is_inside_tree():
		waited += 0.1
		await get_tree().create_timer(0.1).timeout


func _play_finish_sound(won: bool, description: String) -> void:
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
	if _swap_mode:
		# 换牌模式：点一下选中、再点一下取消，可以多选
		if _swap_selection.has(index):
			_swap_selection.erase(index)
		else:
			_swap_selection.append(index)
		_refresh()
		return
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
	_rebuild_flowers()
	_rebuild_tiles()
	_rebuild_pools()
	_update_hint()
	# 又得了一次分就弹一下飘分板
	if round_.score_serial != _score_shown_serial:
		_score_shown_serial = round_.score_serial
		_play_score_sequence(round_.last_score_base_start, round_.last_score_multiplier_start,
			round_.last_score_base, round_.last_score_multiplier, round_.last_flower_effects,
			round_.last_score_tiles, round_.last_score_kind)
	# 先把按钮该显示的显示出来，再排位置：
	# 按钮是居中摆的，位置按「这一行有多宽」算，顺序反了就会拿上一帧的宽度去居中。
	_update_action_buttons()
	_layout_table()

	# 轮到玩家摸牌就自动摸（延后一帧，免得在刷新过程中又触发一轮刷新）
	if round_.state == MahjongRound.State.READY and not _ai_running:
		_auto_draw.call_deferred()


func _update_action_buttons() -> void:
	## 按钮只在该做决定的时候出现：该打牌就只给打出，能碰能给碰
	var state := round_.state
	var claiming := state == MahjongRound.State.CLAIM
	# 换牌窗口已经关了（比如刚摸完牌）就退出换牌模式，免得停在半路上
	if _swap_mode and not round_.can_swap():
		_exit_swap_mode()
	_swap_button.visible = round_.can_swap() and not _swap_mode
	_swap_confirm_button.visible = _swap_mode
	_swap_cancel_button.visible = _swap_mode
	_swap_confirm_button.disabled = _swap_selection.is_empty()
	_swap_confirm_button.text = "确认换牌（%d）" % _swap_selection.size()
	# 挑牌的时候先别给打出，免得两件事搅在一起
	_discard_button.visible = state == MahjongRound.State.DISCARDING and not _swap_mode
	_ron_button.visible = claiming and round_.can_ron
	_kong_button.visible = claiming and round_.can_kong
	# 能杠的时候就不给碰了，杠优先
	_pong_button.visible = claiming and round_.can_pong and not round_.can_kong
	# 暗杠发生在自己摸完牌、还没打出去的时候
	_concealed_kong_button.visible = state == MahjongRound.State.DISCARDING and round_.can_concealed_kong()
	_pass_button.visible = claiming

	_discard_button.disabled = not _has_selection


func _rebuild_tiles() -> void:
	## 手牌 + 副露同占一行
	for child in _tile_row.get_children():
		_tile_row.remove_child(child)
		child.queue_free()
	_row_widgets.clear()

	var count := round_.hand.tiles.size()
	var win_index := -1
	if round_.state == MahjongRound.State.WON and round_.winning_tile >= 0 and not round_.hand.has_drawn():
		win_index = round_.hand.tiles.find(round_.winning_tile)
	for index in count:
		var hand_tile := _make_tile(index, round_.hand.tiles[index], false, index == win_index)
		_tile_row.add_child(hand_tile)
		_row_widgets.append(hand_tile)

	if round_.hand.has_drawn():
		_add_gap(DRAWN_GAP)
		var drawn := _make_tile(count, round_.hand.drawn_tile, true)
		_tile_row.add_child(drawn)
		_row_widgets.append(drawn)
		# 刚摸进来的那张要有入场动画，但要避免每次刷新都重播
		var showing_draw := round_.state == MahjongRound.State.DISCARDING \
			or round_.state == MahjongRound.State.WON
		if showing_draw and _draw_animated_for != round_.draw_serial:
			_draw_animated_for = round_.draw_serial
			drawn.play_draw()
			Sfx.play("draw")

	# 副露（碰 / 杠）就排在自家手牌右边、同一行里，砖头大小跟手牌一模一样。
	# 每一副之间留一道缝，一副里面几张紧靠，跟牌河一个道理。
	for meld in round_.melds:
		_add_gap(MELD_GAP)
		for i in round_.meld_tile_count(meld):
			var meld_tile := _make_meld_tile(meld["kind"], meld.get("concealed", false))
			_tile_row.add_child(meld_tile)
			_row_widgets.append(meld_tile)

	_fit_tile_row()


func _fit_tile_row() -> void:
	## 手牌和副露现在同占一行，牌多了会顶到右边的分数牌。
	## 这里量一下这一行自然要多宽，放不下就整行等比缩一点（放得下就不动）。
	var natural := _tile_row.get_combined_minimum_size().x
	var room := get_viewport_rect().size.x - PANEL_MARGIN * 2.0 - SCOREBOARD_WIDTH - TABLE_SEPARATION
	_row_scale = clampf(room / maxf(natural, 1.0), 0.5, 1.0)
	if _row_scale >= 0.999:
		return
	for child in _tile_row.get_children():
		if child is TileWidget:
			child.set_tile_size(TileWidget.TILE_SIZE * _row_scale, 0.09)


func _rebuild_flowers() -> void:
	## 牌桌最上面那一行：本局买到的花牌照原样摆出来
	## 只有买到的花牌变了才重建——刷新一次就重建的话，正在跳的花牌会被换掉，动画就白演了
	if _flower_built == _owned_flowers and _flower_widgets.size() == _owned_flowers.size():
		return
	_flower_built.assign(_owned_flowers)
	_flower_widgets.clear()
	for child in _flower_row.get_children():
		_flower_row.remove_child(child)
		child.queue_free()
	for id in _owned_flowers:
		var tile := TileWidget.new()
		tile.setup_flower(FlowerTiles.path_of(id), FLOWER_TILE)
		_flower_row.add_child(tile)
		_flower_widgets.append(tile)


func _add_gap(width: int) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(width, 1)
	_tile_row.add_child(gap)


func _make_tile(index: int, kind: int, drawn: bool, highlight: bool = false) -> TileWidget:
	var widget := TileWidget.new()
	widget.setup(kind, drawn)
	widget.set_hinted(_hint_discards.has(kind))
	widget.set_selected(highlight or _swap_selection.has(index)
		or (_has_selection and _selected_index == index))
	widget.pressed.connect(_on_tile_pressed.bind(index))
	return widget


func _make_meld_tile(kind: int, concealed: bool = false) -> TileWidget:
	var widget := TileWidget.new()
	widget.setup(kind, false, false, true)
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
	# 「假装买过花牌」是前置状态，跟后面选哪种画面可以叠加
	if "--owned" in args:
		for entry in FlowerTiles.available():
			if _owned_flowers.size() >= FlowerTiles.LIMIT:
				break
			_owned_flowers.append(entry["id"])
			round_.flowers.append(FlowerTiles.effect_key(entry["id"]))
		if "--full" in args:
			# 凑满上限，用来看商店「花牌已满」的样子
			while _owned_flowers.size() < FlowerTiles.LIMIT:
				_owned_flowers.append("占位%d" % _owned_flowers.size())
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
	elif "--clear" in args or "--clear2" in args or "--shop" in args or "--delete" in args:
		# 一直打到本关达标，看过关画面
		while not round_.is_over():
			_debug_play_one_tour()
			if round_.state == MahjongRound.State.AI_TURN:
				round_.run_opponent_turn()
		if "--delete" in args:
			Settings.coins = 30
			_on_settle_pressed()
			_open_delete_popup()   # 直接翻开删牌弹窗
			if "--pick" in args:
				for i in 4:
					_on_delete_tile_pressed(i)
		if "--shop" in args:
			Settings.coins = 30  # 调试用：给点铜钱，方便看购买键
			_on_settle_pressed()  # 点「结算」翻到商店
			if "--popup" in args:
				# 模拟鼠标压在第一张花牌上，看气泡
				_debug_hover_first_flower()
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
	elif "--fx" in args:
		# 计分演出：桌上从左到右是 梨花 / 水仙 / 桃花，
		# 所以先滚倍率（1→2），再滚底分（10→30），最后倍率再滚（2→4）
		round_.flowers.assign(["discard_bonus", "discard_base", "combo"])
		_owned_flowers.assign(["梨花", "水仙", "桃花"])
		round_.target_score = 9999   # 调试画面而已，别让这一张直接过关弹结算板
		_debug_skip_first_tour()
		round_.wall.stack_next(8, 0)   # 摸到九万
		round_.draw_tile()
		round_.discard(round_.hand.tiles.size())
	elif "--coin" in args:
		# 牡丹：过关时手里每有一张字牌多给 4 钱，看结算板上多出来的那一行
		round_.flowers.assign(["honor_coin"])
		_owned_flowers.assign(["牡丹"])
		round_.hand.reset([27, 28, 29, 30, 31, 32, 33, 0, 3, 6, 9, 12, 15])   # 手里 7 张字牌
		round_.score = round_.target_score - 10   # 再打一张就达标
		_debug_play_one_tour()
	elif "--violet" in args:
		# 买了紫罗兰。再加 --pick 就直接进换牌模式，选两张看界面
		round_.flowers.assign(["violet"])
		if "--pick" in args:
			_on_swap_pressed()
			_on_tile_pressed(0)
			_on_tile_pressed(2)
			if "--confirm" in args:
				_on_swap_confirm_pressed()   # 截在换牌动画演到一半的时候
	elif "--draw" in args:
		_debug_skip_first_tour()
		round_.draw_tile()
	# 有动画正在播的模式不要再刷新，否则刚建好的牌会被重建、动画白做
	var keeps_animation := "--draw" in args or "--konged" in args \
		or "--ankonged" in args or "--ai" in args or "--confirm" in args
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


func _debug_hover_first_flower() -> void:
	## 调试用：等版面排完再模拟悬停，不然量到的是没排版时的坐标
	for i in 3:
		await get_tree().process_frame
	_on_slot_hover_in(_flower_slots[0]["root"])


func _debug_play_one_tour() -> void:
	## 调试用：按当前状态走完玩家这一半（该摸就摸，该打就打）
	if round_.state == MahjongRound.State.READY:
		round_.draw_tile()
	if round_.state == MahjongRound.State.DISCARDING:
		if round_.hand.has_drawn():
			round_.discard(round_.hand.tiles.size())
		else:
			round_.discard(round_.hand.tiles.size() - 1)


func _debug_wait_score_mid() -> void:
	## 调试用：等到计分演出演到一半（牌上已经冒字、飘分板上的数字正在滚）再截图。
	## 开局那几帧的 delta 很不准，按固定秒数等会等偏，所以这里直接看状态。
	var start_text := "%d" % round_.last_score_base_start
	var guard := 0
	while guard < 900:
		guard += 1
		await get_tree().process_frame
		if _score_popup == null or not _score_popup.visible:
			continue
		if _score_popup_base.text != start_text:
			break
	await get_tree().process_frame


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
	if "--ponged" in OS.get_cmdline_user_args() or "--konged" in OS.get_cmdline_user_args() \
			or "--ankonged" in OS.get_cmdline_user_args() \
			or "--win" in OS.get_cmdline_user_args():
		# 这几条路径会得分、弹飘分板：等演到「牌上冒字、底分正在滚」再截图
		await _debug_wait_score_mid()
	if "--fx" in OS.get_cmdline_user_args():
		# 截在花牌起跳、飘分板上的数字正滚动的时候
		await get_tree().create_timer(FX_SHOT_WAIT).timeout
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
