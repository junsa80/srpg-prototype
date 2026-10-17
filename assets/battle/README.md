# 전투 포즈 이미지 (드롭인)

`scripts/combat_scene.gd`가 자동으로 읽는다. 파일이 없으면 지금 맵 스프라이트 리그(머리 4x·몸 4x5 확대 + 테두리)로 대체.

- 경로: `assets/battle/<id>/{ready,attack,hit,dodge}.png` — id 찾는 순서: `<이름>@<클래스>` → `<이름>` → `<클래스>`.
  `ready.png`가 있어야 그 폴더를 쓴다. 나머지 포즈가 없으면 ready로 대체.
- 방향: **왼쪽을 바라보게** 그린다 (맵 시트와 같음, GBA FE처럼 아군이 오른쪽에 서서 왼쪽을 봄). 왼쪽에 서는 적은 자동 좌우 반전.
- 크기: 캔버스 **64x72 px** 권장 (정수 2배 = 화면 128x144, 맵 리그와 같은 크기). 발은 맨 아래 줄, 가로 가운데, 배경 투명.
  다른 크기도 되지만 144px 높이에 들어가는 가장 큰 정수 배율로 그려진다 (예: 48px 높이 → 3배).
- 포즈 시점: ready=대기, attack=공격 시작~타격(돌진/찌르기/도약/발사/시전 동안), hit=피격 순간~HP 감소, dodge=회피 스텝. 회복 지팡이 시전도 attack.
- 배경: `assets/battle/bg/*.png` 240x160 원본 8종(plain, forest, fort, castle, village, desert, snow, mountain; `tools/make_battle_bg.py`)을 정수 배율(3배)로 그린다. 고르는 순서: 방어측 지형 파일 `bg/<지형>.png` → 지형 별칭(throne/pillar/light→castle 등) → `bg/<바닥>.png` → 바닥 별칭(grass→plain, sand→desert) → plain.
- 발판: `assets/battle/platform/*.png` 64x16 (grass, forest, stone, floor, sand, snow, wood, rock), 유닛마다 자기 칸 지형으로 고른다. 발 위치 = 배경 원본 y 130.
- 화면 구조와 참고 메모: `REFERENCE_NOTES.md`.
- 파일을 넣은 뒤 `godot --headless --import` 후 내보내기(배포)하면 적용.
