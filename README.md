# SRPG 프로토타입 (Godot 4.3, GDScript)

고전 파이어엠블렘 스타일 사각 그리드 전술 RPG 뼈대입니다. **휴대폰 세로 화면(720x1280, stretch canvas_items/expand), 터치 전용 조작** 기준입니다.

## 실행
- 에디터: Godot 4.3 이상에서 `project.godot` 열기 → F5
- 헤드리스 자가 테스트: `godot --headless --script res://tests/selftest.gd`
- 웹 빌드: `godot --headless --export-release Web build/web/index.html`
  (스레드 지원 OFF → COOP/COEP 헤더 없는 일반 정적 호스팅에서도 동작)
- 로컬 확인: `python3 -m http.server -d build/web 8000` 후 휴대폰/브라우저로 접속

## 조작 (터치)
1. 아군 유닛 탭 → 파란 칸(이동), 빨간 칸(공격 범위) 표시
2. 파란 칸 탭 → 이동
3. 적 탭 → 하단에 전투 예측(전/후 HP, 데미지, 명중, 추격 x2)
4. **확인** = 공격/대기, **취소** = 이동 취소, **턴 종료** = 적 페이즈
- 선택 안 한 상태에서 적 탭 → 이동/공격 범위와 **다음 행동 의도** 표시
- 대화: 화면 탭으로 진행, 우상단 **건너뛰기**

## 구조
| 경로 | 내용 |
|---|---|
| `scripts/weapon_data.gd` | 무기 Resource. 검>도끼>창>검 상성 (활/마도서는 중립, 마도서는 마력 vs 마방) |
| `scripts/class_data.gd` | 클래스 Resource. 기본 스탯, 성장률, Lv10 전직, 전직 보너스(+이동 보너스) |
| `data/promotion_bonuses.gd` | 상위 클래스 11종 확정 전직 보너스 표 |
| `scripts/unit_data.gd` | 유닛 Resource. 개인 성장률, 개인 스킬, 태그(`dark` 등) |
| `scripts/unit.gd` | 유닛 노드. 스탯, 성장률 굴림 레벨업 / 고정 성장 옵션(`Unit.fixed_growth`), 전직 |
| `scripts/battle_manager.gd` | 명중=무기명중+기×2+행/2−(속×2+행), 2RN 표시명중, 데미지=공−방, 속도 4차 추격, 상성 ±15명중/±1뎀, `forecast()` |
| `scripts/turn_manager.gd` | 플레이어/적 페이즈 |
| `scripts/enemy_ai.gd` | 도달 가능한 최적 대상 공격(킬 우선), 없으면 접근. `plan()`이 의도 반환 |
| `scripts/grid.gd` | 사각 그리드, AStarGrid2D 경로, BFS 이동 범위, 공격 범위 |
| `scripts/save_manager.gd` | 오토로드. 슬롯 3개, 버전 JSON(시각·챕터·턴), 임시파일→rename, 클라우드 동기화 TODO 스텁 |
| `scripts/dialogue_box.gd` | 초상화 없는 대화창 |
| `chapters/chapter_data.gd` | 세계관, 파티 8인, 1~3장 대사 (2·3장은 스텁) |
| `scenes/test_chapter.tscn` | 1장 마을 방어 (아린·노아·리나·세라·엘리아 vs 그림자 병사 4) |
| `ASSETS.md` | 픽셀아트/초상화/타일/보스 생성 프롬프트 |

## 세이브
챕터 시작과 매 플레이어 턴 시작에 슬롯 0으로 자동 저장. `save_N.json.tmp`에 쓰고 rename. 클라우드 충돌 시 자동 선택하지 않고 두 세이브를 나란히 보여주고 고르게 하는 설계(주석 참고).

## 개인 스킬 / 무기 / 지팡이
- `scripts/skills.gd`: 36개 개인 스킬(유닛 이름 기준). 34개 구현, 잭(보물 탐지)·릴리(해제 범위)는 해당 시스템이 없어 데이터만 있음
- `data/weapons.gd`: 무기 14종(위력/명중/치명/무게/내구), 클래스별 기본 장비. 내구는 공격마다 1 감소, 0이면 파손
- 공속 = 속도 − max(0, 무게 − 힘(마법은 마력))
- 지팡이: 이동 후 다친 인접 아군 탭 → 회복량 미리보기 → [확인]. 회복량 = 지팡이 회복 + 마력, EXP 11
- 소지품(내구 포함)은 Campaign 로스터에 저장되어 패배 후 재도전에도 유지
- 테스트: `godot --headless --script res://tests/skills_test.gd`, `godot --headless res://tests/flow_test.tscn -- --flowtest`
