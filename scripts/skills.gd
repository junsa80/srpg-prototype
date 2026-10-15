class_name Skills extends RefCounted
## 36 personal skills, keyed by unit name. Combat hooks are queried by BattleManager.
## status: "impl" = mechanically implemented, "data" = description only.
const LIST = {
	"아린": ["10% 확률 추격 (공속 우위이나 추격 불가 시)", "impl"],
	"노아": ["치명타 피해 +3", "impl"], "카이": ["회피 +5", "impl"], "레온": ["인접 아군 방어 +2", "impl"],
	"실라": ["공속 우위 시 방어 중에도 선공", "impl"], "드레이크": ["받는 물리 피해 -2", "impl"],
	"카엘": ["이동 후 공격 시 명중 +10", "impl"], "가렌": ["방어 +3, 속도 -1", "impl"], "엘런": ["이동 +1", "impl"],
	"브렌": ["근접 공격에 방어 +2", "impl"], "리안": ["창 명중 +10", "impl"], "토르": ["방어 무시 +2 피해", "impl"],
	"리나": ["명중 +10", "impl"], "에일린": ["15% 확률 추격 (공속 우위이나 추격 불가 시)", "impl"],
	"마크": ["치명 +10", "impl"], "세라핀": ["속도 +2", "impl"], "하론": ["적 방어 30% 무시", "impl"],
	"리엘": ["숲에서 회피 +10", "impl"], "엘리아": ["마력 +2", "impl"], "미라": ["마법 무게 패널티 -2", "impl"],
	"오르린": ["전투 중 대상 마방 -3", "impl"], "루나": ["전투 중 2번째 타격 위력 +2", "impl"],
	"카이젠": ["자기 턴 시작부터 마방 +2", "impl"], "아리아": ["마법 피해의 20% 회복", "impl"],
	"루크": ["치명 +15", "impl"], "보리스": ["도끼 장비 시 명중 +10 (나무꾼)", "impl"], "섀도우": ["이동 +1, 회피 +5", "impl"], "잭": ["보물 탐지 +1", "data"],
	"니아": ["방어 시 선공, 회피 +5", "impl"], "벤": ["명중 시 20% 독 (턴 시작 HP-3, 3턴)", "impl"],
	"릴리": ["해제 범위 +1", "data"], "세라": ["턴 종료 시 인접 아군 HP 5 회복", "impl"],
	"아이린": ["'dark' 적에게 마법 피해 +3", "impl"], "가브리엘": ["인접 아군 방어 +1, 마방 +1", "impl"],
	"루미나": ["받는 마법 피해 -2", "impl"], "아서": ["먼저 공격 시 피해 +2", "impl"],
	"셀레나": ["2칸 내 아군 명중 +5, 회피 +5", "impl"],
	"그렉": ["받는 물리 피해 -1 (나무꾼 체력)", "impl"], "카스": ["도끼 치명 +15", "impl"],
}
static var units: Array = []   # set by chapter for aura checks
static var grid = null          # set by chapter for terrain checks

static func has(u: Unit, n: String) -> bool: return u.data.name == n

static func _dist(a: Unit, b: Unit) -> int: return abs(a.cell.x - b.cell.x) + abs(a.cell.y - b.cell.y)

static func _allies_with(u: Unit, skill: String, max_d: int) -> bool:
	for o in units:
		if o != u and o.hp > 0 and o.team == u.team and o.data.name == skill and _dist(o, u) <= max_d: return true
	return false

## Passive stat mods (always on).
static func stat_mod(u: Unit, s: String) -> int:
	var m = 0
	if has(u, "가렌"): m += {"def": 3, "spd": -1}.get(s, 0)
	if has(u, "세라핀") and s == "spd": m += 2
	if has(u, "엘리아") and s == "mag": m += 2
	if has(u, "카이젠") and s == "res" and u.flags.get("kaizen", false): m += 2
	if s == "def" and _allies_with(u, "레온", 1): m += 2
	if s in ["def", "res"] and _allies_with(u, "가브리엘", 1): m += 1
	return m

static func move_mod(u: Unit) -> int: return 1 if has(u, "엘런") or has(u, "섀도우") else 0

static func hit_mod(a: Unit, d: Unit) -> int:
	var m = 0
	if has(a, "리나"): m += 10
	if has(a, "보리스") and a.weapon() and a.weapon().type == WeaponData.Type.AXE: m += 10
	if has(a, "카엘") and a.flags.get("moved", false): m += 10
	if has(a, "리안") and a.weapon() and a.weapon().type == WeaponData.Type.LANCE: m += 10
	if _allies_with(a, "셀레나", 2): m += 5
	return m

static func avo_mod(d: Unit) -> int:
	var m = 0
	if has(d, "카이") or has(d, "섀도우") or has(d, "니아"): m += 5
	if has(d, "리엘") and grid and grid.is_forest(d.cell): m += 10
	if _allies_with(d, "셀레나", 2): m += 5
	return m

static func crit_mod(a: Unit) -> int:
	return (10 if has(a, "마크") else 0) + (15 if has(a, "루크") else 0) + (15 if has(a, "카스") and a.weapon() and a.weapon().type == WeaponData.Type.AXE else 0)

## Defense used against attacker a (after reductions).
static func defense_vs(a: Unit, d: Unit, magic: bool) -> int:
	var v = d.eff("res") if magic else d.eff("def")
	if grid: v += grid.terrain_bonus(d.cell)[0]
	if magic and has(a, "오르린"): v -= 3
	if not magic and has(d, "브렌") and _dist(a, d) == 1: v += 2
	if has(a, "하론"): v = int(ceil(v * 0.7))
	return maxi(0, v)

## Flat damage adjustments after defense.
static func dmg_mod(a: Unit, d: Unit, magic: bool, initiator: bool, strike_no: int) -> int:
	var m = 0
	if has(a, "토르"): m += 2
	if has(a, "아서") and initiator: m += 2
	if has(a, "루나") and strike_no == 2: m += 2
	if has(a, "아이린") and magic and d.has_tag("dark"): m += 3
	if not magic and has(d, "드레이크"): m -= 2
	if magic and has(d, "루미나"): m -= 2
	if not magic and has(d, "그렉"): m -= 1
	return m

static func crit_dmg_bonus(a: Unit) -> int: return 3 if has(a, "노아") else 0

static func vantage(d: Unit, a: Unit) -> bool:
	if has(d, "니아"): return true
	return has(d, "실라") and BattleManager.attack_speed(d) > BattleManager.attack_speed(a)

## Chance (0..1) of a bonus follow-up when faster but < 4 AS.
static func extra_double_chance(u: Unit) -> float:
	if has(u, "아린"): return 0.10
	if has(u, "에일린"): return 0.15
	return 0.0

static func weight_relief(u: Unit) -> int: return 2 if has(u, "미라") else 0
static func lifesteal_magic(u: Unit) -> float: return 0.2 if has(u, "아리아") else 0.0
static func poison_chance(u: Unit) -> float: return 0.2 if has(u, "벤") else 0.0
static func end_turn_heal(u: Unit) -> int: return 5 if has(u, "세라") else 0
