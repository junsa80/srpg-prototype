class_name ClassProfs extends RefCounted
## Class weapon proficiency (observe-only on stats: base stats/growths live in roster.gd and are untouched).
## PROF[class][type] = bonus applied when that class fights with that weapon type.
const W = WeaponData.Type
const PROF = {
	"용병": {W.SWORD: {"hit": 10}},                                   # 검 전문: 명중 +10
	"궁수": {W.BOW: {"hit": 5}},
	"성기사": {W.SWORD: {}, W.STAFF: {"heal": 2}},                    # 검은 무난, 지팡이 회복 +2
	"마법사": {W.TOME: {"hit": 5}},
	"기사": {W.LANCE: {"might": 1, "hit": 5}},                        # 창 전문
	"도적": {W.SWORD: {"crit": 10}},                                 # 경량 검만, 치명 +10
	"영웅": {W.SWORD: {"hit": 10, "crit": 5}, W.AXE: {}},
	"스나이퍼": {W.BOW: {"hit": 10, "crit": 10}},
	"발키리": {W.SWORD: {"hit": 5}, W.TOME: {"hit": 5}, W.STAFF: {"heal": 3}},
	"세이지": {W.TOME: {"hit": 10, "might": 1}, W.STAFF: {"heal": 3}},
	"그레이트나이트": {W.LANCE: {"might": 2, "hit": 5}, W.SWORD: {}},
	"팔라딘": {W.SWORD: {"hit": 5}, W.LANCE: {"hit": 5}},
	"어쌔신": {W.SWORD: {"crit": 20}},
	"검성": {W.SWORD: {"hit": 15, "crit": 10}},
}
## Classes that may only use light weapons of a type (weight <= LIGHT_WT or light trait).
const LIGHT_ONLY = {"도적": [W.SWORD]}
const LIGHT_WT = 6
## Starting weapon ranks (0=E..5=S). Promoted classes broaden: new types start at these ranks.
const START_RANK = {
	"용병": {W.SWORD: 1}, "궁수": {W.BOW: 1}, "성기사": {W.SWORD: 0, W.STAFF: 1}, "마법사": {W.TOME: 1},
	"기사": {W.LANCE: 1}, "도적": {W.SWORD: 0},
	"영웅": {W.SWORD: 2, W.AXE: 1}, "스나이퍼": {W.BOW: 2}, "발키리": {W.SWORD: 1, W.TOME: 1, W.STAFF: 2},
	"세이지": {W.TOME: 2, W.STAFF: 1}, "그레이트나이트": {W.LANCE: 2, W.SWORD: 1}, "팔라딘": {W.SWORD: 1, W.LANCE: 1},
	"어쌔신": {W.SWORD: 2}, "검성": {W.SWORD: 3},
}
## Unit tags for weapon effectiveness.
const TAGS = {"기사": ["armor"], "그레이트나이트": ["armor"], "팔라딘": ["cavalry"], "발키리": ["cavalry"],
	"그림자 중갑병": ["armor"], "그림자 기병": ["cavalry"], "그림자 비룡": ["flying"], "그림자 지휘관": ["armor"], "바르가스": ["armor"],
	"그림자 기사": ["armor", "cavalry"], "그림자 비룡기사": ["flying"]}
## Weapon EXP thresholds for E D C B A S.
const WEXP = [0, 30, 70, 120, 180, 250]
const WEXP_PER_COMBAT = 4
const WEXP_PER_HEAL = 5
## Rank bonuses (might, hit, crit) — shown in forecast.
const RANK_BONUS = [[0, 0, 0], [0, 0, 0], [0, 5, 0], [1, 5, 0], [2, 10, 5], [3, 15, 5]]

static func prof(cls: String, t: int) -> Dictionary: return PROF.get(cls, {}).get(t, {})
static func tags(cls: String) -> Array: return TAGS.get(cls, [])
static func rank_of(points: int) -> int:
	var r = 0
	for i in WEXP.size(): if points >= WEXP[i]: r = i
	return r
