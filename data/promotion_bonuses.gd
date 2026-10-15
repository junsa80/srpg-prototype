class_name PromotionBonuses extends RefCounted
## FINAL promotion bonuses (applied at promotion, Lv10). Keys: hp str mag skl spd lck def res move.
const TABLE = {
	"워리어": {"hp": 3, "str": 2, "skl": 2, "def": 2}, "버서커": {"hp": 4, "str": 3, "skl": 1, "spd": 2},
	"영웅": {"hp": 4, "str": 2, "skl": 2, "def": 2},
	"검성": {"hp": 3, "skl": 3, "spd": 3, "lck": 2},
	"팔라딘": {"hp": 4, "str": 2, "def": 2, "move": 1},
	"제네럴": {"hp": 5, "str": 3, "def": 3},   # 이동 5 (구 그레이트나이트 +1 제거: 사용자 확정값)
	"스나이퍼": {"hp": 3, "str": 2, "skl": 3, "spd": 1},
	"레인저": {"hp": 2, "skl": 3, "spd": 3, "lck": 2},
	"세이지": {"hp": 3, "mag": 3, "skl": 2, "res": 2},
	"메이지나이트": {"hp": 3, "mag": 2, "spd": 2, "res": 2, "move": 1},
	"어쌔신": {"hp": 2, "skl": 3, "spd": 3, "lck": 3},
	"로그": {"hp": 2, "skl": 2, "spd": 4, "lck": 3},
	"성기사": {"hp": 4, "str": 2, "def": 2, "res": 1},   # 이동 7은 클래스 자체 값   # 시스터 → 기마: 이동 6(+1)
	"비숍": {"hp": 3, "mag": 3, "skl": 1, "res": 3},
	"드래곤마스터": {"hp": 4, "str": 2, "spd": 1, "def": 2},
	"그레이트나이트": {"hp": 3, "str": 2, "skl": 2, "spd": 2, "def": 1, "res": 1},   # FE8 그레이트나이트 기준
	"드래곤나이트": {"hp": 3, "str": 1, "skl": 3, "spd": 3, "def": 1, "res": 1},
	"발키리": {"hp": 3, "mag": 2, "skl": 2, "res": 3, "move": 1},
}
static func for_class(n: String) -> Dictionary: return TABLE.get(n, {})
