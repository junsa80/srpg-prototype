# 인수인계 문서 (HANDOFF)

다른 AI/개발자가 이어서 작업할 수 있도록 정리한 문서입니다. 마지막 갱신: 2026-10-17.

## 1. 프로젝트 개요
- GBA 파이어엠블렘 스타일 SRPG. **Godot 4.3 / GDScript**, **휴대폰 세로 720x1280**, 터치 전용, 한국어 UI.
- 플레이: https://junsa80.github.io/srpg-prototype/ (repo `junsa80/srpg-prototype`, `main` 브랜치 `/docs` 폴더 = GitHub Pages)
- 구현 범위: **본편 완결** — 1~27장 + 종장(그림자의 심연) + 3장 이후 분기(4A 노르드 / 4B 사르한), 엔딩 3종(새벽/잿빛/기본, `ChapterData.ending_id`; 14장 떠나보냄 = 기본), 종장 빛 기둥(`L`, `light_only_heal`). 거점(상점·수송·장비·상태·저장·지원·환생), 프롤로그/턴 이벤트/야영/지원 대화, 모든 보스·화자 초상화.
- 현재 배포: 커밋은 `git log -1`, `docs/index.pck` md5 `79b007e7c6526b3d0e1446d73d17422b` (2026-10-17, 음향 설정·유닛 전환·레온·23장·노아 이전·SD 통일).
- 미결 사항 목록: `story/OPEN_QUESTIONS.md` (스포일러). 실기기 확인 목록: `DEVICE_CHECKLIST.md`.

## 2. 빌드 · 테스트 · 배포
```bash
G=/path/to/Godot_v4.3-stable_linux.x86_64
$G --headless --import                                   # 최초 1회/스크립트 변경 후
# 테스트 (전부 PASS 상태 유지)
for t in flow_test menu_test weapons_test campaign_test; do $G --headless res://tests/$t.tscn -- --flowtest; done
$G --headless --script tests/selftest.gd
$G --headless --script tests/skills_test.gd
$G --headless res://tests/qol_test.tscn -- --flowtest     # P0/P1 QoL, 저장 내보내기·손상 복구
$G --headless --script tests/consistency_test.gd      # 맵·대본·클래스·무기·초상 정합성 (초상 누락=WARN)
$G --headless res://tests/sim_test.tscn -- --flowtest      # 밸런스 시뮬 (SIM_ONLY=ch6, SIM_V=1, SIM_NOHEAL=1)
# 웹 빌드 (export_presets.cfg: thread_support=false → COOP/COEP 없는 정적 호스팅 OK)
$G --headless --export-release Web build/web/index.html
rm -rf docs && cp -r build/web docs && touch docs/.nojekyll docs/.gdignore
git add -A && git commit -m "..." && git push origin main
# 배포 확인
gh api repos/junsa80/srpg-prototype/pages/builds/latest --jq '.status+" "+.commit'
curl -s https://junsa80.github.io/srpg-prototype/index.pck | md5sum; md5sum docs/index.pck
```
- `gh auth`는 사용자 계정(junsa80)으로 로그인된 상태여야 push/release 가능. **토큰을 커밋하지 말 것** (커밋 전 `rg -l "gh[op]_[A-Za-z0-9]{20}" .`).
- `--script` 모드 테스트(selftest, skills_test)는 autoload(Campaign/Settings/Sfx/Menus)를 못 씀 → `unit.gd`, `battle_manager.gd`에서 autoload 참조 금지(정적 변수 사용, 예: `Unit.show_badge`).
- 개발용 URL 해시: `#goto=chX`, `nodialog`, `mapview`, `devwin`(적 전멸·클리어 화면), `forecast`, `#base+ch2`.

## 3. 저장소 구조
| 경로 | 내용 |
|---|---|
| `scripts/battle.gd` | 전투 씬 전체 (이동/공격/아이템/교환/드롭/이벤트/목표/UI 배치) |
| `scripts/battle_manager.gd` | 전투 공식, `forecast()` |
| `scripts/enemy_ai.gd` | 적 AI (`smart` = 매우 어려움) |
| `scripts/campaign.gd` | 캠페인 상태·저장(autoload), 환생 규칙 |
| `scripts/base.gd` / `prep.gd` / `title.gd` | 거점 / 출전 준비 / 타이틀 |
| `scripts/menus.gd`, `item_menus.gd`, `rebirth_ui.gd` | 공용 UI (설정, 슬롯, 유닛 목록, 상성표, 환생 화면) |
| `scripts/unit.gd`, `class_data.gd`, `unit_data.gd`, `weapon_data.gd` | 유닛/클래스/무기 리소스 |
| `scripts/skills.gd` | 개인 스킬 37개 (이름 = 유닛 이름) |
| `data/roster.gd` | 클래스·플레이어블 유닛·합류 장 |
| `data/weapons.gd`, `class_profs.gd`, `promotion_bonuses.gd`, `maps.gd` | 무기/숙련/전직/맵 데이터 |
| `chapters/chapter_data.gd` | 대사 (프롤로그, 장별 pre/boss/post, 이벤트, 야영, 대화 영입, 지원) |
| `assets/portraits/<이름>.png` | 대화 초상화 (128x128) |
| `assets/user_art/` | 사용자 원본 그림 (`.gdignore` → 웹 빌드 제외) |
| `story/` | 전체 스토리 바이블·대본·`chapters_script.json` (**스포일러, Pages 비공개**) |
| `tests/` | 테스트 + `sim_results.txt` |
| `docs/` | 웹 빌드 결과물(Pages). 여기엔 스포일러 문서 넣지 말 것 |

## 4. 핵심 시스템 · 공식
- 명중 = 무기명중 + 기술×2 + 행운/2 + 상성×15 + 스킬 + 랭크/숙련 보너스 − 회피. 회피 = 공속×2 + 행운 + 지형 + 스킬.
- 데미지 = (힘 또는 마력) + 위력×(특효면 3) + 보너스 + 상성×1 − 방어(또는 마방). 치명 = 무기치명 + 기술/2 + 보너스 − 행운, 치명 ×3.
- 공속 = 속도 − max(0, 무게 − 힘). 공속 차 4 이상이면 추격.
- 상성: 검 > 도끼 > 창 > 검 (예측 창에 ▲/▼, 메뉴에 상성표).
- 무기 랭크 E~S (WEXP 0/30/70/120/180/250), 클래스별 숙련 보너스(`class_profs.gd`).
- **드롭**: 일반 적 무기 3%·아이템 5%, 정예/경계 12%·10% (2026-10-15 하향, 이전 8%/15%), 보스는 확정 드롭만. 시도마다 고정 시드 → 저장/불러오기로 다시 굴릴 수 없음. 획득 팝업, 소지품 가득 차면 수송대로/버리기/교체.
- **열쇠**: 문 열쇠·상자 열쇠·마스터 키(3회). 도적은 무료.
- **각성(재도전 보정)**: 그 장에서 패배한 뒤 다시 출전할 때, 이전 시도에 없던 유닛은 이번 장 한정 전 능력치 +2, HP +5. 패배 시 출전 유닛에게 훈련 EXP +10.
- **교환**: 인접 아군과 5칸 인벤토리 교환, 행동을 끝내지 않음.
- **회복 아이템**: 자신 또는 인접 아군에게 사용 (사용자의 아이템 소모, 행동 종료).
- **무기 숙련**: 도적 = 단검 특화(검 하위 분류 `dagger`, 도적 명중+10 치명+10 / 어쌔신 명중+10 치명+15). 시스터 = 지팡이 주무기 + 단검(E)만, 단검 보너스 없음.
- **회복 병종**: 시스터(기본, 도보 이동5) → 성기사(상급 기마 이동7, 창/검/지팡이) 또는 비숍(지팡이+빛 마법). 세라 = 시스터. 발키리는 데이터에 남아 있음(구 저장의 전직 세라용, 신규 진입 경로 없음).
- **저장 버전**: `Campaign.GAME_VERSION`. 클래스/맵이 바뀌는 업데이트마다 올리고 `Campaign.migrate_entry()`에 이전 규칙 추가. 구버전 저장 → 1회 "업데이트 재시작" 제안 (`update_restart()`: ★·enemy_lv 그대로, 난이도 보통, 전부 유지).
- **맵 스프라이트**: `tools/chibi.py` 재실행으로 모든 SD 시트 재생성 (유닛 추가 시 UNITS 표에 한 줄). 비룡 클래스 시트는 미리 만들어 둠(아군 비룡 미구현, 제안만).
- **상점 입고**: `base.gd` BASIC(처음) / STEEL+UTILITY(`ch3` 클리어 후) / SILVER(은·킬러·해커·멘드·피지오, `ch5` 클리어 후). 드롭·상자는 그대로. 필터 `Settings.usable_only` = `Unit.block_reason()` 기준.
- **맵 확대/축소**: `battle.gd` `set_zoom()/zoom_step()/_pinch_input()`, `Settings.map_zoom`, 단계 `Settings.ZOOM_STEPS`. 카메라는 왼쪽 위 기준, `_clamp_cam`은 화면 크기/배율로 계산.
- **오디오**: 백그라운드에서 BGM/SFX 일시정지 (`scripts/audio.gd`). 설정 `Settings.bgm_on`/`sfx_on`(켬/끔, 기본 켬) + 음량 `bgm`/`sfx`(0~10). 끔이면 BGM 정지·SFX 재생 안 함. 예전 전체 음소거(`user://muted`)도 유지.
- **출전 준비 유닛 전환**: `prep.gd _unit_items(u, open_convoy)` 상단 `ItemMenus.nav_row()` ◀▶, 수송대 패널은 `ItemMenus.convoy_panel(..., cycle)`로 같은 버튼(출전 유닛 순환, 수송대 화면은 다음 유닛 수송대로 바로 열림). 거점 상점/수송/장비는 원래 ◀▶ 있음.
- **14장 노아 결과**: 클리어 시 `battle._record_noah_outcome()`가 `camp_seen`에 `noah_out_joined/farewell/killed/lost` 기록. 엔딩은 `Campaign.ending_for()`. 구버전 저장(14장 클리어, 기록 없음)은 불러올 때 `noah_out_legacy` → 노아 부재여도 기본 엔딩(격파 여부를 알 수 없어 잿빛으로 판정하지 않음).
- **환생**:
  - 언제든 가능(타이틀·거점·전투 메뉴). 1장부터 다시 시작. 유닛은 합류 레벨로 돌아가고, 동료는 스토리 지점에서 다시 합류.
  - 난이도: 보통 +0 / 어려움 +2 / 매우 어려움 +4(AI 강화). 상위 난이도는 6장 클리어 후에만 고를 수 있고, 진행 도중 환생하면 현재 난이도까지만.
  - 포인트 = 이번 회차 클리어한 장 수 + 완결 시 3, 최대 10, 다음 회차로 이월되지 않음.
  - 특전:
    - 골드 30% 유지(최대 3000G) 1pt
    - 특수 무기 최대 2개 유지, 개당 2pt (용사, 특효(활 제외), 보스 드롭, A랭크 이상)
    - 무기 랭크 한 단계 낮춰 유지 2pt
    - 시작 아이템 보따리 1pt (엘릭서 / 마스터 키 / 강철 무기 세트 / 상처약 x5)
    - 지원 대화 유지 0pt
    - 고급(비추천) 능력치 +1: 3pt, 한 유닛당 누적 최대 +2, 성장률 보너스 없음
  - 기본 선택: 골드 + 지원 + (포인트가 되면) 상처약 x5.
  - **노가다 모드**는 별도: 전부 유지, 회차마다 적 Lv +3, 저장에 [노가다] 표시.
  - 구버전 저장은 cycle 수만큼 노가다 회차로 이전된다.
  - 완전 초기화는 별개이며 확인을 2번 받는다.

## 5. 설계 결정 · 사용자 제약 (반드시 지킬 것)
- **기존 클래스/유닛의 기본 능력치·성장률 변경 금지.** 새 클래스(전사/워리어/버서커)만 `Roster.GROWTHS`로 별도 지정.
- **에일린/레온 클래스는 사용자 결정 사항.** 현재 데이터는 에일린=용병, 레온=기사. 초상화는 에일린=기사, 레온=아머나이트(2026-10-17 교체, 옛 궁수 그림은 `assets/user_art/leon_old_archer_portrait.png`). 임의로 바꾸지 말 것.
- **6장 승리 조건 = 아린 탈출** (전원 탈출안은 사용자가 되돌림).
- `docs/`(Pages)에 스포일러 금지. 스토리는 `story/`에.
- 외부 전송(push, release, 메시지)은 사용자 승인 후에만.
- **사용자 게임 디자인 기준**: GBA 파이어엠블렘 감성, 휴대폰 한 손 터치로 편하게, 자연스러운 한국어 구어체(번역투 금지, 짧은 대사), 매 작업마다 테스트, 폰 화면으로 실제 탭 확인, 문서 갱신, 배포, 스크린샷과 함께 보고.

- 병종 계열 (v4): 중갑 아머나이트→제네럴 / 기마 소셜나이트→팔라딘, 성기사(시스터 상급) / 비행 비룡기사→드래곤마스터. 개인 기본치 보정·성장률은 `Roster.PERSONAL_BASE/PERSONAL_GROWTH`, 개인 초기 장비 `UNIT_LOADOUT`. 리엘(비룡) 이름이 스토리 바이블 13장 숲 정찰병 리엘과 겹침 — 사용자 결정 대기.

- 능력치 상한: `data/class_caps.gd` (ClassCaps.RAW, MAX_LEVEL 20, PROMOTE_MIN_LV 10). 상급 최소치 = 하급 Lv1 기본치 + 전직 보너스. 보스(boss=true)는 상한·레벨 제한 면제, 그림자 일반병은 대응 아군 클래스 상한(ENEMY_AS). 13장 정찰병은 레이(사용자 결정), 비룡기사 리엘 유지.

- 장 계획 `data/campaign_plan.gd` (Maps.CH에 없는 장은 플레이 불가), 보스 `data/bosses.gd` (faction/playable 최소 필드만). 7장 이후 영입 9명은 join "ch7".. — CH_INDEX에 장 추가 시 합류. 모르간 패시브로 ch5 승률 11→6/16 (사용자: 승률 현행 유지).

- 7장 구현 (maps.gd ch7, chapter_data ch7/EVENTS/CAMP/TALK 아린|다린). NEXT ch6→ch7→end. 스토리의 벤(대화 영입)·엘런(마차 생존 시 합류)·카시안 대화 퇴각은 미구현 (벤/엘런은 유닛 데이터 없음). 다음 장 추가 시 NEXT·CH_INDEX·sim PLAN·base "준비 중" 문구 갱신.

- 8장 구현: defend + "rout_early"(적·증원 모두 처치 시 조기 승리). 셀레나(시작 합류)·가브리엘(회의장 방문) 유닛 데이터 없음 → 대사만. 베일은 도적 클래스 보스(15장 전 상급 금지). 4B: (12,7) 중갑병 guard.

- 9~16장은 사용자 재구성안(STORY_BIBLE 하단). 9~27장·종장 완료 = 본편 완결 (엔딩 분기 ChapterData.ending_id, story/final.md). 이야기 이름 보스는 `Bosses.ALIAS`로 일반 보스 패시브 사용 (Skills.has). 노아: ch13 클리어 시 Campaign.absent에 추가, ch14 대화 설득→선택(_noah_choice). 카이린 = 12장 영입(roster "recruit"). 9~12 보스는 기본 클래스(아머나이트) — 승급 적은 15장부터.

## 6. 현재 시뮬 승률 (16회, 조잡한 AI 기준. 통과선 15%, 9장 이후 목표 8~13)
- 1~8장: ch1 16 · ch2 11 · ch3 9 · ch4a 7 · ch4b 5 · ch5 9 · ch6 5 · ch7 14 · ch8 10
- 9~16장: ch9 12 · ch10 13 · ch11 9 · ch12 12 · ch13 10 · ch14 9 · ch15 13 · ch16 13
- 17~종장: ch19 13 · ch20 11 · ch21 13 · ch22 10 · ch23 12 · ch24 8 · ch25 13 · ch26 8 · ch27 8 · final 9 (빛 기둥 적용 후)
- 주의: 상급 적은 숨은 하급 15레벨이 붙어 **Lv 1 차이로 승률이 크게 흔들린다** (ch25 Lv10 13/16 → Lv11 2/16). 자세한 기록 `tests/sim_results.txt`. 단일 장: `SIM_ONLY=ch25`.

## 7. 미완료 · 열린 작업
1. 결정 완료(2026-10-17, `story/OPEN_QUESTIONS.md` §2): 떠나보냄=기본 엔딩, 종장 빛 기둥, 7장 8턴 방어 유지, 아린/세라 변경 없음, 미구현 영입 21명·이졸데·발레리우스 보류. 레온 초상화 교체 완료(2026-10-17). **남은 것**: 업데이트 재시작 시 enemy_lv 초기화 여부(유지 권장).
2. 보리스 전용 초상화·SD 완료. **아트 감사 `story/ART_AUDIT.md`** (재생성: `tools/art_audit.gd`): 임시(코드 생성) 초상 12명, 구형 96px 3명+상인, 이름 NPC 화자 초상 없음 22명. 그림자 일반병 5종·바르가스 SD는 chibi.py로 통일(원본 `assets/user_art/sliced/*_old_sheet.png`). SD만 다시 만들 땐 `tools/chibi.py`를 모듈로 불러 `class_sheet()`로 해당 유닛만 생성(전체 재실행은 모든 시트를 덮어씀).
3. 실기기 확인 (`DEVICE_CHECKLIST.md` 11항목). safe area(노치) 처리 코드 없음.
4. 원안 메커닉(보류): 5장 안개, 6장 성 안/밖 분할·노아 침식, 7장 호위 NPC.
5. 클라우드 저장 미구현 (UI에 "미지원" 표기). 로컬 내보내기/가져오기·손상 복구는 구현.
6. 스크린샷 러너 재구축 필요 (보고용 화면 캡처).
7. 시뮬 AI가 조잡함 (탈출·제압형 목표에서 사망 과대 추정, 예: ch23 평균 사망 4.9 — 2026-10-17 완화 전 6.4).

### 이어서 작업하는 법
- 새 장 추가: `data/maps.gd` CH 항목 → `chapters/chapter_data.gd` CHAPTERS/EVENTS/CAMP/SUPPORTS → `scripts/campaign.gd` NEXT, `data/roster.gd` CH_INDEX → `tests/campaign_test.gd`·`tests/sim_test.gd` PLAN → 시뮬 → 빌드·배포. 이야기 이름 보스는 `Bosses.ALIAS`로 기존 패시브 연결.
- 초상화: 원본을 `/workspace/portraits_raw/<이름>.png`에 두고 128px 정사각 크롭 → `assets/portraits/<이름>.png` → `tests/consistency_test.gd`로 누락 확인.
- 세션이 자주 끊기므로 단계마다 커밋·푸시.

## 8. 그림 파일 주의 (파일명 ≠ 내용)
사용자가 Drive에 올린 파일은 이름과 내용이 자주 다르다. **반드시 그림을 열어 보고 판단할 것.** 2026-10-15 묶음의 실제 내용:

| 파일 | 실제 내용 | 게임에서 사용처 |
|---|---|---|
| leon_portrait | 에일린 | 에일린 |
| vargas_portrait | 레온 | 레온 |
| extra_mercenary_portrait | 바르가스 | 바르가스 |
| extra_mage_portrait | 루크 | 루크 |
| luke_portrait | (이름표 없는 그림) | 노아 |
| arin_sprites (저녁) | 마을 타일 | 풀밭 맵 마을/벽/산 |
| village_tileset (저녁) | 아린 | 아린 맵 스프라이트 |
| sera_sprites (저녁) | 리나 | 리나 맵 스프라이트 |
| rina_sprites (저녁) | 금발 갑옷 창병 | 세라 성기사 전직 후 |
| eileen_portrait | (이름표 없는 그림) | 엘리아 |

예전 묶음 기록은 `ASSETS.md` 참고.

## 9. 외부 자료
- 사용자 그림 Google Drive 폴더 ID: `1xlFChkT9a02QYAIfHFdDOjteXElnquO6`
- 백업 릴리스(웹 빌드 zip): https://github.com/junsa80/srpg-prototype/releases/tag/backup-20261015

## QoL 메모 (2026-10-16)
- 설정 `auto_end`(자동 턴 종료) 추가. `battle._maybe_auto_end()`가 유일한 자동 종료 경로.
- 저장 내보내기 코드 형식: `SRPGSAVE1:` + base64(JSON 문서). `SaveManager.import_text(slot, text)`는 슬롯 1~3만, 원본 JSON도 허용.
- `load_slot()`은 손상 시 `{"corrupt": true}` 반환 → UI가 빈 슬롯과 구분. 클라우드 동기화(`cloud_sync`)는 여전히 TODO, UI 노출 금지.
- 실기기 확인 필요: 노치/작은 화면 안전 영역, 두 손가락 확대, 한 손 드래그, 웹 다운로드·클립보드(iOS Safari 제한), 가져오기 TextEdit 가상 키보드.
