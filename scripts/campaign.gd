extends Node
## Autoload. Persistent roster progress + per-chapter attempt history (kept across defeats).
const PATH = "user://campaign.json"
const AWAKEN_BONUS = Unit.AWAKEN_BONUS
const AWAKEN_HP = Unit.AWAKEN_HP
var roster = {}             # name -> {"level", "exp", "stats"} (base progress, never includes 각성)
var attempts = {}           # chapter -> Array of Arrays of deployed names (prior attempts)
var deploy = []             # current chosen lineup (empty = chapter default)
var gold = 0
var convoy = []             # Array of {"name", "uses"} — shared storage
var chapter = "ch1"         # next/current chapter
var cleared = []            # cleared chapters
const CONVOY_MAX = 100
const CLEAR_GOLD = {"ch1": 1000, "ch2": 1500}

func _ready() -> void: load_campaign()

func is_awakened(chapter: String, name: String) -> bool:
	var prior: Array = attempts.get(chapter, [])
	if prior.is_empty(): return false
	for a in prior:
		if name in a: return false
	return true

func record_progress(u: Unit, persist = true) -> void:
	if u.team != 0: return
	for g in u.pending_gift: convoy.append(g.to_dict())
	u.pending_gift = []
	var st = u.stats.duplicate()
	if u.awakened:
		for s in st: st[s] -= AWAKEN_HP if s == "hp" else AWAKEN_BONUS
	roster[u.data.name] = {"class": u.unit_class.name, "level": u.level, "exp": u.exp, "stats": st, "move_bonus": u.move_bonus, "items": u.inventory.map(func(w): return w.to_dict())}
	if persist: save_campaign()

func record_defeat(chapter: String, deployed: Array) -> void:
	if not attempts.has(chapter): attempts[chapter] = []
	attempts[chapter].append(deployed)
	save_campaign()

func record_clear(ch: String) -> void:
	attempts.erase(ch); deploy = []
	if not ch in cleared: cleared.append(ch); gold += CLEAR_GOLD.get(ch, 500)
	var order = ["ch1", "ch2", "ch3"]; var i = order.find(ch)
	if i >= 0 and i + 1 < order.size(): chapter = order[i + 1]
	ensure_roster(); save_campaign()

func to_dict() -> Dictionary:
	return {"roster": roster, "attempts": attempts, "deploy": deploy, "gold": gold, "convoy": convoy, "chapter": chapter, "cleared": cleared}

## Make sure every joined unit has a roster entry (default stats/loadout).
func ensure_roster() -> void:
	for n in Roster.joined_by(chapter):
		if not roster.has(n):
			var u = Roster.make_unit(n, 0, Vector2i.ZERO)
			record_progress(u, false); u.free()

func entry(n: String) -> Dictionary: return roster.get(n, {})

func to_convoy(w: WeaponData) -> bool:
	if convoy.size() >= CONVOY_MAX: return false
	convoy.append(w.to_dict()); save_campaign(); return true

func from_convoy(i: int) -> WeaponData:
	var it = convoy[i]; convoy.remove_at(i); save_campaign()
	return Weapons.make(it.name, int(it.uses))

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
	gold = int(c.get("gold", 0)); convoy = c.get("convoy", []); chapter = c.get("chapter", "ch1"); cleared = c.get("cleared", [])

func reset() -> void:
	roster = {}; attempts = {}; deploy = []; gold = 0; convoy = []; chapter = "ch1"; cleared = []; save_campaign()
