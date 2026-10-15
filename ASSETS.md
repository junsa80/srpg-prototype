# 에셋 가이드 (파일 이름만 맞추면 바로 교체됩니다)

## 드롭인 경로 / 규격
| 종류 | 경로 | 규격 |
|---|---|---|
| 대화 초상화 | `assets/portraits/<이름>.png` (예: `노아.png`) | 정사각형 96x96 또는 128x128 PNG, 흉상. 금테 프레임은 게임이 그림 (프레임 없는 그림 권장) |
| 맵 유닛 스프라이트 | `assets/units/<유닛 이름 또는 클래스>.png` (예: `카엘.png`, `그림자 궁병.png`) | 32x32 프레임을 **가로로** 나열 (예: 64x32 = 2프레임 대기 모션). 투명 배경. 이름 파일이 클래스 파일보다 우선 |
| 지형 타일 | `assets/tiles/<종류>.png` | 32x32, 종류: `plain`, `grass2`, `flower`, `forest`, `forest2`, `forest3` (없으면 Kenney 타일 사용) |
| 효과음 | `assets/sfx/<이름>.wav` | cursor, select, cancel, hit, crit, miss, levelup, heal, phase, bgm(루프) |

교체 후 `godot --headless --import` → 웹 빌드 다시 내보내기.

## 사용자 아트 처리 결과 (assets/user_art 원본은 .gdignore로 빌드 제외)
- 파일 이름과 내용이 달랐습니다: `character_portrait_1` = 숲 타일셋, `character_portrait_2`·`shadow_soldier_portrait` = 숲 맵 샘플, `character_portrait_3`·`forest_map_sample` = 그림자 병사 초상화(금/보라 장식 프레임). **노아/카엘/미라 초상화는 없었습니다.**
- 숲 타일: `forest_tileset_1.jpg`에서 잔디·꽃·소나무/활엽수 칸을 잘라 32x32로 축소·감색 → `assets/tiles/`
- 그림자 병사: `shadow_sprites.jpg`(가짜 체크무늬 배경)에서 배경 제거 후 32x32, 16색 감색, 적 외곽선 추가 → `assets/units/그림자 병사|창병|지휘관.png`. 궁병/술사는 원본에 없어 병사 스프라이트 재사용.
- 초상화: 프레임 안쪽 얼굴 부분을 128x128로 → `assets/portraits/그림자 병사.png`, `그림자 지휘관.png` (창병/궁병/술사는 병사 초상화 재사용)
- 숲 맵 샘플 2장은 참고용(2장 숲 배치 참고)으로만 사용

## 2차 업로드 (06:49)
- 이번에도 파일 이름이 서로 바뀌어 있었습니다: `cael_portrait.jpg` = 그림자 궁병 스프라이트 8포즈, `shadow_archer_sprites.jpg` = 카엘 초상화 카드(CAEL / KNIGHT). `mira_portrait.jpg`, `shadow_mage_sprites.jpg`는 이름대로.
- 카엘·미라: 카드 안쪽 얼굴 부분을 128x128로 → `assets/portraits/카엘.png`, `미라.png` (카드의 이름판/프레임은 잘라냄; 게임 금테 프레임 사용)
- 그림자 궁병: 정면 2포즈 → `assets/units/그림자 궁병.png` (2프레임), 그림자 술사: 정면/측면 → `assets/units/그림자 술사.png`
- 노아 초상화는 아직 없음 → 업로드되면 `assets/portraits/노아.png`로 교체

## 생성 프롬프트 (추후 생성용)
공통: 16-bit 픽셀아트, GBA 파이어엠블렘 풍, 세련된 음영과 하이라이트, 선명한 외곽선, 고급스러운 팔레트, 투명 배경.
- 아군 8+2인 맵 스프라이트 32x32 (정면/측면, 대기 2~3프레임): 아린(갈색 머리 젊은 용병, 철검), 노아(과묵한 검은 머리 선배 용병), 카엘(은색 판금 몰락 귀족 기사, 창), 리나(녹색 후드 궁수), 엘리아(금발 아카데미 마법사), 미라(보라 머리 불안정한 마법사), 루크(두건 도적), 세라(흰 갑옷 성기사 치유사), 에일린(분홍 머리 용병), 레온(방패 기사)
- 애니메 초상화 128x128 (금/검정 장식 프레임 없이), 표정 3종
- 타일셋: 꽃, 돌, 울타리, 집, 요새 벽/바닥/옥좌, 문, 보물상자
- 보스: 그림자 장군 바르가스 — 흑철 중갑, 양손 대도끼, 그림자 오라 (48x48 맵, 전투 컷)
