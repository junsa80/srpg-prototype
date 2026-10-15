class_name ClassData extends Resource
@export var name = "Myrmidon"
@export var move = 5
@export var base_stats = {"hp": 18, "str": 5, "mag": 0, "skl": 8, "spd": 9, "lck": 4, "def": 3, "res": 1}
## percent growth bonuses added to unit growths
@export var growth_rates = {"hp": 60, "str": 30, "mag": 5, "skl": 50, "spd": 50, "lck": 30, "def": 20, "res": 15}
@export var promotion_level = 10
@export var promotes_to: ClassData
## Usable weapon types (WeaponData.Type). Empty = all.
@export var weapon_types: Array = []
## Stat bonus granted when promoting INTO this class. Empty -> looked up in PromotionBonuses.TABLE by name.
@export var promotion_bonus = {}
## Movement bonus granted when promoting into this class.
@export var move_bonus = 0

func get_promotion_bonus() -> Dictionary:
	var b: Dictionary = promotion_bonus if not promotion_bonus.is_empty() else PromotionBonuses.for_class(name)
	if move_bonus != 0: b = b.duplicate(); b["move"] = move_bonus
	return b
