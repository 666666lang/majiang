extends Control
## 主界面：开始游戏 / 设置（音乐和音效音量）。

var _main_box: VBoxContainer
var _settings_box: VBoxContainer
var _music_value: Label
var _sfx_value: Label


func _ready() -> void:
	UiStyle.apply_cjk_theme(self)
	_build()
	_show_main()
	Music.play_track("main")
	if "--shot" in OS.get_cmdline_user_args():
		if "--settings" in OS.get_cmdline_user_args():
			_show_settings()
		UiStyle.capture_and_quit(self)


func _unhandled_input(event: InputEvent) -> void:
	# 在设置页按 Esc 回主菜单
	if event.is_action_pressed("ui_cancel") and _settings_box.visible:
		_show_main()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UiStyle.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)

	_main_box = _build_main()
	column.add_child(_main_box)
	_settings_box = _build_settings()
	column.add_child(_settings_box)


func _build_main() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)

	var title := UiStyle.label("麻将传奇", 72, UiStyle.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var subtitle := UiStyle.label("换牌胡 · 共 24 关", 24, UiStyle.DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(gap)

	var start_button := UiStyle.button("开始游戏", UiStyle.ACTION_GOLD, UiStyle.ACTION_INK,
		Vector2(300, 68))
	start_button.pressed.connect(_on_start_pressed)
	box.add_child(start_button)

	var settings_button := UiStyle.button("设置", UiStyle.ACTION_SLATE, UiStyle.ACTION_LIGHT,
		Vector2(300, 68))
	settings_button.pressed.connect(_show_settings)
	box.add_child(settings_button)
	return box


func _build_settings() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)

	var title := UiStyle.label("设置", 48, UiStyle.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var music_row := _build_volume_row("音乐", Settings.music_volume, _on_music_changed)
	box.add_child(music_row[0])
	_music_value = music_row[1]

	var sfx_row := _build_volume_row("音效", Settings.sfx_volume, _on_sfx_changed)
	box.add_child(sfx_row[0])
	_sfx_value = sfx_row[1]

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(gap)

	var back_button := UiStyle.button("返回", UiStyle.ACTION_SLATE, UiStyle.ACTION_LIGHT,
		Vector2(300, 64))
	back_button.pressed.connect(_show_main)
	box.add_child(back_button)
	return box


func _build_volume_row(title: String, value: float, on_change: Callable) -> Array:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)

	var name_label := UiStyle.label(title, 24, UiStyle.DIM)
	name_label.custom_minimum_size = Vector2(72, 0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(name_label)

	var slider := UiStyle.slider()
	slider.value = value
	slider.value_changed.connect(on_change)
	row.add_child(slider)

	var value_label := UiStyle.label(_percent(value), 22, UiStyle.GOLD)
	value_label.custom_minimum_size = Vector2(76, 0)
	row.add_child(value_label)
	return [row, value_label]


func _percent(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)


func _show_main() -> void:
	_settings_box.visible = false
	_main_box.visible = true


func _show_settings() -> void:
	_main_box.visible = false
	_settings_box.visible = true


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_music_changed(value: float) -> void:
	Settings.set_music_volume(value)
	_music_value.text = _percent(value)


func _on_sfx_changed(value: float) -> void:
	Settings.set_sfx_volume(value)
	_sfx_value.text = _percent(value)
