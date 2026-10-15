extends Node
## Autoload "Sfx": CC0 procedurally-synthesized chiptune SFX + BGM loop, mute toggle (persisted).
var players = {}
var bgm: AudioStreamPlayer
var muted = false
const NAMES = ["cursor", "select", "cancel", "hit", "crit", "miss", "levelup", "heal", "phase"]

func _ready() -> void:
	for n in NAMES:
		var p = AudioStreamPlayer.new(); p.stream = load("res://assets/sfx/%s.wav" % n); add_child(p); players[n] = p
	bgm = AudioStreamPlayer.new(); add_child(bgm)
	var s: AudioStreamWAV = load("res://assets/sfx/bgm.wav")
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD; s.loop_begin = 0; s.loop_end = s.data.size() / 2
	bgm.stream = s; bgm.volume_db = -8
	muted = FileAccess.file_exists("user://muted")
	_apply()

func play(n: String) -> void:
	if not muted and players.has(n): players[n].play()

func start_bgm() -> void:
	if not bgm.playing and not muted: bgm.play()

func toggle_mute() -> bool:
	muted = not muted; _apply()
	if muted: FileAccess.open("user://muted", FileAccess.WRITE).store_string("1")
	elif FileAccess.file_exists("user://muted"): DirAccess.remove_absolute("user://muted")
	return muted

func _apply() -> void:
	AudioServer.set_bus_mute(0, muted)
	if not muted and bgm and not bgm.playing and is_inside_tree(): bgm.play()
