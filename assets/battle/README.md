# 전투 포즈 이미지 (드롭인)

`scripts/combat_scene.gd`가 자동으로 읽는다. 파일이 없으면 지금 맵 스프라이트 리그(머리 4x·몸 4x5 확대 + 테두리)로 대체.

- 경로: `assets/battle/<id>/{ready,attack,hit,dodge}.png` — id 찾는 순서: `<이름>@<클래스>` → `<이름>` → `<클래스>`.
  `ready.png`가 있어야 그 폴더를 쓴다. 나머지 포즈가 없으면 ready로 대체.
- 방향: **왼쪽을 바라보게** 그린다 (맵 시트와 같음, GBA FE처럼 아군이 오른쪽에 서서 왼쪽을 봄). 왼쪽에 서는 적은 자동 좌우 반전.
- 크기: 캔버스 **64x72 px** 권장 (정수 2배 = 화면 128x144, 맵 리그와 같은 크기). 발은 맨 아래 줄, 가로 가운데, 배경 투명.
  다른 크기도 되지만 144px 높이에 들어가는 가장 큰 정수 배율로 그려진다 (예: 48px 높이 → 3배).
- 포즈 시점: ready=대기, attack=공격 시작~타격(돌진/찌르기/도약/발사/시전 동안), hit=피격 순간~HP 감소, dodge=회피 스텝. 회복 지팡이 시전도 attack.
- 배경: `assets/battle/bg/<지형>.png` (plain, forest, fort, throne, village, bridge, pillar, light, mountain …), 없으면 `bg/<바닥>.png` (grass, snow, sand, castle), 없으면 지금의 하늘·언덕 그림. 권장 240x160 px (가로로 꽉 차게 잘라서 그림).
- 파일을 넣은 뒤 `godot --headless --import` 후 내보내기(배포)하면 적용.
