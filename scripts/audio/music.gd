extends Node
## 背景音乐。
##
## 去 assets/audio/music/ 找一首循环播放；没有文件就安静什么都不做，
## 所以音乐可以随时丢进来、随时删掉，都不会报错。

const DIRS := [
	"res://assets/audio/bgm/",
	"res://assets/audio/music/",
	"res://assets/audio/",
]
const EXTS := [".ogg", ".mp3", ".wav"]

var volume_scale: float = 0.3
var _player: AudioStreamPlayer
var _current := ""


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_apply()


func play_track(name: String) -> void:
	## 换成指定曲子；同一首正在播就不打断（切场景、重开本关时不会重头放）
	if name == _current and _player != null and _player.playing:
		return
	_current = name
	if _player == null or _silent():
		return
	var stream := _find_stream(name)
	if stream == null:
		_player.stop()
		_player.stream = null
		return
	_loop(stream)
	_player.stream = stream
	_player.play()
	_apply()


func set_volume_scale(value: float) -> void:
	volume_scale = clampf(value, 0.0, 1.0)
	_apply()


func has_music() -> bool:
	return _player != null and _player.stream != null


func current_track() -> String:
	return _current


func _apply() -> void:
	if _player == null:
		return
	# 0 就是静音；其余按线性音量换算成 dB
	_player.volume_db = -80.0 if volume_scale <= 0.001 else linear_to_db(volume_scale)


func _silent() -> bool:
	return DisplayServer.get_name() == "headless" or OS.has_feature("headless")


func _loop(stream: AudioStream) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD


func _find_stream(name: String) -> AudioStream:
	for dir in DIRS:
		for ext in EXTS:
			var path: String = dir + name + ext
			if not ResourceLoader.exists(path):
				continue
			var res := load(path)
			if res is AudioStream:
				return res
	return null
