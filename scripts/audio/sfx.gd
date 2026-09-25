extends Node
## 音效总控。
##
## 按约定文件名去 assets/audio/ 下找音频：找到就播，找不到就安静跳过，
## 所以音效可以随时加、随时删，都不会让游戏报错或卡住。
## 支持 wav / ogg / mp3，同名有多种格式时按这个顺序优先。

## 找音频的目录，按顺序找：
##   voice/  碰、杠、胡了、自摸胡这类牌局结果音
##   effect/ 摸牌、打出、悬停这类操作音
## 外层主目录也留着，放在那里的同样能响。
const DIRS := [
	"res://assets/audio/",
	"res://assets/audio/voice/",
	"res://assets/audio/effect/",
]
const EXTS := [".wav", ".ogg", ".mp3"]
## 每个音效认多个文件名（英文名和中文名都行），按顺序取第一个存在的
const ALIASES := {
	"pong": ["碰", "pong"],
	"kong": ["杠", "kong"],
	"win": ["胡了", "胡", "荣和", "win"],
	"tsumo": ["自摸胡", "自摸", "tsumo"],
	"draw": ["fumble", "摸牌", "draw"],
	"discard": ["drop", "打出", "discard"],
	"impact": ["impact", "悬停"],
	"refresh": ["refresh", "刷新"],
	"clear": ["过关", "clear"],
	"tenhou": ["天胡", "tenhou"],
	"deal": ["发牌", "deal"],
}
const VOICES := 6        # 同时能响几路（碰杠连着来时不会互相打断）
const VOLUME_DB := -4.0  # 整体音量

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var volume_scale: float = 1.0  # 0..1，由设置界面控制


func _ready() -> void:
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


func _exit_tree() -> void:
	## 退出时把音频放开，免得 Godot 报「资源仍在使用」
	for player in _players:
		player.stop()
		player.stream = null
	_streams.clear()
	_players.clear()


func play(name: String, fallback: String = "") -> void:
	## 播一个音效；name 找不到时可以退回去播 fallback。
	if _silent():
		return
	if volume_scale <= 0.001:
		return  # 静音时干脆不播
	var stream := _stream_for(name)
	if stream == null and fallback != "":
		stream = _stream_for(fallback)
	if stream == null:
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.volume_db = VOLUME_DB + linear_to_db(volume_scale)
	player.play()


func set_volume_scale(value: float) -> void:
	volume_scale = clampf(value, 0.0, 1.0)


func has_sound(name: String) -> bool:
	return _stream_for(name) != null


func _silent() -> bool:
	## 无头运行（跑测试、打包校验）时不出声，也不用建音频对象
	return DisplayServer.get_name() == "headless" or OS.has_feature("headless")


func _stream_for(name: String) -> AudioStream:
	if _streams.has(name):
		return _streams[name]
	var found: AudioStream = null
	var candidates: Array = ALIASES.get(name, [name])
	for base in candidates:
		for dir in DIRS:
			for ext in EXTS:
				var path: String = dir + base + ext
				if not ResourceLoader.exists(path):
					continue
				var res := load(path)
				if res is AudioStream:
					found = res
					break
			if found != null:
				break
		if found != null:
			break
	_streams[name] = found
	return found
