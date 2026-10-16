# 인수인계 문서 (HANDOFF)

다른 AI/개발자가 이어서 작업할 수 있도록 정리한 문서입니다. 마지막 갱신: 2026-10-15.

## 1. 프로젝트 개요
- GBA 파이어엠블렘 스타일 SRPG. **Godot 4.3 / GDScript**, **휴대폰 세로 720x1280**, 터치 전용, 한국어 UI.
- 플레이: https://junsa80.github.io/srpg-prototype/ (repo `junsa80/srpg-prototype`, `main` 브랜치 `/docs` 폴더 = GitHub Pages)
- 구현 범위: 1~6장 + 3장 이후 분기(4A 노르드 / 4B 사르한), 거점(상점·수송·장비·상태·저장·지원·환생), 프롤로그/턴 이벤트/야영/지원 대화.

## 2. 빌드 · 테스트 · 배포
```bash
G=/path/to/Godot_v4.3-stable_linux.x86_64
$G --headless --import                                   # 최초 1회/스크립트 변경 후
# 테스트 (전부 PASS 상태 유지)
for t in flow_test menu_test weapons_test campaign_test; do $G --headless res://tests/$t.tscn -- --flowtest; done
$G --headless --script tests/selftest.gd
$G --headless --script tests/skills_test.gd
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
- **오디오**: 백그라운드에서 BGM/SFX 일시정지 (`scripts/audio.gd`).
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
- **에일린/레온 클래스는 사용자 결정 사항.** 현재 데이터는 에일린=용병, 레온=기사. 초상화는 에일린=기사, 레온=궁수. 임의로 바꾸지 말 것.
- **6장 승리 조건 = 아린 탈출** (전원 탈출안은 사용자가 되돌림).
- `docs/`(Pages)에 스포일러 금지. 스토리는 `story/`에.
- 외부 전송(push, release, 메시지)은 사용자 승인 후에만.
- **사용자 게임 디자인 기준**: GBA 파이어엠블렘 감성, 휴대폰 한 손 터치로 편하게, 자연스러운 한국어 구어체(번역투 금지, 짧은 대사), 매 작업마다 테스트, 폰 화면으로 실제 탭 확인, 문서 갱신, 배포, 스크린샷과 함께 보고.

- 병종 계열 (v4): 중갑 아머나이트→제네럴 / 기마 소셜나이트→팔라딘, 성기사(시스터 상급) / 비행 비룡기사→드래곤마스터. 개인 기본치 보정·성장률은 `Roster.PERSONAL_BASE/PERSONAL_GROWTH`, 개인 초기 장비 `UNIT_LOADOUT`. 리엘(비룡) 이름이 스토리 바이블 13장 숲 정찰병 리엘과 겹침 — 사용자 결정 대기.

- 능력치 상한: `data/class_caps.gd` (ClassCaps.RAW, MAX_LEVEL 20, PROMOTE_MIN_LV 10). 상급 최소치 = 하급 Lv1 기본치 + 전직 보너스. 보스(boss=true)는 상한·레벨 제한 면제, 그림자 일반병은 대응 아군 클래스 상한(ENEMY_AS). 13장 정찰병은 레이(사용자 결정), 비룡기사 리엘 유지.

- 장 계획 `data/campaign_plan.gd` (Maps.CH에 없는 장은 플레이 불가), 보스 `data/bosses.gd` (faction/playable 최소 필드만). 7장 이후 영입 9명은 join "ch7".. — CH_INDEX에 장 추가 시 합류. 모르간 패시브로 ch5 승률 11→6/16 (사용자: 승률 현행 유지).

- 7장 구현 (maps.gd ch7, chapter_data ch7/EVENTS/CAMP/TALK 아린|다린). NEXT ch6→ch7→end. 스토리의 벤(대화 영입)·엘런(마차 생존 시 합류)·카시안 대화 퇴각은 미구현 (벤/엘런은 유닛 데이터 없음). 다음 장 추가 시 NEXT·CH_INDEX·sim PLAN·base "준비 중" 문구 갱신.

- 8장 구현: defend + "rout_early"(적·증원 모두 처치 시 조기 승리). 셀레나(시작 합류)·가브리엘(회의장 방문) 유닛 데이터 없음 → 대사만. 베일은 도적 클래스 보스(15장 전 상급 금지). 4B: (12,7) 중갑병 guard.

- 9~16장은 사용자 재구성안(STORY_BIBLE 하단). 9~12장 완료, 13~16 남음. 카이린 = 12장 영입(roster "recruit"). 9~12 보스는 기본 클래스(아머나이트) — 승급 적은 15장부터.

## 6. 현재 시뮬 승률 (16회, 조잡한 AI 기준. 통과선 15%)
ch1 16/16 · ch2 11/16 · ch3 9/16 · ch4a 7/16 · ch4b 5/16 · ch5 6/16 · ch6 8/16 (2026-10-15 밤, 상한·2갈래 전직·보스 패시브). v4 직후: 16·11·8·6·4·11·6. 이전(저녁): 16·9·6·7·7·9·10. 시스터 지팡이만(단검 없음) 시험: ch1 16/16, ch2 2/16 → 단검 유지. 치유사 없이: ch1 16/16, ch2 4/16. 자세한 값은 `tests/sim_results.txt`.

## 7. 미완료 · 열린 작업
1. 스토리 충돌 목록 (`story/STORY_BIBLE.md` "현재 구현과의 충돌"):
   - 미라를 3장 선택 영입으로 바꾸기
   - 에일린/레온 합류를 4장 루트별로 옮기기
   - 4장 재구성
   - 5장 설원 재설계(안개·숨겨진 길·모르간 중갑)
   - 6장 성 안/밖 분할과 노아 침식 선택
   - 2장 보스 이름을 '우르'로 표기
2. (완료) 눈/성 타일·미라 v2·모르간 초상화 적용. 남은 것: 4A 설원은 아직 절차적 눈 그림(테마 미적용), 성 타일 중 현수막·문장 바닥 일부 미사용, 모르간 인벤토리에 용사의 창 2개 표시(확정 드롭+장비 중복, 확인 필요). 폰 탭 확인 필요: 인접 아군 회복 아이템 대상 선택, 백그라운드 오디오 일시정지(실기기).
3. 보리스 초상화와 전용 맵 스프라이트가 없음 (현재 기본 그림).
4. 폰 탭 확인이 아직 안 된 기능: 교환 화면, 드롭 팝업, 창 자동 이동, 무기 아이콘 설정 토글 (자동 테스트만 통과).
5. 5·6장 신규 메커닉: 안개(시야 제한), 분할 배치, 침식 상태, 엔딩 플래그.
6. 클라우드 저장 미구현 (현재 브라우저 로컬 저장만).
7. 7장 이후 맵, 적 배치, 신규 유닛 21명 데이터 (대본은 `story/`에 있고, 스킬은 `skills.gd`에 이미 있음).
8. 시뮬 AI가 조잡함 (탈출·호위형 목표에서 특히 약함).

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
