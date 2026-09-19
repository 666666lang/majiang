extends Node
## 设置：音乐和音效音量，存到 user://settings.cfg，下次打开还在。

const PATH := "user://settings.cfg"
const DEFAULT_MUSIC := 0.3
const DEFAULT_SFX := 1.0

var music_volume: float = DEFAULT_MUSIC
var sfx_volume: float = DEFAULT_SFX
## 金币：一局游戏从头开始时归零，不存盘（音量才需要记住）
var coins: int = 0


func _ready() -> void:
	load_settings()
	apply()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	apply()
	save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	apply()
	save_settings()


func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)


func reset_coins() -> void:
	coins = 0


func apply() -> void:
	Music.set_volume_scale(music_volume)
	Sfx.set_volume_scale(sfx_volume)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return  # 还没存过，用默认值
	music_volume = clampf(config.get_value("audio", "music", DEFAULT_MUSIC), 0.0, 1.0)
	sfx_volume = clampf(config.get_value("audio", "sfx", DEFAULT_SFX), 0.0, 1.0)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.save(PATH)
