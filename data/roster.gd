class_name Roster extends RefCounted
## Class + playable unit definitions shared by battle and base screens.
const W = WeaponData.Type
## name: [move, base_stats, promotes_to, weapon_types]   (empty weapon_types = any, used by enemies)
const CLASSES = {
	"용병": [5, {"hp": 20, "str": 6, "mag": 0, "skl": 8, "spd": 8, "lck": 5, "def": 4, "res": 1}, "영웅", [W.SWORD]],
	"궁수": [5, {"hp": 17, "str": 5, "mag": 0, "skl": 7, "spd": 6, "lck": 4, "def": 3, "res": 1}, "스나이퍼", [W.BOW]],
	"시스터": [5, {"hp": 19, "str": 5, "mag": 3, "skl": 5, "spd": 5, "lck": 6, "def": 6, "res": 5}, "성기사", [W.STAFF, W.SWORD]],   # 기본 회복 병종 (구 성기사 수치 그대로)
	# 성기사 = 상급 (기마). base_stats kept only for units that join already promoted (아서) — numbers unchanged.
	"성기사": [7, {"hp": 19, "str": 5, "mag": 3, "skl": 5, "spd": 5, "lck": 6, "def": 6, "res": 5}, "", [W.LANCE, W.SWORD, W.STAFF]],
	"비숍": [5, {}, "", [W.STAFF, W.TOME]],
	"마법사": [5, {"hp": 15, "str": 0, "mag": 7, "skl": 6, "spd": 6, "lck": 3, "def": 1, "res": 6}, "세이지", [W.TOME]],
	# 중갑 계열 (도보, 'armor' → 아머킬러/해머 특효): 아머나이트 → 제네럴. 구 '기사'/'그레이트나이트' 수치 그대로 이름만 변경.
	"아머나이트": [4, {"hp": 22, "str": 7, "mag": 0, "skl": 5, "spd": 3, "lck": 3, "def": 8, "res": 1}, "제네럴", [W.LANCE]],
	# 기마 계열 ('cavalry' → 호스슬레이어 특효): 소셜나이트 → 팔라딘 (이동 7 → 8)
	"소셜나이트": [7, {"hp": 20, "str": 6, "mag": 0, "skl": 6, "spd": 7, "lck": 4, "def": 5, "res": 1}, "팔라딘", [W.SWORD, W.LANCE]],
	# 비행 계열 ('flying' → 활 특효): 비룡기사 → 드래곤마스터
	"비룡기사": [7, {"hp": 22, "str": 8, "mag": 0, "skl": 6, "spd": 7, "lck": 4, "def": 6, "res": 1}, "드래곤마스터", [W.LANCE, W.AXE]],
	"드래곤마스터": [8, {}, "", [W.LANCE, W.AXE, W.SWORD]],
	"도적": [6, {"hp": 16, "str": 4, "mag": 0, "skl": 8, "spd": 10, "lck": 7, "def": 2, "res": 1}, "어쌔신", [W.SWORD]],
	"전사": [5, {"hp": 24, "str": 8, "mag": 0, "skl": 5, "spd": 5, "lck": 3, "def": 5, "res": 0}, "워리어", [W.AXE]],
	"워리어": [6, {}, "", [W.AXE, W.BOW]], "버서커": [6, {}, "", [W.AXE]],
	"영웅": [6, {}, "", [W.SWORD, W.AXE]], "스나이퍼": [6, {}, "", [W.BOW]], "발키리": [6, {}, "", [W.LANCE, W.SWORD, W.TOME, W.STAFF]],
	"세이지": [6, {}, "", [W.TOME, W.STAFF]], "제네럴": [5, {}, "", [W.SWORD, W.LANCE]],
	"팔라딘": [7, {}, "", [W.SWORD, W.LANCE]],
	# 2nd promotion branches (FE8): 그레이트나이트 (아머나이트/소셜나이트 공통, 중갑+기마), 레인저(기마 궁), 메이지나이트(기마 마도), 로그(도적), 드래곤나이트(비행 고속)
	"그레이트나이트": [6, {}, "", [W.SWORD, W.LANCE, W.AXE]], "레인저": [7, {}, "", [W.SWORD, W.BOW]],
	"메이지나이트": [7, {}, "", [W.TOME, W.STAFF]], "로그": [7, {}, "", [W.SWORD]], "드래곤나이트": [8, {}, "", [W.LANCE, W.SWORD]], "어쌔신": [7, {}, "", [W.SWORD]], "검성": [6, {}, "", [W.SWORD]],
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
	"아린": ["용병", "ch1", ""], "노아": ["용병", "ch1", ""], "리나": ["궁수", "ch1", ""], "세라": ["시스터", "ch1", ""],
	"엘리아": ["마법사", "ch1", ""], "카엘": ["아머나이트", "ch1", ""], "루크": ["도적", "ch1", ""], "미라": ["마법사", "ch1", ""],
	"보리스": ["전사", "ch1", "나무만 패던 손이지만, 도끼질이라면 자신 있수다."],
	"에일린": ["용병", "ch2", "노아 선배한테 들었어. 나도 같이 갈게!"],
	"레온": ["아머나이트", "ch2", "방패가 필요하겠지. 앞은 내가 맡겠다."],
	# recruited during the campaign (talk / village / rescue) — join via Campaign.recruited
	"가렌": ["용병", "recruit", "돈보다 나은 이유를 찾았다. 이 검, 맡기지."], "카이": ["궁수", "recruit", "마을을 지켜 준 빚은 화살로 갚지."],
	"리안": ["소셜나이트", "recruit", "살아남은 기사의 몫을 하겠다."], "실라": ["도적", "recruit", "루크 빚까지 내가 갚아 줄게. 농담이야."],
	"그렉": ["전사", "recruit", "숲에서 나무만 패다 보니 도끼는 자신 있수다. 앞은 내가 막지."],
	"카스": ["전사", "recruit", "도끼 한 방에 끝낸다. 느리게 싸우는 건 내 스타일 아니야."],
	"리엘": ["비룡기사", "recruit", "그림자 놈들한테서 도망쳤다. 이 날개로 갚지."],
	# 7장 이후 합류 (해당 장이 생기기 전까지는 데이터만; CH_INDEX에 없음 → 등장 안 함)
	"다린": ["용병", "recruit", "검 하나로 떠돌았지만, 이번엔 지킬 게 생겼군."], "소라": ["궁수", "recruit", "내 화살은 빗나가지 않아. 표적만 정해 줘."],
	"엘렌": ["마법사", "recruit", "책으로만 배운 마법이지만… 실전에서 증명할게요."], "카린": ["도적", "recruit", "자물쇠든 경비든, 나한텐 다 열려 있어."],
	"브록": ["아머나이트", "ch12", "성문 하나쯤은 이 몸으로 막아 주지."], "라임": ["소셜나이트", "ch13", "말 위에서라면 누구보다 빨라. 앞장서지."],
	"미르": ["시스터", "ch14", "다치신 분은 제게 오세요. 끝까지 함께할게요."], "제드": ["전사", "ch15", "궁지에 몰릴수록 도끼가 무거워지지. 좋아."],
	"카이린": ["비룡기사", "recruit", "하늘은 넓다. 리엘 혼자 날게 둘 순 없지."],
	"아서": ["성기사", "ch6", "왕성이 함락됐다. 길은 내가 안다, 따라와!"],
}
const IRON = {W.SWORD: "철검", W.LANCE: "철창", W.AXE: "철도끼", W.BOW: "철활", W.TOME: "파이어", W.STAFF: "힐"}
const COLORS = {"용병": Color(0.2, 0.45, 0.95), "궁수": Color(0.2, 0.7, 0.3), "성기사": Color(0.95, 0.85, 0.3), "시스터": Color(0.95, 0.9, 0.6),
	"마법사": Color(0.6, 0.3, 0.9), "전사": Color(0.75, 0.4, 0.2), "아머나이트": Color(0.6, 0.65, 0.75), "소셜나이트": Color(0.85, 0.6, 0.3), "비룡기사": Color(0.4, 0.6, 0.35), "도적": Color(0.2, 0.75, 0.75),
	"그림자 병사": Color(0.35, 0.1, 0.4), "그림자 창병": Color(0.45, 0.1, 0.25), "그림자 궁병": Color(0.3, 0.2, 0.45),
	"그림자 술사": Color(0.5, 0.05, 0.5), "그림자 지휘관": Color(0.15, 0.0, 0.15),
	"그림자 중갑병": Color(0.3, 0.3, 0.4), "그림자 기병": Color(0.4, 0.2, 0.1), "그림자 비룡": Color(0.2, 0.3, 0.2)}
## Alternate promotion (branch): class -> second option (first is CLASSES[..][2]).
const ALT_PROMOTE = {"전사": "버서커", "시스터": "비숍", "용병": "검성", "궁수": "레인저", "마법사": "메이지나이트", "도적": "로그",
	"아머나이트": "그레이트나이트", "소셜나이트": "그레이트나이트", "비룡기사": "드래곤나이트"}
## Class growth bonuses for NEW classes only (existing classes keep ClassData defaults).
## With default personal growths {10,10,0,10,10,20,5,5} 전사 totals 85/55/0/40/40/30/35/15 (hp/str/mag/skl/spd/lck/def/res).
const GROWTHS = {
	"전사": {"hp": 75, "str": 45, "mag": 0, "skl": 30, "spd": 30, "lck": 10, "def": 30, "res": 10},
	"워리어": {"hp": 75, "str": 45, "mag": 0, "skl": 30, "spd": 30, "lck": 10, "def": 30, "res": 10},
	"버서커": {"hp": 75, "str": 45, "mag": 0, "skl": 30, "spd": 30, "lck": 10, "def": 30, "res": 10},
}
const THIEF_CLASSES = ["도적", "어쌔신", "로그"]

## Promotion branches (first = CLASSES[..][2]).
static func branches(base: String) -> Array:
	if not CLASSES.has(base) or CLASSES[base][2] == "": return []
	var out = [CLASSES[base][2]]
	if ALT_PROMOTE.has(base): out.append(ALT_PROMOTE[base])
	return out

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
		if promoted in branches(k): return k
	return ""

const CH_INDEX = {"ch1": 0, "ch2": 1, "ch3": 2, "ch4a": 3, "ch4b": 3, "ch5": 4, "ch6": 5, "ch7": 6, "ch8": 7, "ch9": 8, "ch10": 9, "end": 10}
static func joined_by(chapter: String) -> Array:
	var idx = CH_INDEX.get(chapter, 0)
	var rec = []
	var ml = Engine.get_main_loop()
	var C = ml.root.get_node_or_null("Campaign") if ml is SceneTree else null
	if C: rec = C.recruited + (C.roster.keys() if C.keep_all else [])   # 강화 환생: everyone you had stays
	return UNITS.keys().filter(func(n): return (UNITS[n][1] != "recruit" and CH_INDEX.get(UNITS[n][1], 99) <= idx) or n in rec)
## Recruits join at this level (deterministic fixed-growth level-ups; class base stats untouched).
const JOIN_LV = {"다린": 5, "소라": 6, "엘렌": 6, "카린": 7, "브록": 8, "라임": 8, "미르": 7, "제드": 9, "카이린": 10, "그렉": 4, "카스": 6, "리엘": 8, "레온": 3, "가렌": 5, "카이": 6, "리안": 6, "실라": 7, "아서": 8}

## Personal base-stat offsets (new units only; existing units have none) and personal growths (default UnitData otherwise).
const UNIT_LOADOUT = {"그렉": ["철도끼", "상처약"], "카스": ["손도끼", "철도끼"], "리엘": ["철창", "철도끼"]}
const PERSONAL_BASE = {"그렉": {"hp": 3, "def": 2, "spd": -2}, "카스": {"skl": 3, "spd": 1, "def": -2},
	"다린": {"skl": 1, "spd": 1}, "소라": {"skl": 2, "lck": 2}, "엘렌": {"res": 2}, "카린": {"spd": 1, "lck": 2}, "브록": {"hp": 2, "def": 1, "spd": -1},
	"라임": {"spd": 1}, "미르": {"res": 2, "mag": 1}, "제드": {"hp": 3, "str": 1, "skl": -1}, "카이린": {"str": 1, "def": 1, "spd": -1}}
const PERSONAL_GROWTH = {
	"그렉": {"hp": 20, "str": 10, "mag": 0, "skl": 5, "spd": 0, "lck": 10, "def": 15, "res": 0},
	"카스": {"hp": 5, "str": 10, "mag": 0, "skl": 20, "spd": 15, "lck": 15, "def": 0, "res": 0},
	"리엘": {"hp": 10, "str": 10, "mag": 0, "skl": 10, "spd": 15, "lck": 10, "def": 5, "res": 5},
	"다린": {"hp": 10, "str": 10, "mag": 0, "skl": 15, "spd": 15, "lck": 10, "def": 5, "res": 5},
	"소라": {"hp": 5, "str": 10, "mag": 0, "skl": 20, "spd": 10, "lck": 15, "def": 5, "res": 5},
	"엘렌": {"hp": 5, "str": 0, "mag": 15, "skl": 10, "spd": 10, "lck": 10, "def": 0, "res": 15},
	"카린": {"hp": 5, "str": 5, "mag": 0, "skl": 15, "spd": 20, "lck": 20, "def": 0, "res": 5},
	"브록": {"hp": 15, "str": 10, "mag": 0, "skl": 5, "spd": 5, "lck": 5, "def": 15, "res": 0},
	"라임": {"hp": 10, "str": 10, "mag": 0, "skl": 10, "spd": 15, "lck": 10, "def": 5, "res": 5},
	"미르": {"hp": 5, "str": 0, "mag": 15, "skl": 5, "spd": 10, "lck": 15, "def": 0, "res": 20},
	"제드": {"hp": 20, "str": 15, "mag": 0, "skl": 5, "spd": 5, "lck": 5, "def": 5, "res": 0},
	"카이린": {"hp": 10, "str": 10, "mag": 0, "skl": 5, "spd": 10, "lck": 5, "def": 10, "res": 5},
}
static func apply_personal(u: Unit) -> void:
	var n = u.data.name
	if PERSONAL_GROWTH.has(n): u.data.personal_growths = PERSONAL_GROWTH[n]
	for s in PERSONAL_BASE.get(n, {}): u.stats[s] += PERSONAL_BASE[n][s]
	u.hp = u.stats.hp

## Build a Unit node from a campaign roster entry (or defaults).
static func make_unit(n: String, team: int, cell: Vector2i, entry = {}) -> Unit:
	var cname: String = entry.get("class", UNITS[n][0]) if team == 0 else n
	var c = cls(cname)
	var d = UnitData.new(); d.name = n; d.unit_class = c; d.color = color_for(cname)
	var u = Unit.new(); u.setup(d, team, cell)
	if team == 0:
		u.inventory = Weapons.loadout(cname)
		if Roster.PERSONAL_GROWTH.has(n): u.data.personal_growths = PERSONAL_GROWTH[n]
		if entry.is_empty(): apply_personal(u)
		else: u.apply_progress(entry)
		if UNIT_LOADOUT.has(n) and entry.is_empty(): u.inventory = UNIT_LOADOUT[n].map(func(x): return Weapons.make(x))
	return u

static func is_thief(u: Unit) -> bool:
	return u.unit_class.name in THIEF_CLASSES or u.data.name in ["잭", "릴리"]
