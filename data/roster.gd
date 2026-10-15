class_name Roster extends RefCounted
## Class + playable unit definitions shared by battle and base screens.
const W = WeaponData.Type
## name: [move, base_stats, promotes_to, weapon_types]   (empty weapon_types = any, used by enemies)
const CLASSES = {
	"용병": [5, {"hp": 20, "str": 6, "mag": 0, "skl": 8, "spd": 8, "lck": 5, "def": 4, "res": 1}, "영웅", [W.SWORD]],
	"궁수": [5, {"hp": 17, "str": 5, "mag": 0, "skl": 7, "spd": 6, "lck": 4, "def": 3, "res": 1}, "스나이퍼", [W.BOW]],
	"성기사": [5, {"hp": 19, "str": 5, "mag": 3, "skl": 5, "spd": 5, "lck": 6, "def": 6, "res": 5}, "발키리", [W.SWORD, W.STAFF]],
	"마법사": [5, {"hp": 15, "str": 0, "mag": 7, "skl": 6, "spd": 6, "lck": 3, "def": 1, "res": 6}, "세이지", [W.TOME]],
	"기사": [4, {"hp": 22, "str": 7, "mag": 0, "skl": 5, "spd": 3, "lck": 3, "def": 8, "res": 1}, "그레이트나이트", [W.LANCE]],
	"도적": [6, {"hp": 16, "str": 4, "mag": 0, "skl": 8, "spd": 10, "lck": 7, "def": 2, "res": 1}, "어쌔신", [W.SWORD]],
	"전사": [5, {"hp": 24, "str": 8, "mag": 0, "skl": 5, "spd": 5, "lck": 3, "def": 5, "res": 0}, "워리어", [W.AXE]],
	"워리어": [6, {}, "", [W.AXE, W.BOW]], "버서커": [6, {}, "", [W.AXE]],
	"영웅": [6, {}, "", [W.SWORD, W.AXE]], "스나이퍼": [6, {}, "", [W.BOW]], "발키리": [6, {}, "", [W.SWORD, W.TOME, W.STAFF]],
	"세이지": [6, {}, "", [W.TOME, W.STAFF]], "그레이트나이트": [5, {}, "", [W.SWORD, W.LANCE]],
	"팔라딘": [7, {}, "", [W.SWORD, W.LANCE]], "어쌔신": [7, {}, "", [W.SWORD]], "검성": [6, {}, "", [W.SWORD]],
	# enemies
	"그림자 병사": [5, {"hp": 18, "str": 7, "mag": 0, "skl": 3, "spd": 4, "lck": 0, "def": 3, "res": 0}, "", []],
	"그림자 창병": [4, {"hp": 19, "str": 6, "mag": 0, "skl": 4, "spd": 3, "lck": 0, "def": 5, "res": 0}, "", []],
	"그림자 궁병": [5, {"hp": 17, "str": 6, "mag": 0, "skl": 5, "spd": 4, "lck": 0, "def": 3, "res": 1}, "", []],
	"그림자 술사": [5, {"hp": 16, "str": 0, "mag": 6, "skl": 4, "spd": 4, "lck": 0, "def": 2, "res": 4}, "", []],
	"그림자 중갑병": [4, {"hp": 22, "str": 7, "mag": 0, "skl": 3, "spd": 1, "lck": 0, "def": 9, "res": 0}, "", []],
	"그림자 기병": [7, {"hp": 20, "str": 6, "mag": 0, "skl": 5, "spd": 6, "lck": 0, "def": 5, "res": 1}, "", []],
	"그림자 비룡": [7, {"hp": 19, "str": 7, "mag": 0, "skl": 4, "spd": 6, "lck": 0, "def": 5, "res": 0}, "", []],
	"바르가스": [0, {"hp": 38, "str": 12, "mag": 0, "skl": 8, "spd": 4, "lck": 3, "def": 12, "res": 3}, "", []],
	"그림자 지휘관": [0, {"hp": 30, "str": 10, "mag": 0, "skl": 7, "spd": 5, "lck": 3, "def": 9, "res": 3}, "", []],
}
## Playable units: name -> [class, join_chapter, intro line]
const UNITS = {
	"아린": ["용병", "ch1", ""], "노아": ["용병", "ch1", ""], "리나": ["궁수", "ch1", ""], "세라": ["성기사", "ch1", ""],
	"엘리아": ["마법사", "ch1", ""], "카엘": ["기사", "ch1", ""], "루크": ["도적", "ch1", ""], "미라": ["마법사", "ch1", ""],
	"보리스": ["전사", "ch1", "나무만 패던 손이지만, 도끼질이라면 자신 있수다."],
	"에일린": ["용병", "ch2", "노아 선배한테 들었어. 나도 같이 갈게!"],
	"레온": ["기사", "ch2", "방패가 필요하겠지. 앞은 내가 맡겠다."],
	# recruited during the campaign (talk / village / rescue) — join via Campaign.recruited
	"가렌": ["용병", "recruit", "돈보다 나은 이유를 찾았다. 이 검, 맡기지."], "카이": ["궁수", "recruit", "마을을 지켜 준 빚은 화살로 갚지."],
	"리안": ["기사", "recruit", "살아남은 기사의 몫을 하겠다."], "실라": ["도적", "recruit", "루크 빚까지 내가 갚아 줄게. 농담이야."],
	"아서": ["성기사", "ch6", "왕성이 함락됐다. 길은 내가 안다, 따라와!"],
}
const IRON = {W.SWORD: "철검", W.LANCE: "철창", W.AXE: "철도끼", W.BOW: "철활", W.TOME: "파이어", W.STAFF: "힐"}
const COLORS = {"용병": Color(0.2, 0.45, 0.95), "궁수": Color(0.2, 0.7, 0.3), "성기사": Color(0.95, 0.85, 0.3),
	"마법사": Color(0.6, 0.3, 0.9), "전사": Color(0.75, 0.4, 0.2), "기사": Color(0.6, 0.65, 0.75), "도적": Color(0.2, 0.75, 0.75),
	"그림자 병사": Color(0.35, 0.1, 0.4), "그림자 창병": Color(0.45, 0.1, 0.25), "그림자 궁병": Color(0.3, 0.2, 0.45),
	"그림자 술사": Color(0.5, 0.05, 0.5), "그림자 지휘관": Color(0.15, 0.0, 0.15),
	"그림자 중갑병": Color(0.3, 0.3, 0.4), "그림자 기병": Color(0.4, 0.2, 0.1), "그림자 비룡": Color(0.2, 0.3, 0.2)}
## Alternate promotion (branch): class -> second option (first is CLASSES[..][2]).
const ALT_PROMOTE = {"전사": "버서커"}
## Class growth bonuses for NEW classes only (existing classes keep ClassData defaults).
## With default personal growths {10,10,0,10,10,20,5,5} 전사 totals 85/55/0/40/40/30/35/15 (hp/str/mag/skl/spd/lck/def/res).
const GROWTHS = {
	"전사": {"hp": 75, "str": 45, "mag": 0, "skl": 30, "spd": 30, "lck": 10, "def": 30, "res": 10},
	"워리어": {"hp": 75, "str": 45, "mag": 0, "skl": 30, "spd": 30, "lck": 10, "def": 30, "res": 10},
	"버서커": {"hp": 75, "str": 45, "mag": 0, "skl": 30, "spd": 30, "lck": 10, "def": 30, "res": 10},
}
const THIEF_CLASSES = ["도적", "어쌔신"]

static var _cache = {}
static func cls(n: String) -> ClassData:
	if _cache.has(n): return _cache[n]
	var d = CLASSES[n]; var c = ClassData.new(); c.name = n; c.move = d[0]
	if not d[1].is_empty(): c.base_stats = d[1]
	c.weapon_types = d[3]
	if GROWTHS.has(n): c.growth_rates = GROWTHS[n]
	_cache[n] = c
	if d[2] != "": c.promotes_to = cls(d[2])
	return c

static func color_for(class_name_: String) -> Color:
	return COLORS.get(class_name_, COLORS.get(_base_of(class_name_), Color.GRAY))

static func _base_of(promoted: String) -> String:
	for k in CLASSES:
		if CLASSES[k][2] == promoted: return k
	return ""

const CH_INDEX = {"ch1": 0, "ch2": 1, "ch3": 2, "ch4a": 3, "ch4b": 3, "ch5": 4, "ch6": 5, "end": 6}
static func joined_by(chapter: String) -> Array:
	var idx = CH_INDEX.get(chapter, 0)
	var rec = []
	var ml = Engine.get_main_loop()
	var C = ml.root.get_node_or_null("Campaign") if ml is SceneTree else null
	if C: rec = C.recruited + (C.roster.keys() if C.keep_all else [])   # 강화 환생: everyone you had stays
	return UNITS.keys().filter(func(n): return (UNITS[n][1] != "recruit" and CH_INDEX.get(UNITS[n][1], 99) <= idx) or n in rec)
## Recruits join at this level (deterministic fixed-growth level-ups; class base stats untouched).
const JOIN_LV = {"가렌": 5, "카이": 6, "리안": 6, "실라": 7, "아서": 8}

## Build a Unit node from a campaign roster entry (or defaults).
static func make_unit(n: String, team: int, cell: Vector2i, entry = {}) -> Unit:
	var cname: String = entry.get("class", UNITS[n][0]) if team == 0 else n
	var c = cls(cname)
	var d = UnitData.new(); d.name = n; d.unit_class = c; d.color = color_for(cname)
	var u = Unit.new(); u.setup(d, team, cell)
	if team == 0:
		u.inventory = Weapons.loadout(cname)
		if not entry.is_empty(): u.apply_progress(entry)
	return u

static func is_thief(u: Unit) -> bool:
	return u.unit_class.name in THIEF_CLASSES or u.data.name in ["잭", "릴리"]
