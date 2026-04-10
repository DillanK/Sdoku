# UI Analysis — 화면 기능 연결 (E0BE83F0)

> **분석 기준**: 첨부 디자인 리소스 없음 — 현재 코드베이스 역공학(reverse engineering) 기반 분석
> **분석 일자**: 2026-04-10

---

## 1. UI Lead — 시각적 디자인 / 레이아웃 분석

### 1-1. 현재 화면 계층 구조

```
SdokuApp
└── ContentView
    └── HomeView (NavigationStack)
        ├── Title: "Sdoku" (.largeTitle.bold, paddingTop: 40)
        ├── VStack(spacing: 16) — 난이도 목록
        │   └── DifficultyRowView × 4 (easy / normal / hard / extreme)
        │       ├── VStack(leading, spacing: 4)
        │       │   ├── Text(displayName) — .headline, .primary
        │       │   └── HStack(spacing: 12)
        │       │       ├── Label("N회 완료", "checkmark.circle") — .caption, .secondary
        │       │       └── Label("mm:ss" | "기록 없음", "clock") — .caption, .secondary/.tertiary
        │       ├── Spacer()
        │       └── Image("chevron.right") — .secondary
        │   [컨테이너] padding(16), background(secondarySystemBackground), cornerRadius: 12
        └── ✗ navigationDestination → [플레이스홀더 Text] ← 연결 누락

GameView (독립 뷰, HomeView와 미연결)
├── Text("스도쿠") — .largeTitle.bold, paddingTop
├── SudokuGridView(viewModel)
├── GameControlsView(viewModel)
└── NumberPadView(viewModel)
```

### 1-2. 컴포넌트 스펙 (코드 실측)

| 컴포넌트 | 속성 | 값 |
|---|---|---|
| DifficultyRowView | padding | 16pt (all sides) |
| DifficultyRowView | cornerRadius | 12pt |
| DifficultyRowView | background | `Color(.secondarySystemBackground)` |
| DifficultyRowView | chevron | `Image(systemName: "chevron.right")`, .secondary |
| Title "Sdoku" | font | `.largeTitle.bold()` |
| Title "Sdoku" | paddingTop | 40pt |
| 난이도 목록 VStack | spacing | 16pt |
| 난이도 목록 HStack (외부) | paddingHorizontal | 24pt |
| VStack(root) | spacing | 24pt |
| 통계 레이블 | font | `.caption` |
| 통계 레이블(완료) | foregroundStyle | `.secondary` |
| 통계 레이블(없음) | foregroundStyle | `.tertiary` |

### 1-3. 색상 팔레트 (시맨틱 기반)

| 용도 | 시맨틱 색상명 | 비고 |
|---|---|---|
| 행 배경 | `Color(.secondarySystemBackground)` | Light: #F2F2F7 / Dark: #1C1C1E |
| 주요 텍스트 | `.primary` | 시스템 자동 |
| 부가 텍스트 | `.secondary` | 시스템 자동 |
| 비활성 텍스트 | `.tertiary` | 시스템 자동 |
| 아이콘 | `.secondary` | chevron.right |

> HEX 실측 불가 — 디자인 시안 미첨부. 시스템 시맨틱 색상만 사용 중.

### 1-4. 타이포그래피

| 역할 | Font Token |
|---|---|
| 앱 타이틀 | `.largeTitle.bold()` (34pt Bold) |
| 게임 타이틀 | `.largeTitle.bold()` (재사용) |
| 난이도명 | `.headline` (17pt Semibold) |
| 통계 레이블 | `.caption` (12pt Regular) |

### 1-5. UI Lead → 다른 Lead 전달 사항

- **[Critical]** `HomeView.swift:42-46` — `navigationDestination` 클로저가 `Text` 플레이스홀더를 렌더링. `GameView`로 교체 필요.
- **[Critical]** `GameView` — `@State private var viewModel = GameViewModel()` 가 `.mock()` 보드를 사용. 난이도 파라미터 주입 필요.
- **[Info]** GameView는 `NavigationTitle` 미설정. 홈 화면 연결 시 `.navigationTitle(difficulty.displayName)` 추가 권장.
- **[Info]** GameView에 뒤로가기 처리(게임 완료/중단) 시 시각적 완료 피드백(Alert 또는 Sheet)이 없음 — UX Lead 검토 필요.

---

## 2. 코드 매핑 (REUSE / MODIFY / NEW)

### MODIFY

| 파일 | 위치 | 변경 내용 |
|---|---|---|
| `HomeView.swift` | L43-46 | `navigationDestination` 클로저를 `GameView(difficulty:)` 호출로 교체 |
| `GameView.swift` | L6, L8 | `difficulty: Difficulty` 파라미터 수신, ViewModel 생성 시 전달 |
| `GameViewModel.swift` | L22 | `init(difficulty:)` 추가 — `PuzzleGenerator`로 실제 퍼즐 생성 |

### REUSE (변경 없음)

| 파일 | 이유 |
|---|---|
| `PuzzleGenerator.swift` | `generate(difficulty:)` API 이미 완성 |
| `SudokuBoard.swift` | `mock()` 은 Preview 전용으로 유지 |
| `HomeViewModel.swift` | `recordGame(difficulty:elapsedSeconds:isCompleted:)` 이미 구현 |
| `GameRecordRepository.swift` | 변경 불필요 |
| `Difficulty.swift` | 변경 불필요 |
| 모든 Component 뷰 | `SudokuGridView`, `GameControlsView`, `NumberPadView` 변경 불필요 |

### NEW (추가 필요)

| 대상 | 내용 |
|---|---|
| `GameViewModel` — 승리 감지 | `SudokuPuzzle.solution`과 현재 보드 비교하여 `isCompleted: Bool` 노출 |
| `GameView` — 완료 콜백 | `isCompleted` 감지 시 기록 저장 트리거 (`HomeViewModel.recordGame`) |
| `GameView` — 타이머 | 경과 시간 추적 (저장용 `elapsedSeconds`) |

---

## 3. 핵심 연결 포인트 요약

```
HomeView.navigationDestination(difficulty)
    ↓
GameView(difficulty: difficulty)           ← MODIFY
    ↓
GameViewModel(difficulty: difficulty)      ← MODIFY
    ↓
PuzzleGenerator().generate(difficulty)    ← REUSE (이미 완성)
    ↓
SudokuBoard(cells: puzzle cells)
```

```
GameViewModel.isCompleted (NEW)
    ↓ onChange in GameView
HomeViewModel.recordGame(difficulty, elapsed, isCompleted: true)  ← REUSE
    ↓
GameRecordRepository.save(...)            ← REUSE
```
