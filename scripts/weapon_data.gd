class_name WeaponData extends Resource
enum Type { SWORD, LANCE, AXE, BOW, TOME, STAFF }
@export var magic = false  # uses mag vs res
@export var name = "Iron Sword"
@export var type: Type = Type.SWORD
@export var might = 5
@export var hit = 90
@export var crit = 0
@export var min_range = 1
@export var max_range = 1
@export var weight = 5
@export var max_uses = 40
@export var uses = 40
@export var heal = 0  # staves only

func is_staff() -> bool: return type == Type.STAFF
func to_dict() -> Dictionary: return {"name": name, "uses": uses}

## sword > axe > lance > sword. Returns +1 advantage, -1 disadvantage, 0 neutral.
static func triangle(a: Type, b: Type) -> int:
	if a == b or a > Type.AXE or b > Type.AXE: return 0
	var beats = {Type.SWORD: Type.AXE, Type.AXE: Type.LANCE, Type.LANCE: Type.SWORD}
	return 1 if beats[a] == b else -1
