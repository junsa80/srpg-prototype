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
var playtime = 0.0         # seconds
var resume = {}            # battle snapshot to restore on next battle scene load (from a save)
var chapter_start = {}     # campaign dict at chapter start (for 챕터 재시작)
const CONVOY_MAX = 100
const CLEAR_GOLD = {"ch1": 1000, "ch2": 1500}
const NEXT = {"ch1": "ch2", "ch2": "ch3", "ch3": "ch4a", "ch4a": "ch5", "ch4b": "ch5", "ch5": "ch6", "ch6": "end"}
const TRAIN_EXP = 10        # 훈련 bonus EXP for each deployed unit after a defeat
var recruited = []          # names recruited by talk/village/rescue
var ranks = {}              # chapter -> best rank letter (S/A/B/C)
var sides = {}              # chapter -> Array of completed side objective ids
var route = ""              # "ch4a" / "ch4b" after the Ch3 branch

func _ready() -> void: load_campaign()

func _process(dt: float) -> void: playtime += dt

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
	roster[u.data.name] = {"class": u.unit_class.name, "level": u.level, "exp": u.exp, "stats": st, "move_bonus": u.move_bonus, "wexp": u.wexp, "items": u.inventory.map(func(w): return w.to_dict())}
	if persist: save_campaign()

func record_defeat(chapter: String, deployed: Array) -> Array:
	if not attempts.has(chapter): attempts[chapter] = []
	attempts[chapter].append(deployed)
	var out = train(deployed)
	save_campaign()
	return out

## 훈련: deployed units gain a little EXP after a defeat (kept on retry).
func train(names: Array) -> Array:
	var out = []
	for n in names:
		if not roster.has(n): continue
		var u = Roster.make_unit(n, 0, Vector2i.ZERO, roster[n])
		var ups = u.gain_exp(TRAIN_EXP)
		record_progress(u, false); u.free()
		out.append("%s 훈련 EXP +%d%s" % [n, TRAIN_EXP, " → 레벨 업!" if ups.size() else ""])
	return out

func recruit(n: String) -> void:
	if not n in recruited: recruited.append(n)
	ensure_roster()

func record_clear(ch: String) -> void:
	attempts.erase(ch); deploy = []
	if not ch in cleared: cleared.append(ch); gold += Maps.CH.get(ch, {}).get("clear_gold", CLEAR_GOLD.get(ch, 500))
	chapter = NEXT.get(ch, "end")
	if ch == "ch3" and route != "": chapter = route
	ensure_roster(); save_campaign()

func to_dict() -> Dictionary:
	return {"roster": roster, "attempts": attempts, "deploy": deploy, "gold": gold, "convoy": convoy, "chapter": chapter, "cleared": cleared, "playtime": playtime, "recruited": recruited, "ranks": ranks, "sides": sides, "route": route}

## Make sure every joined unit has a roster entry (default stats/loadout).
func ensure_roster() -> void:
	for n in Roster.joined_by(chapter):
		if not roster.has(n):
			var u = Roster.make_unit(n, 0, Vector2i.ZERO)
			var fg = Unit.fixed_growth; Unit.fixed_growth = true   # deterministic join level
			for i in Roster.JOIN_LV.get(n, 1) - 1: u.level_up()
			Unit.fixed_growth = fg; u.hp = u.stats.hp
			record_progress(u, false); u.free()

func entry(n: String) -> Dictionary: return roster.get(n, {})

func to_convoy(w: WeaponData) -> bool:
	if convoy.size() >= CONVOY_MAX: return false
	convoy.append(w.to_dict()); save_campaign(); return true

func from_convoy(i: int) -> WeaponData:
	var it = convoy[i]; convoy.remove_at(i); save_campaign()
	return Weapons.make(it.name, int(it.uses))

func save_campaign() -> void:
	SaveManager.write_atomic(PATH, JSON.stringify({"version": SaveManager.SAVE_VERSION, "campaign": to_dict()}))

func load_campaign() -> void:
	if not FileAccess.file_exists(PATH): return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(d) != TYPE_DICTIONARY: return
	from_dict(d.get("campaign", {}))

func from_dict(c: Dictionary) -> void:
	c = c.duplicate(true)
	roster = c.get("roster", {}); attempts = c.get("attempts", {}); deploy = c.get("deploy", [])
	gold = int(c.get("gold", 0)); convoy = c.get("convoy", []); chapter = c.get("chapter", "ch1"); cleared = c.get("cleared", []); playtime = float(c.get("playtime", 0))
	recruited = c.get("recruited", []); ranks = c.get("ranks", {}); sides = c.get("sides", {}); route = c.get("route", "")

func reset() -> void:
	roster = {}; attempts = {}; deploy = []; gold = 0; convoy = []; chapter = "ch1"; cleared = []; playtime = 0.0; recruited = []; ranks = {}; sides = {}; route = ""; resume = {}; save_campaign()
