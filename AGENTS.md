# AI_START — 다른 AI(Grok 다른 계정 / ChatGPT 등)를 위한 시작 안내

항상 **한국어**로 사용자와 소통합니다. 처음부터 다시 만들지 말고 기존 코드를 이어서 작업합니다.

## 읽는 순서
1. 이 파일 (AGENTS.md)
2. [HANDOFF.md](HANDOFF.md) — 특히 §5(사용자 제약), §10(환경·테스트·빌드·배포 절차)
3. [README.md](README.md) — 구조·조작
4. [CHANGELOG.md](CHANGELOG.md) — 최근 변경
5. 필요 시 `DEVICE_CHECKLIST.md`, `story/ART_AUDIT.md`, `assets/battle/README.md`, `art/source/portraits_raw/README.md`

## 절대 규칙
- 기본 스탯·성장률·공식 변경 금지.
- 기존 세이브·설정 호환 유지 (HANDOFF §10.6).
- 캐릭터는 모두 성인으로 묘사. 선정적·노골적 이미지는 GitHub에 절대 올리지 않음.
- `docs/`(배포 폴더)에 스포일러 문서 금지.
- **한 번에 한 AI만** 이 게임을 작업. GitHub `main` = 검증된 최신본(유일한 기준).
- 커밋 메시지 접두사: `[GrokBot]` / `[Grok]` / `[GPT]` 중 작성 AI에 맞게.
- `git add -A` 금지 — 직접 바꾼 파일만 지정해 stage.
- `build/web/`은 git 제외 (배포는 `docs/`로 복사).
- 작업 순서: 소스 수정 → 테스트 9종 → 커밋·푸시 → HANDOFF/CHANGELOG 갱신 → 배포 확인. GitHub에서 커밋 확인돼야 "완료".

## 빌드 · 테스트 · 배포 (요약, 상세는 HANDOFF §10)
- 환경: Godot 4.3-stable + 웹 내보내기 템플릿 (§10.1)
- 테스트 9종: flow, menu, weapons, campaign, qol, drop, selftest, skills, consistency (§10.2)
- 빌드: `godot --headless --export-release Web build/web/index.html`
- 배포: `rm -rf docs && cp -r build/web docs && touch docs/.nojekyll docs/.gdignore` → 커밋·푸시 → 라이브 `index.pck` md5가 로컬과 일치하는지 확인 (§10.3)
- 모바일 확인: `node tools/mobile_check.js` (§10.4)
- 플레이: https://junsa80.github.io/srpg-prototype/
