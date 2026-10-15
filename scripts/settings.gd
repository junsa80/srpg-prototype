extends Node
## Autoload "Settings": player options, persisted atomically to user://settings.json.
const PATH = "user://settings.json"
const TEXT_SPEEDS = ["느림", "보통", "빠름", "즉시"]
const CPS = [25.0, 50.0, 110.0, 0.0]   # chars/sec, 0 = instant
var bgm = 7          # 0..10
var sfx = 8          # 0..10
var text_speed = 1   # index into TEXT_SPEEDS
var growth_fixed = false
var anim = true

func _ready() -> void:
	if FileAccess.file_exists(PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if typeof(d) == TYPE_DICTIONARY:
			bgm = int(d.get("bgm", bgm)); sfx = int(d.get("sfx", sfx)); text_speed = int(d.get("text_speed", text_speed))
			growth_fixed = bool(d.get("growth_fixed", growth_fixed)); anim = bool(d.get("anim", anim))
	elif FileAccess.file_exists("user://anim_off"): anim = false   # migrate old flag file
	Unit.fixed_growth = growth_fixed

func save() -> void:
	Unit.fixed_growth = growth_fixed
	SaveManager.write_atomic(PATH, JSON.stringify({"bgm": bgm, "sfx": sfx, "text_speed": text_speed, "growth_fixed": growth_fixed, "anim": anim}))
	if is_instance_valid(Sfx): Sfx.apply_volumes()

func cps() -> float: return CPS[clampi(text_speed, 0, 3)]
