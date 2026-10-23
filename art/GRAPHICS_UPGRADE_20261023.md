# 잿빛 왕관 그래픽 업그레이드 · 2026-10-23

## 범위와 사용 경로
- 전용 키아트: `assets/title/ashen-crown-keyart-v1.png` → 타이틀의 TitleArt. 원본 1536×1024, Godot 가져오기 최대 1024px, 품질 0.9 손실 압축. 이미지 자체에는 제목을 넣지 않고 게임의 한국어 글자로 표시.
- 아린 초상: `assets/portraits/arin-v3.png` → Sprites.portrait("아린")을 사용하는 대화/상태/거점/전장 정보. 가져오기 최대 256px, 무손실. 원본 `assets/portraits/아린.png` 보존.
- 최종 초상은 `story/ART_AUDIT.md`의 성인 여성 용병 설정을 기준으로 갈색 단발·푸른 용병복·검을 유지. 성별 설정을 확인하기 전의 초상 시안은 채택하지 않음.
- 남색·황동·아이보리의 공통 메뉴 프레임, 선명한 포커스와 비활성 버튼, 키아트 액자와 제목 그림자.
- 맵의 짧은 벽 그림자·가는 칸 경계. 기존 파랑 이동/빨강 공격/초록 회복 의미를 유지하면서 테두리와 각각 꺾쇠/교차/십자 모양을 추가. 순수 그리기 변경이며 이동·범위·위험 판정은 유지.
- 사용한 생성 방식: 내장 image_gen 도구. CLI/API 호출과 별도 API 키 사용 없음. 새 키아트는 새 생성, 초상은 기존 이미지 참조 편집. 외부 게임 이미지는 사용하지 않음.
- 기존 전투 배경·맵 유닛 스프라이트·세이브·공식·성장률·진행 데이터 유지.

## 최종 프롬프트

### 키아트
```text
Use case: stylized-concept. Asset type: original main-menu key art for a Korean classic tactical RPG called Ashen Crown, to be integrated in a Godot game (not a UI mockup). Create one landscape 1536x1024 illustration, no text or lettering. A weathered medieval royal citadel crowns a ridge above a misty war-scarred valley at first dawn, a winding stone approach and broken banners lead toward the gate. In the low foreground, a small formation of clearly adult armored travelers seen from behind surveys the distant castle, cloaks and practical full armor, no identifiable existing characters, no faces close up. A subtle broken-crown motif worked into a fallen stone relief, not a floating logo. Premium 1990s Japanese strategy RPG box illustration brought to refined modern painted concept art: confident inklike contours, textured gouache, cinematic layered depth, atmospheric but readable silhouettes. Deep ink navy and charcoal, tarnished brass highlights, restrained amber dawn cutting through cool ash haze; serious noble melancholy and hope. Central citadel and light are the focal point, foreground travelers stay small and low. Keep important composition within central 70 percent so cropping to a wide mobile title panel works. Fine craftsmanship, no generic glossy mobile-gacha style, no photoreal people, no young characters, no exposed skin or sexual content, no copied franchise characters, no typography, no letters, no UI, no watermark. This is the one finished in-game key art asset.
```

### 아린 (기존 초상 참조 편집)
입력: assets/portraits/아린.png
```text
Use case: identity-preserve. Edit target: the supplied original game portrait of Arin. Canonical identity is an ADULT WOMAN mercenary, age around 28, with short spiky brown hair, brown eyes, practical navy-blue mercenary armor with brass-gold piping and a diagonal brown leather strap. The reference drawing looks too much like a teenage boy: correct this while preserving the exact recognizable hair colour, short spiky haircut, blue/gold outfit and sword-bearing warrior role. Create a mature female swordswoman with a clear adult face, confident steady eyes, defined cheekbones and a composed resolute expression. No childish oversized eyes, no masculine boy face, no heavy makeup, no glamour styling. Square bust portrait with all hair and shoulders inside frame, three-quarter pose facing the same direction as the reference. Practical armor fully covers neck, chest and shoulders; no sexualized armor, no cleavage or bare shoulders. Painterly original classic tactical RPG character illustration, crisp shaped shadows and limited harmonious colour palette, clean silhouette legible at 128-256px, elegant restrained brushwork, simple deep charcoal/navy background. Chest-up only, no text, no frame, no logos, no photoreal person or franchise likeness. Preserve costume identity; the woman is a seasoned adult mercenary, not a princess in a gown or a teenage character. Finished square 1024x1024 game portrait.
```

## 검증
- Godot 4.3-stable. 기존 flow/menu/weapons/campaign/qol/drop/selftest/skills/consistency 9종과 mobile_ui_test의 화면 경계 검사.
- 원본 PNG 눈으로 검수: 실존 인물/글자/워터마크 없음, 갑옷을 입은 성인 캐릭터와 판타지 풍경.
- PCK는 기존 웹 런타임과 같은 Godot 4.3으로 재생성하고 docs/index.html의 PCK 크기를 갱신한다.
- headless 좌표 검사는 실제 폰/브라우저 렌더링 검사를 대신하지 않는다. 실기기 노치·터치·색감·성능은 미검증.

