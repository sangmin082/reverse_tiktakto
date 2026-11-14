# 리버스 틱택토 — iOS

먼저 줄을 만드는 쪽이 지는 틱택토. SwiftUI로 만든 네이티브 iOS 게임.

- Bundle ID: `com.reversetictactoe.game`
- 완전 오프라인 · 데이터 수집 없음 · 한국어/영어

## 게임 규칙

- 4×4 판, X가 선공, 한 칸씩 번갈아 둔다
- **자기 말 3개가 가로·세로·대각선으로 한 줄이 되면 패배**
- 판이 다 찰 때까지 아무도 줄을 만들지 않으면 무승부

## 앱 구성

```
ReverseTicTacToe/
  App/      ReverseTicTacToeApp.swift
  Engine/   Board.swift(비트마스크 국면·직선 테이블) Game.swift(진행·판정·무르기) Puzzles.swift(배우기 미션)
  AI/       Bot.swift (네가맥스+알파베타+치환표 반복 심화, 점대칭 전략 / 쉬움·보통·어려움)
  Views/    HomeView / GameScreen(GameModel) / BoardView / TutorialView / Theme / Haptics / Stats
Tests/TicTacCoreTests/   엔진·AI 단위 테스트 (Package.swift)
```

- **배우기**: 엔진이 끝까지 읽어서 정답을 판정하는 4개의 한 수 퍼즐
- **컴퓨터 대전**: 쉬움/보통/어려움, 판마다 선·후공 교대, 난이도별 전적
- **함께 하기**: 한 기기로 로컬 2인 대전
- **위험한 칸 표시**: 지금 두면 지는 칸에 빨간 점 (설정으로 끄기 가능)

### AI 메모

- 4×4는 서로 최선이면 **후공(O)이 이긴다** — 빈 판부터 끝까지 읽어 확인 (릴리스 빌드로 약 8초)
- 자기 줄을 완성하는 '독' 칸은 다른 수가 없을 때만 두므로 실제 분기 수가 작다
- 어려움은 후공일 때 확실한 승리를 못 찾으면 **점대칭 전략**을 쓴다: 상대 수를 판 중심에 대해
  뒤집어 따라 두면 먼저 줄을 완성할 수 없다

## 빌드

로컬(Mac): `ReverseTicTacToe.xcodeproj`를 Xcode 26+로 열고 실행.
엔진 테스트는 Mac 없이도 가능: `swift test` (리눅스 Swift 툴체인 OK).

CI (GitHub Actions):

- `.github/workflows/ios.yml` — push/PR 시 엔진 테스트 + 서명 없이 컴파일 검증
- `.github/workflows/ui-tests.yml` — 시뮬레이터에서 주요 흐름을 눌러 보고 스크린샷을 아티팩트로 남김
- `.github/workflows/testflight.yml` — Actions 탭 Run workflow 또는 `v*` 태그 푸시 시 TestFlight 업로드
  (reverse_omok과 같은 방식: `scripts/asc.py`가 번들 ID 등록·빌드 번호 결정, fastlane match 서명)

시크릿과 첫 배포 절차는 [docs/RELEASE.md](./docs/RELEASE.md) 참고.
