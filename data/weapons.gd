class_name Weapons extends RefCounted
## Weapon catalog. [type, might, hit, crit, weight, uses, min_r, max_r, magic, heal]
const T = WeaponData.Type
const LIST = {
	"철검": [T.SWORD, 5, 90, 0, 5, 40, 1, 1, false, 0], "강철검": [T.SWORD, 8, 80, 0, 8, 30, 1, 1, false, 0],
	"은검": [T.SWORD, 12, 85, 5, 6, 20, 1, 1, false, 0],
	"철창": [T.LANCE, 6, 85, 0, 6, 40, 1, 1, false, 0], "강철창": [T.LANCE, 9, 75, 0, 9, 30, 1, 1, false, 0],
	"은창": [T.LANCE, 13, 80, 5, 7, 20, 1, 1, false, 0],
	"철활": [T.BOW, 6, 85, 0, 5, 40, 2, 2, false, 0], "강철활": [T.BOW, 9, 75, 0, 7, 30, 2, 2, false, 0],
	"은활": [T.BOW, 13, 80, 5, 6, 20, 2, 2, false, 0],
	"파이어": [T.TOME, 5, 90, 0, 3, 30, 1, 2, true, 0], "썬더": [T.TOME, 8, 80, 5, 4, 25, 1, 2, true, 0],
	"엘파이어": [T.TOME, 12, 85, 0, 5, 20, 1, 2, true, 0],
	"힐": [T.STAFF, 0, 100, 0, 2, 30, 1, 1, true, 10], "멘드": [T.STAFF, 0, 100, 0, 4, 20, 1, 1, true, 20],
	# enemy-only (not in user's list)
	"철도끼": [T.AXE, 8, 75, 0, 10, 45, 1, 1, false, 0],
}
## Class loadouts (base and promoted).
const LOADOUT = {
	"용병": ["철검"], "도적": ["철검"], "기사": ["철창"], "궁수": ["철활"], "마법사": ["파이어"], "성기사": ["철검", "힐"],
	"세이지": ["파이어", "힐"], "발키리": ["파이어", "힐"], "팔라딘": ["철검", "철창"], "그레이트나이트": ["철검", "철창"],
}

static func make(n: String, uses = -1) -> WeaponData:
	var d = LIST[n]; var w = WeaponData.new()
	w.name = n; w.type = d[0]; w.might = d[1]; w.hit = d[2]; w.crit = d[3]; w.weight = d[4]
	w.max_uses = d[5]; w.uses = d[5] if uses < 0 else uses
	w.min_range = d[6]; w.max_range = d[7]; w.magic = d[8]; w.heal = d[9]
	return w

static func loadout(cls: String) -> Array:
	return LOADOUT.get(cls, ["철검"]).map(func(n): return make(n))
