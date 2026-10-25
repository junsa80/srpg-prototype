extends Node
## Autoload "Sfx": CC0 procedurally-synthesized chiptune SFX + BGM loop, mute toggle (persisted).
var players = {}
var bgm: AudioStreamPlayer
var bgm_tracks = {}
var current_track = "home"
var muted = false
var bg = false            # app/tab in background: everything paused (resumes at the same position)
var _vis_cb = null        # keep the JS callback alive
const NAMES = ["cursor", "select", "cancel", "hit", "crit", "miss", "levelup", "heal", "phase", "pickup"]

func _ready() -> void:
	for n in NAMES:
		var p = AudioStreamPlayer.new(); p.stream = load("res://assets/sfx/%s.wav" % n); add_child(p); players[n] = p
	bgm = AudioStreamPlayer.new(); add_child(bgm)
	for track in ["home", "battle"]:
		var s: AudioStreamWAV = load("res://assets/sfx/bgm_home.wav" if track == "home" else "res://assets/sfx/bgm.wav")
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD; s.loop_begin = 0; s.loop_end = s.data.size() / 2
		bgm_tracks[track] = s
	bgm.stream = bgm_tracks["home"]; bgm.volume_db = -8
	muted = FileAccess.file_exists("user://muted")
	apply_volumes(); _apply()
	if OS.has_feature("web"):   # mobile browsers may not send focus notifications
		_vis_cb = JavaScriptBridge.create_callback(func(_a): set_background(bool(JavaScriptBridge.eval("document.hidden", true))))
		JavaScriptBridge.get_interface("document").addEventListener("visibilitychange", _vis_cb)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED: set_background(true)
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED: set_background(false)

## Background pause: stream_paused keeps the BGM position; bus mute silences SFX. User mute stays respected.
func set_background(on: bool) -> void:
	if bg == on: return
	bg = on
	if bgm: bgm.stream_paused = on
	for n in players: players[n].stream_paused = on
	AudioServer.set_bus_mute(0, muted or bg)

func apply_volumes() -> void:
	for n in players: players[n].volume_db = linear_to_db(Settings.sfx / 10.0) if Settings.sfx > 0 else -80.0
	if bgm: bgm.volume_db = (linear_to_db(Settings.bgm / 10.0) - 8.0) if Settings.bgm > 0 else -80.0
	if bgm and not Settings.bgm_on and bgm.playing: bgm.stop()
	elif bgm and Settings.bgm_on and not muted and not bg and not bgm.playing and is_inside_tree(): bgm.play()

func play(n: String) -> void:
	if not muted and not bg and Settings.sfx_on and players.has(n): players[n].play()

func start_bgm() -> void:
	var scene = get_tree().current_scene
	var track = "battle" if scene and "battle" in scene.scene_file_path else "home"
	if track != current_track:
		bgm.stop(); current_track = track; bgm.stream = bgm_tracks[track]
	if not bgm.playing and not muted and Settings.bgm_on: bgm.play()

func toggle_mute() -> bool:
	muted = not muted; _apply()
	if muted: FileAccess.open("user://muted", FileAccess.WRITE).store_string("1")
	elif FileAccess.file_exists("user://muted"): DirAccess.remove_absolute("user://muted")
	return muted

func _apply() -> void:
	AudioServer.set_bus_mute(0, muted or bg)
	if not muted and not bg and Settings.bgm_on and bgm and not bgm.playing and is_inside_tree(): bgm.play()
