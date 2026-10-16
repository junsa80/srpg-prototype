class_name CampaignPlan extends RefCounted
## 25-30 chapter plan (data only). Chapters without a map in Maps.CH are NOT playable: after Ch6 the base shows "to be continued".
## Enemy timeline (GBA FE6/FE8 style): Ch7-14 base classes; Ch15-20 promoted enemies appear (rising share); Ch21+ mostly promoted + special weapons.
## ch: [title, enemy lv range, promoted share 0..1, class mix, boss, recruits]
const BASE_MIX = ["그림자 병사", "그림자 창병", "그림자 궁병", "그림자 술사", "그림자 중갑병", "그림자 기병", "그림자 비룡"]
static var PLAN = {
	"ch7": ["피난민 행렬 (8턴 방어)", [10, 12], 0.0, BASE_MIX, "추격대장 카시안", ["다린", "벤", "엘런"]],
	"ch8": ["왕 보호 10턴", [16, 17], 0.0, BASE_MIX, "암살자 베일", ["소라", "셀레나", "가브리엘"]],
	"ch9": ["수문 3개 → 탈출", [16, 17], 0.0, BASE_MIX, "밀수왕 오스만", ["엘렌", "잭", "릴리"]],
	"ch10": ["보스 격파", [7, 9], 0.0, BASE_MIX, "벨크", ["카린", "드레이크", "브렌"]],
	"ch11": ["보스 격파", [7, 10], 0.0, BASE_MIX, "학장 마그누스", ["오르린", "아리아"]],
	"ch12": ["격파/설득", [8, 11], 0.0, BASE_MIX, "길드장 라울", ["브록", "마크", "하론"]],
	"ch13": ["대장군 격파, 요새 사수", [9, 12], 0.05, BASE_MIX + ["제네럴"], "그라이브", ["라임", "토르", "레이", "세라핀"]],
	"ch14": ["옥좌 제압", [10, 12], 0.1, BASE_MIX + ["제네럴", "팔라딘"], "재상 오드윈", ["미르", "카이젠", "루나"]],
	"ch15": ["정문 도달", [1, 4], 0.2, BASE_MIX + ["제네럴", "팔라딘", "세이지", "스나이퍼"], "망령 황후 이졸데", ["제드", "아이린"]],
	"ch16": ["봉인진 4개 → 보스", [2, 5], 0.25, BASE_MIX + ["제네럴", "팔라딘", "세이지", "스나이퍼"], "자칭 황제 발레리우스", ["카이린"]],
	"ch17": ["요새 돌파", [3, 6], 0.3, ["제네럴", "그레이트나이트", "스나이퍼"] + BASE_MIX, "요새 문지기", []],
	"ch18": ["협곡 저격전", [3, 7], 0.35, ["스나이퍼", "레인저", "팔라딘"] + BASE_MIX, "그림자 궁병 대장", []],
	"ch19": ["마탑", [4, 8], 0.4, ["세이지", "메이지나이트", "비숍"] + BASE_MIX, "어둠 마법사", []],
	"ch20": ["평원 기병전", [5, 9], 0.5, ["팔라딘", "그레이트나이트", "레인저"] + BASE_MIX, "그림자 기병 대장", []],
	"ch21": ["설원 행군", [6, 10], 0.55, ["드래곤마스터", "워리어", "제네럴"] + BASE_MIX, "", []],
	"ch22": ["밤의 왕성", [7, 11], 0.6, ["어쌔신", "로그", "검성"] + BASE_MIX, "그림자 암살자", []],
	"ch23": ["봉인 신전", [8, 12], 0.65, ["세이지", "비숍", "팔라딘"] + BASE_MIX, "", []],
	"ch24": ["대전장", [9, 13], 0.7, ["워리어", "버서커", "제네럴", "팔라딘"] + BASE_MIX, "그림자 장군", []],
	"ch25": ["하늘 요새", [10, 14], 0.75, ["드래곤마스터", "드래곤나이트", "스나이퍼"], "", []],
	"ch26": ["비룡의 둥지", [11, 15], 0.8, ["드래곤마스터", "드래곤나이트", "레인저"], "비룡 군주", []],
	"ch27": ["그림자 왕좌", [13, 17], 0.9, ["제네럴", "팔라딘", "세이지", "검성", "어쌔신"], "그림자 왕", []],
	"final": ["종장 — 에레보스", [15, 20], 1.0, ["제네럴", "팔라딘", "세이지", "검성", "어쌔신", "드래곤마스터"], "에레보스", []],
}
## Special weapons (은/킬러/용사/특효) share on enemies: 0 before ch15, then rising.
static func special_share(ch: String) -> float:
	var n = int(ch.trim_prefix("ch")) if ch.begins_with("ch") else 28
	return 0.0 if n < 15 else clampf((n - 14) * 0.06, 0.0, 0.8)
static func playable(ch: String) -> bool: return Maps.CH.has(ch)
