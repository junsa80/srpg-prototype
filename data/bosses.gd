class_name Bosses extends RefCounted
## Boss data + passives (Skills.LIST holds the passive text; hooks in skills.gd / battle_manager.gd).
## faction / playable kept minimal for a possible future shadow-side campaign (not implemented).
## name: {class, weapon, lv, chapter (plan), passive, faction, playable}
const TABLE = {
	"바르가스": {"class": "바르가스", "weapon": "파멸의 도끼", "lv": 2, "chapter": "ch3", "passive": "철벽", "faction": "shadow", "playable": false},
	"그림자 지휘관": {"class": "그림자 지휘관", "weapon": "그림자 창 우르", "lv": 1, "chapter": "ch2", "passive": "", "faction": "shadow", "playable": false},
	"모르간": {"class": "그림자 지휘관", "weapon": "용사의 창", "lv": 6, "chapter": "ch5", "passive": "그림자 지휘", "faction": "shadow", "playable": false},
	"요새 문지기": {"class": "제네럴", "weapon": "강철창", "lv": 6, "chapter": "ch10", "passive": "수비", "faction": "shadow", "playable": false},
	"그림자 궁병 대장": {"class": "스나이퍼", "weapon": "강철활", "lv": 7, "chapter": "ch16", "passive": "정밀 사격", "faction": "shadow", "playable": false},
	"어둠 마법사": {"class": "세이지", "weapon": "썬더", "lv": 8, "chapter": "ch19", "passive": "마력 흡수", "faction": "shadow", "playable": false},
	"그림자 기병 대장": {"class": "팔라딘", "weapon": "은창", "lv": 9, "chapter": "ch11", "passive": "돌격", "faction": "shadow", "playable": false},
	"그림자 암살자": {"class": "어쌔신", "weapon": "킬러소드", "lv": 11, "chapter": "ch22", "passive": "급소", "faction": "shadow", "playable": false},
	"그림자 장군": {"class": "워리어", "weapon": "강철도끼", "lv": 13, "chapter": "ch12", "passive": "학살", "faction": "shadow", "playable": false},
	"비룡 군주": {"class": "드래곤마스터", "weapon": "은창", "lv": 15, "chapter": "ch26", "passive": "급강하", "faction": "shadow", "playable": false},
	"그림자 왕": {"class": "그림자 지휘관", "weapon": "그림자 창 우르", "lv": 18, "chapter": "ch27", "passive": "왕권", "faction": "shadow", "playable": false},
}
## story-named bosses that use a generic boss passive
const ALIAS = {"마그누스": "어둠 마법사", "라울": "그림자 기병 대장", "오드윈": "그림자 암살자", "그라데스": "그림자 장군", "에레보스": "그림자 왕"}
static func passive(n: String) -> String: return TABLE.get(n, {}).get("passive", "")
