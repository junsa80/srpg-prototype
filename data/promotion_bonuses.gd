class_name PromotionBonuses extends RefCounted
## FINAL promotion bonuses (applied at promotion, Lv10). Keys: hp str mag skl spd lck def res move.
const TABLE = {
	"워리어": {"hp": 3, "str": 2, "skl": 2, "def": 2}, "버서커": {"hp": 4, "str": 3, "skl": 1, "spd": 2},
	"영웅": {"hp": 4, "str": 2, "skl": 2, "def": 2},
	"검성": {"hp": 3, "skl": 3, "spd": 3, "lck": 2},
	"팔라딘": {"hp": 4, "str": 2, "def": 2, "move": 1},
	"그레이트나이트": {"hp": 5, "str": 3, "def": 3, "move": 1},
	"스나이퍼": {"hp": 3, "str": 2, "skl": 3, "spd": 1},
	"레인저": {"hp": 2, "skl": 3, "spd": 3, "lck": 2},
	"세이지": {"hp": 3, "mag": 3, "skl": 2, "res": 2},
	"메이지나이트": {"hp": 3, "mag": 2, "spd": 2, "res": 2, "move": 1},
	"어쌔신": {"hp": 2, "skl": 3, "spd": 3, "lck": 3},
	"로그": {"hp": 2, "skl": 2, "spd": 4, "lck": 3},
	"발키리": {"hp": 3, "mag": 2, "skl": 2, "res": 3, "move": 1},
}
static func for_class(n: String) -> Dictionary: return TABLE.get(n, {})
