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
const NEXT = {"ch1": "ch2", "ch2": "ch3", "ch3": "ch4a", "ch4a": "ch5", "ch4b": "ch5", "ch5": "ch6", "ch6": "ch7", "ch7": "ch8", "ch8": "ch9", "ch9": "ch10", "ch10": "ch11", "ch11": "ch12", "ch12": "ch13", "ch13": "ch14", "ch14": "ch15", "ch15": "ch16", "ch16": "ch17", "ch17": "ch18", "ch18": "ch19", "ch19": "ch20", "ch20": "ch21", "ch21": "ch22", "ch22": "ch23", "ch23": "ch24", "ch24": "end"}
const TRAIN_EXP = 10        # 훈련 bonus EXP for each deployed unit after a defeat
var recruited = []          # names recruited by talk/village/rescue
var ranks = {}              # chapter -> best rank letter (S/A/B/C)
var sides = {}              # chapter -> Array of completed side objective ids
var route = ""              # "ch4a" / "ch4b" after the Ch3 branch
var drop_seeds = {}         # chapter -> random-drop seed for the current attempt (fixed until cleared: no save/load scumming)
var cycle = 0               # 환생 count (New Game+): enemies +CYCLE_LV levels per cycle
var clears = 0              # times the final chapter was cleared (unlocks 환생 on title)
const CYCLE_LV = 3          # 강화 환생 (grind): enemies +3 Lv per cycle
const CYCLE_LV_STD = 1      # 환생 (표준): enemies +1 Lv per cycle
var enemy_lv = 0            # accumulated enemy level bonus from all cycles
var rb_bonus = {}           # unit -> {"stats": {s: n}, "growth": {s: pct}, "wexp": {type: pts}} (표준 환생 carry-over)
var boosters = {}           # unit -> {s: n} stat boosters already used (kept through 표준 환생)
var keep_all = false        # last rebirth was 강화 (units pre-joined as before)
var camp_seen = []          # chapters whose camp conversation was shown
var supports_seen = []
var absent = []              # story-absent units (e.g. 노아 after Ch13; back only if persuaded in Ch14)      # support conversation ids read
## Content version of the game build. Bump when an update changes classes/maps so old saves get migrated
## and are offered ONE free 업데이트 재시작 (Ch1, keep everything, no ★, normal enemies).
const GAME_VERSION = 4      # 3 = 세라 시스터 / 성기사 상급, 4 = 기사→아머나이트, 그레이트나이트→제네럴, 리안 소셜나이트, 새 영입(그렉·카스·리엘)
var game_ver = GAME_VERSION # version the campaign was last saved by
var update_offer = 0        # >0: version whose 업데이트 재시작 offer is pending (shown once)
var update_restarts = []    # versions for which the free restart was taken (save marker)
var update_declined = []    # versions whose offer was declined

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
	drop_seeds.erase(ch)
	if chapter == "end": clears += 1
	ensure_roster(); save_campaign()

func drop_seed(ch: String) -> int:
	if not drop_seeds.has(ch): drop_seeds[ch] = randi() % 1000000007
	return int(drop_seeds[ch])

## 강화 환생 (grind): back to Ch1 keeping everything (levels, stats, ranks, items, convoy, gold). Enemies +3 Lv.
func rebirth() -> void:   # 노가다 모드
	cycle += 1; grind += 1; enemy_lv += CYCLE_LV; keep_all = true
	chapter = "ch1"; cleared = []; attempts = {}; deploy = []; ranks = {}; sides = {}; route = ""; drop_seeds = {}; resume = {}; camp_seen = []
	ensure_roster(); save_campaign()

const DIFFS = ["보통", "어려움", "매우 어려움"]; const DIFF_LV = [0, 2, 4]
const RB_CAP = 10; const RB_FULL = 3; const STAT_CAP = 2
const PERK_COST = {"gold": 1, "weapon": 2, "ranks": 2, "bundle": 1, "supports": 0, "stat": 3}
const BUNDLES = {"엘릭서": ["엘릭서"], "마스터 키": ["마스터 키"], "강철 무기 세트": ["강철검", "강철창", "강철도끼", "강철활"], "상처약 x5": ["상처약", "상처약", "상처약", "상처약", "상처약"]}
var difficulty = 0          # 0 보통 / 1 어려움 (+2 Lv) / 2 매우 어려움 (+4 Lv, smarter AI)
var grind = 0               # 노가다 모드 cycles (each +3 enemy Lv; marked on saves)

func full_clear() -> bool: return "ch6" in cleared
## 환생 포인트: 1 per chapter cleared this cycle, +3 for a full clear, capped at 10. Never carried over.
func rb_points() -> int: return mini(RB_CAP, cleared.size() + (RB_FULL if full_clear() else 0))
## Highest difficulty selectable: all tiers after a full clear; otherwise (mid-progress) the current one.
func max_diff() -> int: return 2 if full_clear() else difficulty

## Special weapons: brave, effective (특효), boss drops, rank >= A.
static func is_special(n: String) -> bool:
	if not Weapons.LIST.has(n): return false
	var w = Weapons.make(n)
	if w.is_item(): return false
	if w.brave or (w.effective.size() > 0 and w.type != WeaponData.Type.BOW) or w.rank >= 4: return true   # bows are innately anti-flier
	for ch in Maps.CH:
		for e in Maps.CH[ch].get("enemies", []):
			if e[3].get("boss", false) and e[3].get("drop", "") == n: return true
	return false

func special_owned() -> Array:
	var out = []
	for n in roster: for it in roster[n].get("items", []): if is_special(it.name) and not it.name in out: out.append(it.name)
	for it in convoy: if is_special(it.name) and not it.name in out: out.append(it.name)
	return out

## opts: {diff, gold, weapons: [names<=2], ranks, bundle: key|"", supports, stat: {unit, stat}|{}}
func rb_cost(o: Dictionary) -> int:
	var c = 0
	if o.get("gold", false): c += PERK_COST.gold
	c += PERK_COST.weapon * o.get("weapons", []).size()
	if o.get("ranks", false): c += PERK_COST.ranks
	if o.get("bundle", "") != "": c += PERK_COST.bundle
	if not o.get("stat", {}).is_empty(): c += PERK_COST.stat
	return c

func rb_defaults() -> Dictionary:
	var o = {"diff": difficulty, "gold": false, "weapons": [], "ranks": false, "bundle": "", "supports": true, "stat": {}}
	var pts = rb_points()
	if pts >= 1: o.gold = true
	if pts >= 2: o.bundle = "상처약 x5"
	return o

## 환생: restart at Ch1 with chosen difficulty and perks (budget = rb_points()). Units restart at join level.
func rebirth_std(o: Dictionary) -> bool:
	if rb_cost(o) > rb_points() or o.get("weapons", []).size() > 2 or int(o.get("diff", 0)) > max_diff(): return false
	var keep_w = o.get("weapons", []).filter(func(n): return n in special_owned())
	var new_ranks = {}
	if o.get("ranks", false):
		for n in roster:
			var r = {}
			for t in roster[n].get("wexp", {}):
				var k = ClassProfs.rank_of(int(roster[n].wexp[t]))
				if k > 0: r[str(t)] = ClassProfs.WEXP[k - 1]
			new_ranks[n] = r
	var st: Dictionary = o.get("stat", {})
	if not st.is_empty():
		var cur = rb_bonus.get(st.unit, {}).get("stats", {})
		var total = 0
		for s in cur: total += int(cur[s])
		if total < STAT_CAP:
			if not rb_bonus.has(st.unit): rb_bonus[st.unit] = {"stats": {}}
			rb_bonus[st.unit].stats[st.stat] = int(rb_bonus[st.unit].stats.get(st.stat, 0)) + 1
	for n in rb_bonus: rb_bonus[n]["wexp"] = new_ranks.get(n, {})
	for n in new_ranks: if not rb_bonus.has(n): rb_bonus[n] = {"stats": {}, "wexp": new_ranks[n]}
	if not o.get("ranks", false): for n in rb_bonus: rb_bonus[n]["wexp"] = {}
	gold = mini(3000, gold * 30 / 100) if o.get("gold", false) else 0
	convoy = keep_w.map(func(n): return Weapons.make(n).to_dict())
	for it in BUNDLES.get(o.get("bundle", ""), []): convoy.append(Weapons.make(it).to_dict())
	if not o.get("supports", true): supports_seen = []
	difficulty = int(o.get("diff", 0)); cycle += 1; keep_all = false
	enemy_lv = DIFF_LV[difficulty] + grind * CYCLE_LV
	roster = {}; recruited = []
	chapter = "ch1"; cleared = []; attempts = {}; deploy = []; ranks = {}; sides = {}; route = ""; drop_seeds = {}; resume = {}; camp_seen = []
	ensure_roster(); save_campaign()
	return true

## Carried 환생 bonuses applied once when a unit (re)joins: chosen stat (+1/cycle, cap +2 total) and kept ranks.
func apply_carry(u: Unit) -> void:
	var b = rb_bonus.get(u.data.name, {})
	for s in b.get("stats", {}): u.stats[s] += int(b.stats[s])
	if b.get("stats", {}).has("hp"): u.hp = u.stats.hp
	for t in b.get("wexp", {}): u.wexp[int(t)] = maxi(int(u.wexp.get(int(t), 0)), int(b.wexp[t]))

func carry_text(n: String) -> String:
	var b = rb_bonus.get(n, {})
	var parts = []
	for s in b.get("stats", {}): parts.append("%s+%d" % [Menus.STAT_NAMES.get(s, s), int(b.stats[s])])
	if b.get("wexp", {}).size(): parts.append("무기 랭크 유지")
	return ("환생 ★%d: " % cycle + " ".join(parts)) if parts.size() else ""

func mode_tag() -> String:
	var t = "환생 ★%d %s" % [cycle, DIFFS[difficulty]] if cycle > 0 or difficulty > 0 else ""
	if grind > 0: t += " [노가다 ×%d]" % grind
	if update_restarts.size() > 0: t += " [업데이트 재시작]"
	return t.strip_edges()


## 완전 초기화: wipe everything (campaign + all save slots).
func wipe_all() -> void:
	for i in 4: SaveManager.delete_slot(i)
	reset(); cycle = 0; clears = 0; save_campaign()

func to_dict() -> Dictionary:
	return {"roster": roster, "attempts": attempts, "deploy": deploy, "gold": gold, "convoy": convoy, "chapter": chapter, "cleared": cleared, "playtime": playtime, "recruited": recruited, "ranks": ranks, "sides": sides, "route": route, "drop_seeds": drop_seeds, "cycle": cycle, "clears": clears, "camp_seen": camp_seen, "supports_seen": supports_seen, "absent": absent, "enemy_lv": enemy_lv, "rb_bonus": rb_bonus, "boosters": boosters, "keep_all": keep_all, "difficulty": difficulty, "grind": grind, "game_ver": GAME_VERSION, "update_offer": update_offer, "update_restarts": update_restarts, "update_declined": update_declined}

## Make sure every joined unit has a roster entry (default stats/loadout).
func ensure_roster() -> void:
	for n in Roster.joined_by(chapter):
		if not roster.has(n):
			var u = Roster.make_unit(n, 0, Vector2i.ZERO)
			var fg = Unit.fixed_growth; Unit.fixed_growth = true   # deterministic join level
			for i in Roster.JOIN_LV.get(n, 1) - 1: u.level_up()
			Unit.fixed_growth = fg; u.hp = u.stats.hp
			apply_carry(u)
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
	drop_seeds = c.get("drop_seeds", {}); cycle = int(c.get("cycle", 0)); clears = int(c.get("clears", 0))
	camp_seen = c.get("camp_seen", []); supports_seen = c.get("supports_seen", []); absent = c.get("absent", [])
	if chapter == "end" and "ch6" in cleared and not "ch7" in cleared: chapter = "ch7"   # 7장 추가: 1부 완료 세이브는 7장으로
	# migrate: pre-rework saves only had 강화-style cycles (+3 Lv each, everyone kept)
	enemy_lv = int(c.get("enemy_lv", cycle * CYCLE_LV)); keep_all = bool(c.get("keep_all", cycle > 0))
	rb_bonus = c.get("rb_bonus", {}); boosters = c.get("boosters", {})
	difficulty = int(c.get("difficulty", 0)); grind = int(c.get("grind", cycle))   # old cycles were all keep-all
	game_ver = int(c.get("game_ver", 1)); update_offer = int(c.get("update_offer", 0))
	update_restarts = c.get("update_restarts", []).map(func(v): return int(v)); update_declined = c.get("update_declined", []).map(func(v): return int(v))
	if game_ver < GAME_VERSION:
		for n in roster: migrate_entry(n, roster[n], game_ver)
		if game_ver < 4 and roster.size() > 0:   # recruits added in v4 whose chapter is already behind this save: join at the base
			var late = {"그렉": "ch2" in cleared, "카스": "ch3" in cleared, "리엘": "ch4b" in cleared or "ch5" in cleared}
			for n in late:
				if late[n] and not n in recruited: recruited.append(n)
			ensure_roster()
		if roster.size() > 0 and not GAME_VERSION in update_restarts and not GAME_VERSION in update_declined: update_offer = GAME_VERSION
		game_ver = GAME_VERSION

## Per-unit save migration between content versions (roster entries and battle-snapshot units).
static func migrate_entry(n: String, e: Dictionary, from_ver: int) -> void:
	if from_ver < 3 and e.get("class", "") == "성기사" and n != "아서":   # 구 성기사(기본) → 시스터; 아서 joins as 상급 성기사
		e["class"] = "시스터"
		var wx = e.get("wexp", {})
		if typeof(wx) == TYPE_DICTIONARY:
			for t in [WeaponData.Type.STAFF, WeaponData.Type.SWORD]:
				if not (wx.has(t) or wx.has(str(t))): wx[str(t)] = ClassProfs.WEXP[ClassProfs.START_RANK["시스터"][t]]
		# items are kept as-is (철창 etc. stay; unusable ones show 병종 불가 and can go to the convoy)
	if from_ver < 4:
		var ren = {"기사": "아머나이트", "그레이트나이트": "제네럴"}   # renamed (same numbers)
		if n == "리안" and e.get("class", "") == "기사": e["class"] = "소셜나이트"   # user decision: 리안 = 기마 (level/stats kept)
		elif ren.has(e.get("class", "")): e["class"] = ren[e["class"]]

func has_update_offer() -> bool: return update_offer > 0 and roster.size() > 0
func decline_update() -> void:
	if not update_offer in update_declined: update_declined.append(update_offer)
	update_offer = 0; save_campaign()
## 업데이트 재시작: free, one-time per version. Back to Ch1 keeping levels/stats/ranks/items/convoy/gold.
## No ★ (cycle unchanged), no enemy level bonus added, recruits kept.
func update_restart() -> void:
	if not update_offer in update_restarts: update_restarts.append(update_offer)
	update_offer = 0; keep_all = true; difficulty = 0   # 보통 난이도, enemy_lv unchanged (no new bonus)
	chapter = "ch1"; cleared = []; attempts = {}; deploy = []; ranks = {}; sides = {}; route = ""; drop_seeds = {}; resume = {}; camp_seen = []
	ensure_roster(); save_campaign()

func reset() -> void:
	roster = {}; attempts = {}; deploy = []; gold = 0; convoy = []; chapter = "ch1"; cleared = []; playtime = 0.0; recruited = []; ranks = {}; sides = {}; route = ""; resume = {}; drop_seeds = {}; cycle = 0; camp_seen = []; supports_seen = []; enemy_lv = 0; rb_bonus = {}; boosters = {}; keep_all = false; difficulty = 0; grind = 0; update_offer = 0; save_campaign()

## Support conversations unlocked: both units in roster and chapter cleared.
func supports_open() -> Array:
	return ChapterData.SUPPORTS.filter(func(sp): return roster.has(sp.a) and roster.has(sp.b) and sp.after in cleared)
