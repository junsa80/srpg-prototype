class_name ClassCaps extends RefCounted
## Stat caps per class (GBA FE6/FE8 style). Order: hp str mag skl spd lck def res.
## Base classes: HP 35-45, others ~12-22 (FE8 unpromoted caps are 20). Promoted: HP 60, others ~20-30 (FE8 promoted caps).
## Level: every class Lv1-20; base classes promote at Lv10-20 (level resets to 1).
const MAX_LEVEL = 20
const PROMOTE_MIN_LV = 10
static func _c(a: Array) -> Dictionary:
	return {"hp": a[0], "str": a[1], "mag": a[2], "skl": a[3], "spd": a[4], "lck": a[5], "def": a[6], "res": a[7]}
const RAW = {
	# base classes
	"용병": [40, 18, 5, 20, 20, 30, 16, 15], "궁수": [40, 18, 5, 20, 18, 30, 16, 15],
	"시스터": [38, 14, 18, 18, 18, 30, 15, 20], "마법사": [35, 8, 20, 18, 18, 30, 12, 20],
	"아머나이트": [45, 20, 5, 16, 15, 30, 22, 14], "소셜나이트": [40, 18, 5, 18, 20, 30, 16, 15],
	"비룡기사": [42, 20, 5, 18, 19, 30, 18, 10], "도적": [35, 14, 5, 20, 20, 30, 12, 15], "전사": [45, 20, 5, 16, 16, 30, 15, 12],
	# promoted (FE8 promoted caps, our names)
	"영웅": [60, 25, 10, 30, 26, 30, 25, 22], "검성": [60, 24, 10, 29, 30, 30, 22, 23],
	"스나이퍼": [60, 25, 10, 30, 28, 30, 25, 25], "레인저": [60, 25, 10, 28, 30, 30, 24, 24],
	"세이지": [60, 15, 30, 28, 26, 30, 21, 25], "메이지나이트": [60, 15, 25, 24, 25, 30, 24, 25],
	"비숍": [60, 15, 25, 26, 24, 30, 22, 30], "성기사": [60, 25, 18, 26, 24, 30, 25, 25], "발키리": [60, 15, 25, 24, 25, 30, 24, 25],
	"제네럴": [60, 29, 10, 27, 24, 30, 30, 25], "그레이트나이트": [60, 29, 10, 27, 24, 30, 28, 25],
	"팔라딘": [60, 25, 10, 26, 24, 30, 25, 25],
	"드래곤마스터": [60, 27, 10, 25, 23, 30, 28, 22], "드래곤나이트": [60, 25, 10, 26, 28, 30, 24, 22],
	"워리어": [60, 30, 10, 28, 26, 30, 26, 22], "버서커": [60, 30, 10, 29, 30, 30, 23, 21],
	"어쌔신": [60, 20, 10, 30, 30, 30, 20, 20], "로그": [60, 20, 10, 30, 30, 30, 20, 20],
}
## Shadow enemies use the matching player class caps; bosses (바르가스, 그림자 지휘관, named bosses) are exempt.
const ENEMY_AS = {"그림자 병사": "전사", "그림자 창병": "아머나이트", "그림자 궁병": "궁수", "그림자 술사": "마법사",
	"그림자 중갑병": "아머나이트", "그림자 기병": "소셜나이트", "그림자 비룡": "비룡기사"}

static func caps(class_name_: String) -> Dictionary:
	var n = ENEMY_AS.get(class_name_, class_name_)
	return _c(RAW[n]) if RAW.has(n) else {}

static func cap(class_name_: String, s: String) -> int:
	return int(caps(class_name_).get(s, 999))

## Promoted-class minimum = base class Lv1 base + promotion bonus (lowest over all base classes leading here).
static func mins(promoted: String) -> Dictionary:
	var out = {}
	for b in Roster.CLASSES:
		if not promoted in Roster.branches(b): continue
		var base: Dictionary = Roster.CLASSES[b][1]; var bon = PromotionBonuses.for_class(promoted)
		for s in base:
			var v = int(base[s]) + int(bon.get(s, 0))
			out[s] = mini(out.get(s, 999), v)
	return out

## Clamp a unit's stats to its class caps (returns {stat: lost}).
static func clamp_unit(u) -> Dictionary:
	var lost = {}
	if u.boss: return lost
	var c = caps(u.unit_class.name)
	for s in c:
		if u.stats.get(s, 0) > c[s]: lost[s] = u.stats[s] - c[s]; u.stats[s] = c[s]
	u.hp = mini(u.hp, u.stats.hp)
	return lost
