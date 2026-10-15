class_name Weapons extends RefCounted
## Weapon catalog. [type, might, hit, crit, weight, uses, min_r, max_r, magic, heal]
## The first 14 entries are the user's base weapons — numbers unchanged; roles come from TRAITS below.
const T = WeaponData.Type
const LIST = {
	"철단검": [T.SWORD, 4, 95, 10, 2, 40, 1, 1, false, 0], "강철단검": [T.SWORD, 7, 90, 15, 4, 30, 1, 1, false, 0],
	"철검": [T.SWORD, 5, 90, 0, 5, 40, 1, 1, false, 0], "강철검": [T.SWORD, 8, 80, 0, 8, 30, 1, 1, false, 0],
	"은검": [T.SWORD, 12, 85, 5, 6, 20, 1, 1, false, 0],
	"철창": [T.LANCE, 6, 85, 0, 6, 40, 1, 1, false, 0], "강철창": [T.LANCE, 9, 75, 0, 9, 30, 1, 1, false, 0],
	"은창": [T.LANCE, 13, 80, 5, 7, 20, 1, 1, false, 0],
	"철활": [T.BOW, 6, 85, 0, 5, 40, 2, 2, false, 0], "강철활": [T.BOW, 9, 75, 0, 7, 30, 2, 2, false, 0],
	"은활": [T.BOW, 13, 80, 5, 6, 20, 2, 2, false, 0],
	"파이어": [T.TOME, 5, 90, 0, 3, 30, 1, 2, true, 0], "썬더": [T.TOME, 8, 80, 5, 4, 25, 1, 2, true, 0],
	"엘파이어": [T.TOME, 12, 85, 0, 5, 20, 1, 2, true, 0],
	"라이트": [T.TOME, 4, 95, 5, 2, 35, 1, 2, true, 0],
	"힐": [T.STAFF, 0, 100, 0, 2, 30, 1, 1, true, 10], "멘드": [T.STAFF, 0, 100, 0, 4, 20, 1, 1, true, 20],
	# enemy-only base
	"철도끼": [T.AXE, 8, 75, 0, 10, 45, 1, 1, false, 0],
	# ---- utility weapons (new)
	"레이피어": [T.SWORD, 7, 95, 10, 5, 25, 1, 1, false, 0],
	"아머킬러": [T.SWORD, 8, 80, 0, 11, 20, 1, 1, false, 0],
	"킬러소드": [T.SWORD, 7, 75, 30, 7, 20, 1, 1, false, 0],
	"용사의 검": [T.SWORD, 9, 75, 0, 9, 30, 1, 1, false, 0],
	"윈드소드": [T.SWORD, 7, 70, 0, 9, 25, 1, 2, true, 0],
	"호스슬레이어": [T.LANCE, 7, 70, 0, 13, 16, 1, 1, false, 0],
	"투창": [T.LANCE, 6, 65, 0, 11, 20, 1, 2, false, 0],
	"킬러랜스": [T.LANCE, 8, 70, 30, 9, 20, 1, 1, false, 0],
	"용사의 창": [T.LANCE, 10, 70, 0, 14, 30, 1, 1, false, 0],
	"손도끼": [T.AXE, 7, 60, 0, 9, 20, 1, 2, false, 0],
	"강철도끼": [T.AXE, 11, 65, 0, 15, 30, 1, 1, false, 0],
	"해커": [T.AXE, 11, 65, 30, 11, 20, 1, 1, false, 0],
	"해머": [T.AXE, 10, 55, 0, 15, 20, 1, 1, false, 0],
	"킬러보우": [T.BOW, 9, 75, 30, 7, 20, 2, 2, false, 0],
	"볼트": [T.TOME, 6, 80, 0, 5, 20, 1, 2, true, 0],
	"피지오": [T.STAFF, 0, 100, 0, 3, 15, 1, 4, true, 10],
	# boss uniques
	"그림자 창 우르": [T.LANCE, 11, 80, 10, 10, 30, 1, 1, false, 0],
	"파멸의 도끼": [T.AXE, 13, 70, 5, 14, 30, 1, 1, false, 0],
	# ---- items (T.ITEM: never equipped; effect in ITEMS)
	"상처약": [T.ITEM, 0, 0, 0, 1, 3, 0, 0, false, 10], "엘릭서": [T.ITEM, 0, 0, 0, 1, 1, 0, 0, false, 99],
	"문 열쇠": [T.ITEM, 0, 0, 0, 1, 1, 0, 0, false, 0], "상자 열쇠": [T.ITEM, 0, 0, 0, 1, 1, 0, 0, false, 0],
	"마스터 키": [T.ITEM, 0, 0, 0, 1, 3, 0, 0, false, 0], "해제의 지팡이": [T.ITEM, 0, 0, 0, 1, 2, 1, 5, false, 0],
	"힘의 반지": [T.ITEM, 0, 0, 0, 1, 1, 0, 0, false, 0], "스피드링": [T.ITEM, 0, 0, 0, 1, 1, 0, 0, false, 0],
	"여신의 상": [T.ITEM, 0, 0, 0, 1, 1, 0, 0, false, 0], "드래곤 실드": [T.ITEM, 0, 0, 0, 1, 1, 0, 0, false, 0],
}
## Item effects. key: "door"/"chest"/"both" (any holder can open; thieves still open free). heal: HP restored.
## stat: permanent +n (rare boosters). icon: key/potion/ring/staff.
const ITEMS = {
	"상처약": {"heal": 10, "icon": "potion", "desc": "HP 10 회복 (3회)"}, "엘릭서": {"heal": 99, "icon": "potion", "desc": "HP 전부 회복"},
	"문 열쇠": {"key": "door", "icon": "key", "desc": "인접한 문 1개를 연다"}, "상자 열쇠": {"key": "chest", "icon": "key", "desc": "보물상자 1개를 연다"},
	"마스터 키": {"key": "both", "icon": "key", "desc": "문·상자를 연다 (3회)"}, "해제의 지팡이": {"key": "both", "range": 5, "icon": "staff", "desc": "5칸 이내 문·상자를 연다 (2회)"},
	"힘의 반지": {"stat": "str", "n": 2, "icon": "ring", "desc": "힘 +2 (영구)"}, "스피드링": {"stat": "spd", "n": 2, "icon": "ring", "desc": "속도 +2 (영구)"},
	"여신의 상": {"stat": "hp", "n": 5, "icon": "ring", "desc": "최대 HP +5 (영구)"}, "드래곤 실드": {"stat": "def", "n": 2, "icon": "ring", "desc": "수비 +2 (영구)"},
}
## Roles. rank: required weapon rank (0=E..5=S). eff: target tags (might x3). brave: strikes twice.
## light: weight never lowers attack speed. heavy: high might, slows. desc: shown in UI.
const TRAITS = {
	"철단검": {"rank": 0, "light": true, "dagger": true, "desc": "단검: 가볍고 치명이 잘 난다."}, "강철단검": {"rank": 1, "light": true, "dagger": true, "desc": "단검: 위력↑, 여전히 가볍다."},
	"철검": {"rank": 0, "desc": "기본 검. 가볍고 다루기 쉽다."},
	"강철검": {"rank": 1, "heavy": true, "desc": "무겁다: 위력↑ 공속↓"},
	"은검": {"rank": 3, "desc": "고급 검. 높은 위력."},
	"철창": {"rank": 0, "desc": "기본 창."},
	"강철창": {"rank": 1, "heavy": true, "desc": "무겁다: 위력↑ 공속↓"},
	"은창": {"rank": 3, "desc": "고급 창. 높은 위력."},
	"철활": {"rank": 0, "eff": ["flying"], "desc": "비행 특효"},
	"강철활": {"rank": 1, "eff": ["flying"], "heavy": true, "desc": "비행 특효 · 무겁다"},
	"은활": {"rank": 3, "eff": ["flying"], "desc": "비행 특효 · 고급"},
	"파이어": {"rank": 0, "desc": "기본 마법. 사거리 1-2."},
	"라이트": {"rank": 0, "light": true, "desc": "빛 마법. 가볍고 정확하다."},
	"썬더": {"rank": 1, "desc": "치명 +5 마법."},
	"엘파이어": {"rank": 2, "desc": "강력한 화염 마법."},
	"힐": {"rank": 0, "desc": "인접 아군 HP 10+마력 회복"},
	"멘드": {"rank": 2, "desc": "인접 아군 HP 20+마력 회복"},
	"철도끼": {"rank": 0, "heavy": true, "desc": "무겁다"},
	"레이피어": {"rank": 2, "light": true, "eff": ["armor", "cavalry"], "desc": "경량 · 중갑/기병 특효"},
	"아머킬러": {"rank": 2, "eff": ["armor"], "desc": "중갑 특효"},
	"킬러소드": {"rank": 2, "desc": "치명 +30"},
	"용사의 검": {"rank": 4, "brave": true, "desc": "용사: 공격 시 2회 연속 공격"},
	"윈드소드": {"rank": 1, "desc": "마법 검: 사거리 1-2, 마력으로 공격(마방 판정)"},
	"호스슬레이어": {"rank": 2, "eff": ["cavalry"], "heavy": true, "desc": "기병 특효 · 무겁다"},
	"투창": {"rank": 1, "desc": "투척: 사거리 1-2"},
	"킬러랜스": {"rank": 2, "desc": "치명 +30"},
	"용사의 창": {"rank": 4, "brave": true, "heavy": true, "desc": "용사: 2회 연속 공격 · 무겁다"},
	"강철도끼": {"rank": 1, "heavy": true, "desc": "무겁지만 강하다"}, "해커": {"rank": 2, "desc": "치명 +30"},
	"손도끼": {"rank": 0, "desc": "투척: 사거리 1-2"},
	"해머": {"rank": 1, "eff": ["armor"], "heavy": true, "desc": "중갑 특효 · 무겁다"},
	"킬러보우": {"rank": 2, "eff": ["flying"], "desc": "비행 특효 · 치명 +30"},
	"볼트": {"rank": 2, "eff": ["armor"], "light": true, "desc": "경량 마법 · 중갑 특효"},
	"피지오": {"rank": 2, "desc": "원거리 회복: 사거리 1-4, 10+마력"},
	"그림자 창 우르": {"rank": 3, "eff": ["cavalry"], "desc": "지휘관의 창 · 기병 특효"},
	"파멸의 도끼": {"rank": 3, "eff": ["armor", "cavalry"], "heavy": true, "desc": "바르가스의 도끼 · 중갑/기병 특효"},
}
const RANKS = ["E", "D", "C", "B", "A", "S"]
const TYPE_NAMES = {0: "검", 1: "창", 2: "도끼", 3: "활", 4: "마법", 5: "지팡이", 6: "아이템"}
const TAG_NAMES = {"armor": "중갑", "cavalry": "기마", "flying": "비행"}

## Class loadouts (base and promoted).
const LOADOUT = {
	"용병": ["철검", "상처약"], "도적": ["철단검", "상처약"], "아머나이트": ["철창", "상처약"], "소셜나이트": ["철검", "철창"], "비룡기사": ["철창", "철도끼"], "드래곤마스터": ["철창", "철도끼"], "궁수": ["철활", "상처약"], "마법사": ["파이어", "상처약"], "전사": ["철도끼", "상처약"], "워리어": ["철도끼"], "버서커": ["철도끼"], "시스터": ["힐", "철단검"], "성기사": ["철검", "철창", "힐"], "비숍": ["라이트", "힐"], "어쌔신": ["철단검"],
	"세이지": ["파이어", "힐"], "발키리": ["파이어", "힐"], "팔라딘": ["철검", "철창"], "제네럴": ["철검", "철창"],
}

static func make(n: String, uses = -1) -> WeaponData:
	var d = LIST[n]; var w = WeaponData.new()
	w.name = n; w.type = d[0]; w.might = d[1]; w.hit = d[2]; w.crit = d[3]; w.weight = d[4]
	w.max_uses = d[5]; w.uses = d[5] if uses < 0 else uses
	w.min_range = d[6]; w.max_range = d[7]; w.magic = d[8]; w.heal = d[9]
	var t: Dictionary = TRAITS.get(n, {})
	w.rank = t.get("rank", 0); w.effective = t.get("eff", []); w.brave = t.get("brave", false)
	w.light = t.get("light", false); w.dagger = t.get("dagger", false); w.heavy = t.get("heavy", false); w.desc = t.get("desc", ITEMS.get(n, {}).get("desc", ""))
	return w

static func loadout(cls: String) -> Array:
	return LOADOUT.get(cls, ["철검"]).map(func(n): return make(n))

## One-line role text with effectiveness tags, e.g. "[C] 중갑/기병 특효 · 경량".
static func effect_text(w: WeaponData) -> String:
	if w.is_item(): return "아이템"
	var parts = ["필요 %s" % RANKS[w.rank]]
	if not w.effective.is_empty(): parts.append("특효:" + "/".join(w.effective.map(func(t): return TAG_NAMES.get(t, t))))
	if w.brave: parts.append("용사")
	if w.light: parts.append("경량")
	if w.heavy: parts.append("중량")
	if w.max_range > 1 and w.type in [T.SWORD, T.LANCE, T.AXE]: parts.append("1-%d" % w.max_range)
	if w.type == T.SWORD and w.magic: parts.append("마법검")
	return " · ".join(parts)
