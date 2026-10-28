## 2026-10-28 — GPT 첫 플레이 1차
- 사용자의 새 우선순위: 모든 게임 GPT 이관. 첫인상·최소 조작 안내 우선. 전체 실행 계획과 다음 ㄱㄱ 작업: [planning/FIRST_FIVE_MINUTES.md](planning/FIRST_FIVE_MINUTES.md).
- 잿빛 왕관 새 게임: 안내받기/바로 플레이 선택, 첫 장 기본 편성, 도입 3줄. 초상 2인의 짧은 조작 안내와 대상 강조, 언제든 스킵, 메뉴→게임 방법/안내 켜기/이야기 도입 다시 보기.
- 배경 서술과 인물 대화 스타일 구분. 기존 일러스트 활용, 지도 밖 회색 영역 개선. 전장 원화·스프라이트·음악 교체는 아직 하지 않음.
- 기존 9종 + 모바일 UI + first_play_test PASS. Godot 4.3 웹 빌드 성공. 브라우저 WebGL2/secure context 미지원으로 실제 렌더링·터치·청취와 실물 휴대폰 미검증.
- 다음 ㄱㄱ: 회차 2, 잿빛 왕관 첫 전장 캐릭터·지형·HUD 아트 개선 및 시각 검증. 이후 경계의 서약→나머지 SRPG/RPG→덱빌딩.

## 2026-10-25 — 거점·전투 BGM
- 오리지널 16마디 거점곡50.53초·전투곡36.23초. 장면별 전환, 기존 음소거·개별 볼륨·배경 정지와 저장 형식 유지. 원본 재생성 tools/compose_audio.py (외부 샘플 없음).
- Godot 4.3 필수 검사9종 및 Web 내보내기 통과. 재생성한 WAV2종의 Git blob 해시가 테스트한 출력과 동일함을 재확인. 실물 휴대폰 청취 미검증.

# 인수인계 문서 (HANDOFF)

> 다른 AI가 이어받는다면 먼저 [AGENTS.md](AGENTS.md)를 읽으세요. 초상화 원본은 `art/source/portraits_raw/`에 백업되어 있습니다.

다른 AI/개발자가 이어서 작업할 수 있도록 정리한 문서입니다. 마지막 갱신: 2026-10-25 (장별 난이도 곡선 정리, GPT 거점·전투 BGM 676cbf7 위에서 작업).

## 1. 프로젝트 개요
- 표시 제목: **잿빛 왕관: 새벽의 서약** / **Ashen Crown**.
- GBA 파이어엠블렘 스타일 SRPG. **Godot 4.3 / GDScript**, **휴대폰 세로 720x1280**, 터치 전용, 한국어 UI.
- 플레이: https://junsa80.github.io/srpg-prototype/ (repo `junsa80/srpg-prototype`, `main` 브랜치 `/docs` 폴더 = GitHub Pages)
- 구현 범위: **본편 완결** — 1~27장 + 종장(그림자의 심연) + 3장 이후 분기(4A 노르드 / 4B 사르한), 엔딩 3종(새벽/잿빛/기본, `ChapterData.ending_id`; 14장 떠나보냄 = 기본), 종장 빛 기둥(`L`, `light_only_heal`). 거점(상점·수송·장비·상태·저장·지원·환생), 프롤로그/턴 이벤트/야영/지원 대화, 모든 보스·화자 초상화.
- 배포 파일: 커밋은 `git log -1`, `docs/index.pck` md5 `f8be1bd81b175d437ca9a06e4efb7692` (2026-10-25 장별 난이도 곡선, 배포 커밋 9b85ae1, 라이브 일치 확인). 실제 배포 완료는 §10.3의 라이브 파일 해시로 확인.
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
$G --headless res://tests/drop_test.tscn -- --flowtest    # 처치 드롭 감사: 일반 무기 드롭 없음, 장당 고정 ≤2(보스 제외), 무작위 ≤1%/5% (DROP_REPORT_ONLY=1 = 보고만)
$G --headless --script tests/consistency_test.gd      # 맵·대본·클래스·무기·초상 정합성 (초상 누락=WARN)
$G --headless res://tests/sim_test.tscn -- --flowtest      # 밸런스 시뮬 (SIM_ONLY=ch6, SIM_V=1, SIM_NOHEAL=1)
# 웹 빌드 (export_presets.cfg: thread_support=false → COOP/COEP 없는 정적 호스팅 OK)
$G --headless --export-release Web build/web/index.html
rm -rf docs && cp -r build/web docs && touch docs/.nojekyll docs/.gdignore
git add docs <내가 바꾼 파일들> && git commit -m "[GrokBot] ..." && git push origin main   # git add -A 금지 (§10.6)
# 배포 확인
gh api repos/junsa80/srpg-prototype/pages/builds/latest --jq '.status+" "+.commit'
curl -s https://junsa80.github.io/srpg-prototype/index.pck | md5sum; md5sum docs/index.pck
```
- `gh auth`는 사용자 계정(junsa80)으로 로그인된 상태여야 push/release 가능. **토큰을 커밋하지 말 것** (커밋 전 `rg -l "gh[op]_[A-Za-z0-9]{20}" .`).
- `--script` 모드 테스트(selftest, skills_test)는 autoload(Campaign/Settings/Sfx/Menus)를 못 씀 → `unit.gd`, `battle_manager.gd`에서 autoload 참조 금지(정적 변수 사용, 예: `Unit.show_badge`).
- 개발용 URL 해시(여러 개는 `,` 또는 `+`로 연결): `#goto=chX`, `nodialog`, `noprep`(출전 준비 생략), `safearea=TOP,BOTTOM`(CSS px 노치 흉내), `combat`/`combatfx`/`combatfx+magic`/`boss`/`late`(전투 장면), `mapview`, `devwin`(적 전멸·클리어 화면), `forecast`, `#base+ch2`, `#nodialog+effdemo`(특효 위협 표시)·`effdemofc`(+예측 창).

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
- 특효: 태그 armor/cavalry/flying(`ClassProfs.TAGS`) × 무기 `eff`(`Weapons.TRAITS`) → 무기 위력 ×`BattleManager.EFF_MULT`(3). 표시: 맵 붉은 칩(`Unit.eff_weapon_tags`), 아군 탭 시 위협 적 빨간 "!"(`battle.eff_threats`/`mark_threats`, `Unit.threat_mark`), 약점 문구 `Weapons.weak_text`, 예측 창·전투 이름판 "특효! ×3"(노드 이름 `Eff`).
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
- **전투 장면** (`scripts/combat_scene.gd`, 순수 연출): `BattleManager.resolve()`가 끝난 뒤 `events`를 재생. `resolve()`는 시작 시 `pre_fc = forecast(a, d)`(위력/명중/치명 표시용, RNG 미사용)와 타격마다 `ev.w`(무기)를 기록. 배치는 `get_viewport().get_visible_rect()` 높이에 맞춰 중앙 정렬. 무기 종류별 `_attack_motion()`, `_tw()`/`_wait()`는 재생 속도 `spd`를 따름(설정 빠르게=2, 화면 터치=4, [건너뛰기]=12). 설정 `Settings.anim`(켬/끔) + `Settings.anim_fast`. 스크린샷용 개발 훅 `#combat+nodialog`(실전 1회), `#combatfx+nodialog`(활 MISS+치명 시각 재생, 상태 변경 없음). 테스트 `qol_test`: 모든 무기 모션·사망·회복 재생 완료, HP 불변, anim_fast 저장.
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
2. 보리스 전용 초상화·SD 완료. **아트 감사 `story/ART_AUDIT.md`** (재생성: `tools/art_audit.gd`): 임시(코드 생성) 초상 12명 → 2026-10-17 교체 완료, 구형 96px 3명+상인, 이름 NPC 화자 초상 없음 22명. 그림자 일반병 5종·바르가스 SD는 chibi.py로 통일(원본 `assets/user_art/sliced/*_old_sheet.png`). SD만 다시 만들 땐 `tools/chibi.py`를 모듈로 불러 `class_sheet()`로 해당 유닛만 생성(전체 재실행은 모든 시트를 덮어씀).
3. 실기기 확인 (`DEVICE_CHECKLIST.md` 15항목). safe area: 2026-10-20 `scripts/safe_area.gd` 추가(CSS env + viewport-fit=cover), 에뮬레이션만 확인 — 실제 아이폰 노치/안드로이드 제스처 바 확인 필요.
4. 원안 메커닉(보류): 5장 안개, 6장 성 안/밖 분할·노아 침식, 7장 호위 NPC.
5. 클라우드 저장 미구현 (UI에 "미지원" 표기). 로컬 내보내기/가져오기·손상 복구는 구현.
6. 스크린샷 러너: 모바일 4기종 일괄 `node tools/mobile_check.js`(§10.4). 연속 프레임은 `/workspace/shotrunner/battle_shot.js` (puppeteer-core, 새 프로필, 390x844 모바일; `URL=... OUT=dir T0 N DT` 프레임 연속 캡처). box 초기화 시 `npm i puppeteer-core@23` 재설치. 전투 전후 비교 `build/battle_before.png`/`battle_after.png`.
8. 전투 장면 후속 후보: 클래스별 공격 프레임(현재 SD 3프레임 대기 애니만), 지형별 배경 그림, 전용 효과음(활 시위/마법), 원거리 시 카메라 팬.
7. 시뮬 AI가 조잡함 (탈출·제압형 목표에서 사망 과대 추정, 예: ch23 평균 사망 4.9 — 2026-10-17 완화 전 6.4).

### 이어서 작업하는 법
- 새 장 추가: `data/maps.gd` CH 항목 → `chapters/chapter_data.gd` CHAPTERS/EVENTS/CAMP/SUPPORTS → `scripts/campaign.gd` NEXT, `data/roster.gd` CH_INDEX → `tests/campaign_test.gd`·`tests/sim_test.gd` PLAN → 시뮬 → 빌드·배포. 이야기 이름 보스는 `Bosses.ALIAS`로 기존 패시브 연결.
- 초상화: 원본을 `art/source/portraits_raw/<이름>.png`(작업 사본 `/workspace/portraits_raw/`)에 두고 128px 정사각 크롭 → `assets/portraits/<이름>.png` → `tests/consistency_test.gd`로 누락 확인.
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


## 드롭 규칙 (2026-10-17)
- 무작위: `battle.gd` DROP_W/DROP_I = 1%, 정예(guard/elite) 5%. `Battle.junk()`(E/D랭크·특효/용사 아님, 상처약)는 굴리지 않음.
- 고정(`maps.gd` "drop"): 보스 + 장마다 0~2개. 적의 장비 무기를 그대로 고정 드롭하지 말 것 (`drop_test`가 막음). 노란 사각 = 드롭 표시.
- 전투 맵 빈 칸 탭 = 지형 정보만, 메뉴는 [메뉴] 버튼 전용.

## 전투 장면 리그 / 포즈 / 상성 색 (2026-10-17)
- `combat_scene.gd`: 유닛 상자 128x144 고정(PX=4, 머리 0-15행 4x4, 몸 16-31행 4x5; 기마·비행은 128x128 균일). `_make_rig()` = [보스 오라] + 테두리 4장(적 붉은 림, 아군 금색, 셰이더 실루엣) + [아군 스카프] + 몸. `inner.scale.x=-1`로 왼쪽 유닛 반전, `lean` 메타로 기울기.
- 포즈: `pose_set(u)` → `assets/battle/<이름@클래스|이름|클래스>/{ready,attack,hit,dodge}.png` (왼쪽 바라봄, 64x72 권장 → 2배). `_pose(u, p)`가 모션 타이밍에 교체(이미지 없으면 기울기만 변화). 배경 `bg_texture()` → `assets/battle/bg/<지형|바닥>.png`. 자세한 규칙 `assets/battle/README.md`.
- class_id(= `unit_class.name`): 용병 궁수 시스터 성기사 비숍 마법사 아머나이트 소셜나이트 비룡기사 드래곤마스터 도적 전사 워리어 버서커 영웅 스나이퍼 발키리 세이지 제네럴 팔라딘 그레이트나이트 레인저 메이지나이트 로그 드래곤나이트 어쌔신 검성 / 적 전용: 그림자 병사 그림자 창병 그림자 궁병 그림자 술사 그림자 중갑병 그림자 기병 그림자 비룡 바르가스 그림자 지휘관.
- 상성 색 `Icons.TRI` (검 파랑 / 도끼 빨강 / 창 초록), `Icons.tri_color()/tri_text()`. 공식은 `WeaponData.triangle()` 그대로.
- 맵 스프라이트 실루엣: `tools/fe_sprites.py`(계열별 그리기) + `tools/chibi.py` `SPEC`(클래스→계열·상급 장식). 적 일반 시트 `<클래스>_적.png`. 참조 시트 `build/class_sprites_sheet.png`.
- 스프라이트 색: `python3 tools/portrait_palette.py && python3 tools/chibi.py` (자동 추출 + `OVERRIDE` 손보정, 결과 `tools/portrait_palette.json`). 확인 `build/palette_compare.png`.
- NPC 초상 별칭 `Sprites.NPC_ALIAS` → `assets/portraits/npc_<type>.png` (파일 없으면 그림 없음).

## GBA FE식 전투 화면 / 아이콘 (2026-10-17)
- 참고 메모 `assets/battle/REFERENCE_NOTES.md` (구조·아이콘 관례; 원작 그림 미사용, 전부 코드로 그린 원본).
- 아이콘: `python3 tools/make_icons.py` → `assets/icons/<id>.png` 16x16 50종 + `build/icons_sheet.png`. 무기 이름→id `Icons.ICON_ID` (새 무기 추가 시 한 줄 + 생성기에 그림, 없으면 `icon_id()`가 종류+등급으로 대체, 파일도 없으면 옛 절차 아이콘). `Icons.rect(w, px)`는 16의 배수로 내림(`px_snap`). 추가 후 `godot --headless --import`.
- 배경·발판: `python3 tools/make_battle_bg.py` → `assets/battle/bg/*.png`(240x160) + `assets/battle/platform/*.png`(64x16) + `build/battle_bg_sheet.png`. 매핑 `CombatScene.BG_OF_TERRAIN/BG_OF_GROUND/PLAT_OF_TERRAIN/PLAT_OF_GROUND`.
- `combat_scene._setup()` 세로 배치: 이름판(100) | 무대 160*BS(BS=3) | 아래 창(232) | 안내+[건너뛰기]. `AY` = 무대 위 + 130*BS. 위쪽 = max(`_safe_top()`+18, 중앙 정렬). 아래 창 노드: `StatBox`(S_HIT/S_DMG/S_CRT, X2), `Tri`, `Eff`, `HPNum`, `HPBar`(칸 = `bars[u][0]` 배열). 발판 `PlatformL/R`, 배경 `BattleBG`.
- 스크린샷: `URL='http://127.0.0.1:18931/#combat+late+nodialog'`(근접) / `#combatfx+late+nodialog`(활) / `#combatfx+magic+late+nodialog`(마법) + `shotrunner/battle_shot.js` (T0=9000). 결과 `build/battle_fe_ref.png`.

## 10. 혼자 이어받기 (2026-10-20 정리)

### 10.1 환경 준비 (box/PC가 초기화됐을 때)
```bash
gh repo clone junsa80/srpg-prototype /workspace/srpg      # gh auth login (junsa80) 필요
cd /tmp && wget https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip && unzip -o Godot_v4.3-stable_linux.x86_64.zip
# 내보내기 템플릿 (웹 빌드에 필수, 버전 4.3.stable 정확히 일치)
wget https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz
mkdir -p ~/.local/share/godot/export_templates/4.3.stable && unzip -j -o Godot_v4.3-stable_export_templates.tpz 'templates/*' -d ~/.local/share/godot/export_templates/4.3.stable
G=/tmp/Godot_v4.3-stable_linux.x86_64; cd /workspace/srpg && $G --headless --import   # class_name 캐시 생성 (새 스크립트 추가 후에도)
# 스크린샷용: Chrome(/usr/bin/google-chrome) + puppeteer-core
mkdir -p /workspace/shotrunner && cd /workspace/shotrunner && npm init -y && npm i puppeteer-core
```
- Godot는 반드시 **4.3-stable** (다른 버전은 .godot 캐시·export 템플릿 불일치).

### 10.2 테스트 9종 + 시뮬
```bash
G=/tmp/Godot_v4.3-stable_linux.x86_64
for t in flow_test menu_test weapons_test campaign_test qol_test drop_test; do $G --headless res://tests/$t.tscn -- --flowtest 2>&1 | grep -E "PASS|FAIL"; done
for s in selftest skills_test consistency_test; do $G --headless --script tests/$s.gd 2>&1 | grep -E "PASS|FAIL"; done
$G --headless res://tests/sim_test.tscn -- --flowtest            # 전 장 16판 (수십 분). SIM_ONLY=ch23 단일 장, SIM_V=1 상세
DROP_REPORT_ONLY=1 $G --headless res://tests/drop_test.tscn -- --flowtest   # 드롭 수량 보고
```
- 각 테스트는 마지막에 `XXXTEST PASS` 출력. 종료 시 `ObjectDB leaked`/`resources still in use` 경고는 정상(무시).
- 시뮬 목표·측정 규격: **`tests/SIM_SPEC.md`** (장당 96판 `SIM_TRIALS=96`, 시드·난이도·성장·장비·AI 고정). 결과는 `tests/sim_results.txt`에 손으로 추가. 기본 16판은 회귀 확인용(±12%p 흔들림).

### 10.3 빌드 · 배포 · 확인 순서
1. 소스 수정 → 2. 테스트 9종 PASS → 3. 소스 커밋·푸시 → 4. HANDOFF/CHANGELOG 갱신 → 5. 배포:
```bash
$G --headless --export-release Web build/web/index.html       # 템플릿 없으면 여기서 실패
rm -rf docs && cp -r build/web docs && touch docs/.nojekyll docs/.gdignore
git add docs && git commit -m "[GrokBot] 배포: ..." && git push origin main
sleep 60; gh api repos/junsa80/srpg-prototype/pages/builds/latest --jq '.status+" "+.commit'   # built + 내 커밋
curl -s "https://junsa80.github.io/srpg-prototype/index.pck?$(date +%s)" | md5sum; md5sum docs/index.pck   # 두 값 일치 = 배포 완료
git log origin/main --oneline -3                                # GitHub에 커밋 확인
```
- `.nojekyll`: Pages가 `_`로 시작하는 파일을 숨기지 않게. `.gdignore`: Godot가 docs/를 리소스로 import하지 않게(둘 다 필수).
- **`build/web/`는 git에서 제외**(2026-10-20, `.gitignore`). 배포본은 `docs/`만 커밋한다. 예전엔 `build/web`이 추적돼서 export 때마다 "커밋 안 된 변경"이 남았음.
- `index.html`의 `viewport-fit=cover`는 `export_presets.cfg`의 `html/head_include`로 넣는다 (export마다 index.html이 다시 생성되므로 직접 수정 금지).

### 10.4 모바일 화면 확인 (puppeteer 에뮬레이션)
```bash
(cd build/web && python3 -m http.server 18931 &)
PP=/workspace/shotrunner/node_modules/puppeteer-core node tools/mobile_check.js     # SIZES=360x640,430x932 MODES=prep,map,forecast,combat 로 좁히기
```
- 결과 `build/mobile_check/<WxH>[_notch]_<prep|map|forecast|combat>.png` (360x640·375x667·390x844·430x932, `_notch` = `#safearea=47,34`).
- 화면 기준: 가상 720px 폭(canvas_items/expand) → 360px 폰에서 0.5배. **버튼 높이 ≥ 88 가상 px = 44 CSS px**. 하단 버튼 줄 90/104, 전투 [건너뛰기] 240x92, 줌 88x88.
- safe area: `SafeArea.insets(viewport)` = (위, 아래) 가상 px. 웹은 CSS `env(safe-area-inset-*)`, 해시 `safearea=` 우선, 아래 최소 8 CSS px. 네이티브는 `DisplayServer.get_display_safe_area()`. 사용처: `battle.gd` `sa`(하단 패널·줌·상단 창·예측 창), `combat_scene._safe_top()`·btn_h.

### 10.5 그림 파이프라인
- 초상화: 원본(정사각 크롭) `art/source/portraits_raw/<이름>.png` (저장소 백업, 작업 사본 `/workspace/portraits_raw/`) → 128x128 `assets/portraits/<이름>.png` (`PIL resize LANCZOS`). NPC 공용 `npc_<type>.png` + `Sprites.NPC_ALIAS`. 확인 `tests/consistency_test.gd`(누락 WARN), 감사 `tools/art_audit.gd` → `story/ART_AUDIT.md`.
- 맵 스프라이트: `python3 tools/portrait_palette.py && python3 tools/chibi.py` (실루엣 `tools/fe_sprites.py`, 클래스→계열 `chibi.SPEC`). 일부만: `chibi.class_sheet()`.
- 전투 포즈: `assets/battle/<이름@클래스|이름|클래스>/{ready,attack,hit,dodge}.png`, **왼쪽을 바라보게**, 64x72(2배 표시). 배경 240x160 `assets/battle/bg/`, 발판 64x16 `assets/battle/platform/` (`tools/make_battle_bg.py`). 아이콘 16x16 `tools/make_icons.py`.
- 그림 추가 후 `$G --headless --import`.

### 10.6 세이브 호환 · 주의점
- 저장: `user://save_<0-3>.json`(0 = 자동), `.tmp`에 쓰고 rename, `.bak` 보존, 손상 시 `{"corrupt":true}`. 내보내기 `SRPGSAVE1:`+base64. 엔딩 `ending_<id>`, 이탈 목록 `absent`.
- **규칙**: 기존 키 이름·의미를 바꾸지 말 것, 새 키는 기본값으로 읽기(`get(k, 기본)`), 설정 기본값 유지. 클래스 기본 스탯·성장률·전투 공식 변경 금지.
- 흔한 함정: (1) box/PC 초기화 → Godot·템플릿·puppeteer 재설치, `build/` 파일이 지워져 보이면 `git checkout -- build`. (2) 여러 작업자가 같은 폴더 → **`git add -A` 금지, 자기 파일만 stage**. (3) 새 `class_name` 스크립트는 `--import` 전엔 테스트에서 "identifier not declared". (4) Pages 캐시: md5 확인 시 `?타임스탬프` 붙이기. (5) `--script` 테스트에서 autoload 사용 불가.

### 10.7 남은 일 (2026-10-20)
- 아린 초상화 다시 그리기(현재 소년처럼 보임).
- 클래스별 전투 포즈 그림(아린·레온·리나·마법사 시험부터).
- 구분이 약한 스프라이트 짝: 성기사/팔라딘, 소셜나이트/레인저, 비룡기사/드래곤나이트, 그림자 창병/그림자 중갑병.
- 실기기 확인 `DEVICE_CHECKLIST.md`(특히 노치·핀치·오디오·클립보드).
- enemy_lv 업데이트 재시작 초기화 여부(유지 권장), 클라우드 저장 미구현.

## 11. 2026-10-22 GPT 모바일 UI 작업
- 기준 main: `a86ba179dfd3711a662679d890576953fdd8a168`. 타이틀을 세로 자동 배치로 바꾸고 기존 요새 배경을 사용. 환생·완전 초기화는 [환생 · 기록 관리]에서 접근하며 기존 초기화 확인 절차 유지.
- 공통 메뉴·아이템·거점·출전 준비에 safe area 적용. 긴 확인창은 화면 높이에 따라 여백을 제한. 공통 본문/버튼 글꼴 최소 24 가상 px. 기본 스탯·성장·공식·저장 형식 변경 없음.
- 예측 창 높이 480, 이름과 특효를 세로 배치. 안내문을 실제 폭이 결정된 뒤 재측정해 높이 1273까지 늘어나 패널을 벗어나던 문제 수정.
- 테스트 9종 전부 PASS. 추가 `tests/mobile_ui_test.tscn`: 4개 화면 크기에서 타이틀 버튼 경계/최소 높이, 기록 관리 진입 시 진행 보존, 긴 확인창, 예측 패널/안내문 경계, 준비 시작 버튼 경계 검사. Godot headless의 가상 좌표 검사이며 실제 폰/웹 터치 검증이 아님. 격리한 XDG_DATA_HOME에서 실행.
- Godot 4.3-stable 웹 릴리스 내보내기 성공. 원본 백업 `art/*`, 스토리 문서 `story/*`를 내보내기 제외에 추가. 런타임 이미지는 기존 assets/ 사용.
- 브라우저 QA 제한: 관리형 로컬 미리보기는 시작했으나 이 브라우저가 WebGL2와 secure context 미지원 오류를 표시해 게임 렌더링/스크린샷 검증 불가. 실기기 노치·터치·오디오·클립보드는 DEVICE_CHECKLIST 미검증 항목으로 유지.

### 표시 제목 변경 (2026-10-22)
- 「잿빛 왕관」 / 「새벽의 서약」 / Ashen Crown. 타이틀 주제목·부제, DisplayServer 창 제목, 웹 HTML title 및 export head_include, README에 반영.
- 중요: 내부 `application/config/name="SRPG Prototype"`은 기존 user:// 저장/설정 경로를 유지하려고 보존. 표시 제목과 별개이며 변경하지 말 것.
- 제목 변경 후 회귀 9종 + 모바일 UI 경계 검사 PASS. Godot 4.3 --export-pack으로 웹 PCK 재생성, 검증된 기존 JS/WASM 런타임 유지, HTML의 PCK 크기 갱신. 실기기/브라우저 렌더링 QA는 위 제한 그대로.

## 10.4 인게임 그래픽 업리프트 (2026-10-23)
- 타이틀: `assets/ui/title_key.png`(허브 커버 v1, 하단 바 제거) 전체 배경 + 주 버튼(이어하기·새 게임) / 보조 줄(불러오기·설정·기록 HBox). `scripts/title.gd`.
- HUD: 지형·유닛 창·전투 힌트·설정 TextEdit 등 직접 font_size <24 → 24 (캔버스 720→360 CSS에서 ≥12px). `battle.gd` / `combat_scene.gd` / `menus.gd`.
- 맵 스프라이트: 표지 캐스트만 팔레트 연결 — 아린 navy, 세라 white-teal, 가렌 grey-leather (`tools/portrait_palette.py` OVERRIDE → `chibi.py` 재생성, 해당 유닛 시트만 변경).
- 전후 스크린(로컬): `build/gfx_uplift/after_title_{360,390}.png`, `after_map_*`, `after_forecast_*`, `before_title_art_fort.png`.
- 밸런스·세이브·공식 변경 없음.

## 2026-10-23 GPT 그래픽 작업 재개·통합
- 이전 `ai/gpt/graphics-20261023`(3386dfb)의 키아트·성인 여성 용병 아린 초상·Ornate 색상·전장 그림자/칸/행동 표식을 최신 main 9afee37 위에 통합.
- main의 주/보조 타이틀 버튼 배치, HUD 24px 이상, 캐스트 팔레트는 유지. 배경만 전용 성채 키아트로 연결. 기존 hub 커버 파일은 보존.
- 원래 브랜치의 PCK를 덮어쓰지 않고 Godot 4.3으로 통합 소스에서 다시 export-pack. 검증된 JS/WASM 유지, HTML의 실제 PCK 크기 갱신.
- 회귀 9종과 모바일 UI 경계 검사 PASS. 모바일 UI 검사는 `--flowtest` 없이 실행(이 플래그는 타이틀을 건너뛰므로 타이틀 검사에 사용 금지).
- 새 생성 작업은 없으며 기존 브랜치의 완성 이미지를 재사용. 실제 폰의 WebGL 렌더링/색감/터치는 미검증.
- 아린 초상은 `Sprites.portrait`에서 arin-v3.png로 연결 완료. §10.7의 아린 재그리기 항목은 완료 상태로 대체.

## 12. 2026-10-25 장별 난이도 곡선 정리 (GrokBot)
- 기준: GPT 오디오 PR #4 머지 `676cbf7`(거점·전투 BGM, `assets/sfx/bgm_*`, `tools/compose_audio.py`) 위에서 작업. 오디오 파일·설정은 건드리지 않음.
- 근거: 품질 감사(곡선 4점, 4B·6장 5/16 ↔ 7장 14/16). 측정 규격 `tests/SIM_SPEC.md` — 장당 96판, 시드 t=0..95, 보통 난이도, 고정 성장, PLAN 레벨/영입/무기 단계, 아군은 적과 같은 전술 AI + 안전 검사. `SIM_TRIALS` 환경 변수 추가(기본 16 유지).
- 바꾼 것은 `data/maps.gd`의 장 데이터뿐: 적 수, 증원 턴, 적 Lv, 장비, 보스 보너스(보스 전용 고정치). 기본 스탯·성장률·전투 공식·목표·드롭 규칙·저장 형식 그대로. 7장 8턴 방어, 종장 빛 기둥 유지.
- 저장 호환: 증원은 **지우지 말고 맨 뒤에만 추가** (전투 중 저장 `reinf_done`이 증원 번호를 기억). 3장 8턴 증원을 지웠으므로 `battle.gd _restore`에 없는 번호를 건너뛰는 안전장치 추가.
- `tests/flow_test.gd` 증원 검사는 2장 첫 증원을 맵 데이터에서 읽음(2장 = 6턴 1명).
- 상급 적은 Lv 1이 크게 흔든다(18장 벨크 Lv11→12만으로 79%→43%). 보스 Lv을 올릴 땐 보너스 HP를 같이 낮춰 맞춤(벨크 Lv12·HP+14 = 52%).
- 의도된 고비(이웃보다 낮아도 둠): 4A(분기 방어), 6(1부 탈출), 13(그라이브), 18(벨크 재대결), 24(대전장), 27(그림자 왕), 종장. 남은 역전: 7장 79%(방어전은 시뮬이 맵 변화에 둔감 — 증원 Lv·장비·추가 증원·마법사 추가 4가지 모두 ±3%p라 원상 유지, 6장 고비 직후 숨 고르기로 둠), 10·16장(70%대).

전후 표 (보통, 장당 96판):

| 장 | 전 승률 | 후 승률 | 변화 | 후 평균 턴 | 후 평균 사망 | 분류 |
|---|---|---|---|---|---|---|
| ch1 | 96/96 (100%) | 96/96 (100%) | +0 | 3.3 | 0.9 | 튜토리얼 |
| ch2 | 39/96 (41%) | 56/96 (58%) | +17 | 14.6 | 3.5 | 수정(초반 역전) |
| ch3 | 44/96 (46%) | 60/96 (62%) | +16 | 14.0 | 4.0 | 수정(초반 역전) |
| ch4a | 49/96 (51%) | 48/96 (50%) | -1 | 9.0 | 5.5 | 의도 고비(분기 방어) |
| ch4b | 34/96 (35%) | 50/96 (52%) | +17 | 12.1 | 4.8 | 수정(4B 스파이크) |
| ch5 | 43/96 (45%) | 55/96 (57%) | +12 | 12.5 | 3.8 | 수정(초반 역전) |
| ch6 | 45/96 (47%) | 47/96 (49%) | +2 | 11.4 | 3.8 | 의도 고비(1부 클라이맥스 탈출) |
| ch7 | 76/96 (79%) | 76/96 (79%) | +0 | 9.0 | 2.4 | 남음(방어전, 시뮬 한계) |
| ch8 | 55/96 (57%) | 53/96 (55%) | -2 | 8.5 | 2.6 | 변경 없음 |
| ch9 | 60/96 (62%) | 59/96 (61%) | -1 | 10.4 | 4.4 | 변경 없음 |
| ch10 | 77/96 (80%) | 72/96 (75%) | -5 | 9.2 | 2.4 | 소폭 |
| ch11 | 82/96 (85%) | 65/96 (68%) | -17 | 10.3 | 4.1 | 수정(골짜기) |
| ch12 | 71/96 (74%) | 66/96 (69%) | -5 | 4.8 | 1.1 | 소폭 |
| ch13 | 55/96 (57%) | 56/96 (58%) | +1 | 9.1 | 2.8 | 의도 고비(그라이브) |
| ch14 | 54/96 (56%) | 61/96 (64%) | +8 | 12.8 | 3.1 | 수정(스파이크) |
| ch15 | 65/96 (68%) | 66/96 (69%) | +1 | 17.7 | 4.9 | 소폭 |
| ch16 | 94/96 (98%) | 75/96 (78%) | -20 | 18.3 | 2.7 | 수정(골짜기) |
| ch17 | 68/96 (71%) | 69/96 (72%) | +1 | 14.6 | 1.5 | 변경 없음 |
| ch18 | 80/96 (83%) | 50/96 (52%) | -31 | 14.5 | 5.4 | 의도 고비(벨크 재대결) |
| ch19 | 77/96 (80%) | 63/96 (66%) | -14 | 18.5 | 3.9 | 수정(골짜기) |
| ch20 | 70/96 (73%) | 55/96 (57%) | -16 | 12.9 | 3.1 | 수정(골짜기) |
| ch21 | 79/96 (82%) | 63/96 (66%) | -16 | 7.7 | 5.4 | 수정(골짜기) |
| ch22 | 67/96 (70%) | 62/96 (65%) | -5 | 11.3 | 5.9 | 소폭 |
| ch23 | 83/96 (86%) | 54/96 (56%) | -30 | 6.0 | 6.5 | 수정(골짜기) |
| ch24 | 56/96 (58%) | 59/96 (61%) | +3 | 12.2 | 4.9 | 의도 고비(대전장) |
| ch25 | 82/96 (85%) | 58/96 (60%) | -25 | 6.9 | 5.2 | 수정(골짜기) |
| ch26 | 69/96 (72%) | 61/96 (64%) | -8 | 11.1 | 4.5 | 수정(골짜기) |
| ch27 | 53/96 (55%) | 51/96 (53%) | -2 | 13.7 | 6.5 | 의도 고비(그림자 왕) |
| final | 64/96 (67%) | 51/96 (53%) | -14 | 14.3 | 6.1 | 의도 최종 고비 |
