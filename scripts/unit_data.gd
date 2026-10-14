class_name UnitData extends Resource
@export var name = "Unit"
@export var unit_class: ClassData
@export var level = 1
@export var personal_growths = {"hp": 10, "str": 10, "mag": 0, "skl": 10, "spd": 10, "lck": 20, "def": 5, "res": 5}
@export var personal_skill = ""
@export var weapon: WeaponData
@export var color = Color.BLUE
## e.g. ["dark"] for 그림자 군단 (아이린 skill bonus target)
@export var tags: PackedStringArray = []
