extends Node
## Autoload. Persistent roster progress + per-chapter attempt history (kept across defeats).
const PATH = "user://campaign.json"
const AWAKEN_BONUS = Unit.AWAKEN_BONUS
const AWAKEN_HP = Unit.AWAKEN_HP
var roster = {}             # name -> {"level", "exp", "stats"} (base progress, never includes 각성)
var attempts = {}           # chapter -> Array of Arrays of deployed names (prior attempts)
var deploy = []             # current chosen lineup (empty = chapter default)

func _ready() -> void: load_campaign()

func is_awakened(chapter: String, name: String) -> bool:
	var prior: Array = attempts.get(chapter, [])
	if prior.is_empty(): return false
	for a in prior:
		if name in a: return false
	return true

func record_progress(u: Unit) -> void:
	if u.team != 0: return
	var st = u.stats.duplicate()
	if u.awakened:
		for s in st: st[s] -= AWAKEN_HP if s == "hp" else AWAKEN_BONUS
	roster[u.data.name] = {"level": u.level, "exp": u.exp, "stats": st}
	save_campaign()

func record_defeat(chapter: String, deployed: Array) -> void:
	if not attempts.has(chapter): attempts[chapter] = []
	attempts[chapter].append(deployed)
	save_campaign()

func record_clear(chapter: String) -> void:
	attempts.erase(chapter); deploy = []; save_campaign()

func to_dict() -> Dictionary: return {"roster": roster, "attempts": attempts, "deploy": deploy}

func save_campaign() -> void:
	var tmp = PATH + ".tmp"
	var f = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null: return
	f.store_string(JSON.stringify({"version": SaveManager.SAVE_VERSION, "campaign": to_dict()})); f.close()
	var dir = DirAccess.open("user://")
	if dir.file_exists(PATH.get_file()): dir.remove(PATH.get_file())
	dir.rename(tmp.get_file(), PATH.get_file())

func load_campaign() -> void:
	if not FileAccess.file_exists(PATH): return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(d) != TYPE_DICTIONARY: return
	var c = d.get("campaign", {})
	roster = c.get("roster", {}); attempts = c.get("attempts", {}); deploy = c.get("deploy", [])

func reset() -> void:
	roster = {}; attempts = {}; deploy = []; save_campaign()
