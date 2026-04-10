# Code Mapping — 화면 기능 연결 (E0BE83F0)

> **Role**: Coordinator
> **작성 기준**: ui-analysis.md + ux-analysis.md + feature-analysis.md + cross-review.md + 실제 소스코드 역공학
> **작성 일자**: 2026-04-10

---

## 1. MODIFY — 기존 코드 수정 필요

### `HomeView.swift` — L42-46 (navigationDestination)

**현재**:
```swift
// HomeView.swift:42-46
.navigationDestination(item: $viewModel.selectedDifficulty) { difficulty in
    Text("게임 화면: \(difficulty.displayName)")
        .navigationTitle(difficulty.displayName)
}
```

**변경 내용**:
- `Text` 플레이스홀더 → `GameView(difficulty:onGameCompleted:)` 호출로 교체
- `onGameCompleted` 클로저에서 `viewModel.recordGame(...)` 호출

**변경 후 (목표)**:
```swift
.navigationDestination(item: $viewModel.selectedDifficulty) { difficulty in
    GameView(difficulty: difficulty) { elapsed in
        viewModel.recordGame(
            difficulty: difficulty,
            elapsedSeconds: elapsed,
            isCompleted: true
        )
    }
}
```

**의존성**: `GameView(difficulty:onGameCompleted:)` 시그니처 확정 후 수정 가능

---

### `GameView.swift` — 전면 수정 (현재 L1-29)

**현재**:
```swift
// GameView.swift:4-29
struct GameView: View {
    @State private var viewModel = GameViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("스도쿠").font(.largeTitle.bold()).padding(.top)
            SudokuGridView(viewModel: viewModel).padding(.horizontal)
            GameControlsView(viewModel: viewModel)
            NumberPadView(viewModel: viewModel).padding(.bottom)
        }
    }
}
```

**변경 범위**: 파라미터 추가, 타이머/로딩/Alert State 추가, body 재구성

**추가할 요소**:

| 항목 | 타입 | 역할 |
|------|------|------|
| `difficulty: Difficulty` | 파라미터 | 난이도 전달 |
| `onGameCompleted: (Int64) -> Void` | 파라미터(클로저) | 기록 저장 콜백 |
| `@State var viewModel: GameViewModel?` | State | 비동기 생성 완료 후 바인딩 |
| `@State var isLoading = true` | State | 퍼즐 생성 중 ProgressView 제어 |
| `@State var elapsedSeconds = 0` | State | 타이머 카운터 |
| `@State var showCompletionAlert = false` | State | 완료 Alert 트리거 |
| `@State var showExitAlert = false` | State | 중단 확인 Alert 트리거 |
| `.navigationTitle(difficulty.displayName)` | modifier | 타이틀 일관성 (cross-review 충돌 G 결정) |
| `.navigationBarBackButtonHidden(true)` | modifier | 커스텀 back 버튼 (충돌 C) |
| `.task { }` | modifier | 비동기 퍼즐 생성 (충돌 A) |
| `Timer.publish` onReceive | modifier | 타이머 1초 tick |
| `.onChange(of: viewModel.isCompleted)` | modifier | 완료 감지 → Alert |
| 완료 Alert | `.alert` | "퍼즐 완료!" → "홈으로" (충돌 B) |
| 중단 Alert | `.alert` | "게임을 종료하시겠습니까?" (충돌 C) |

**Preview 역호환**:
```swift
#Preview {
    GameView(difficulty: .easy) { _ in }
}
```

---

### `GameViewModel.swift` — init 추가 + isCompleted + checkCompletion

**현재**:
```swift
// GameViewModel.swift:22-24
init(board: SudokuBoard = .mock()) {
    self.state = GameState(board: board)
}
```

**추가할 요소**:

| 항목 | 위치 | 내용 |
|------|------|------|
| `private var puzzle: SudokuPuzzle` | 저장 프로퍼티 | solution 보관용 |
| `var isCompleted: Bool = false` | `@Observable` 프로퍼티 | 완료 상태 (단방향) |
| `init(difficulty: Difficulty)` | 새 이니셜라이저 | `PuzzleGenerator().generate(difficulty:)` 연결 |
| `checkCompletion()` | private 메서드 | solution 비교 방식 완료 검증 |
| `inputNumber()` 끝부분 | 기존 메서드 수정 | `checkCompletion()` 호출 추가 |

**`init(difficulty:)` 구현 방향**:
```swift
init(difficulty: Difficulty) {
    let generated = PuzzleGenerator().generate(difficulty: difficulty)
    self.puzzle = generated
    // SudokuPuzzle.puzzle → SudokuBoard 변환: isFixed = puzzle[r][c] != 0
    let board = SudokuBoard(cells: (0..<9).map { r in
        (0..<9).map { c in
            let v = generated.puzzle[r][c]
            return SudokuCell(value: v, isFixed: v != 0)
        }
    })
    self.state = GameState(board: board)
}
```

**기존 `init(board:)` 처리**: Preview 전용으로 유지 (`#if DEBUG` 또는 주석 표시 권고)

**`checkCompletion()` 구현 방향**:
```swift
private func checkCompletion() {
    // 방식 B: solution 비교 (cross-review 합의)
    let cells = state.board.cells
    for r in 0..<9 {
        for c in 0..<9 {
            if cells[r][c].value != puzzle.solution[r][c] { return }
        }
    }
    isCompleted = true
}
```

**`inputNumber()` 수정 지점**:
```swift
// 기존 마지막 줄 (L74): state.board = state.board.detectingConflicts()
// 추가: checkCompletion()
state.board = state.board.detectingConflicts()
checkCompletion()  // ← 추가
```

**Undo 후 isCompleted 재검증** (cross-review 반영):
```swift
func undo() {
    state.undo()
    if isCompleted {
        // undo 후 완료 상태 재검증
        isCompleted = false
        checkCompletion()
    }
}
```

---

### `HomeView.swift` — DifficultyRowView accessibilityLabel 추가

**현재**: `Button(action: onTap)` 내부에 명시적 accessibility 없음

**추가 위치**: `DifficultyRowView.body` 의 최외곽 `Button` 또는 내부 HStack에 `.accessibilityLabel` 추가

**구현 방향**:
```swift
.accessibilityLabel(
    "\(difficulty.displayName), \(stats?.completedCount ?? 0)회 완료, \(accessibilityBestTimeLabel)"
)
```

> 보조 계산 프로퍼티 `accessibilityBestTimeLabel`로 "최고기록 mm:ss" 또는 "기록 없음" 반환

---

## 2. NEW — 신규 구현 필요

### `GameViewModel.isCompleted: Bool`

- **파일**: `GameViewModel.swift`
- **패턴**: `@Observable` 저장 프로퍼티 (`var isCompleted: Bool = false`)
- **특성**: 완료 시 `true`로 전환되는 단방향. `undo()` 호출 시만 재검증 가능.
- **노출**: `public var` — `GameView`에서 `.onChange(of:)` 구독

---

### `GameViewModel.checkCompletion()`

- **파일**: `GameViewModel.swift`
- **패턴**: private 헬퍼 메서드
- **호출 시점**: `inputNumber()` 내부 `detectingConflicts()` 직후
- **방식**: solution 비교 (cross-review 합의 — 방식 B)
- **의존성**: `private var puzzle: SudokuPuzzle` 저장 필요

---

### `GameView` — 타이머

- **파일**: `GameView.swift`
- **패턴**: `@State var elapsedSeconds: Int = 0` + `onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect())`
- **정지 조건**: `viewModel.isCompleted == true` 시 타이머 카운트 중단
- **백그라운드 처리**: `@Environment(\.scenePhase)` 또는 별도 처리 (이번 구현 범위 내 선택)

---

### `GameView` — 로딩 상태 (ProgressView)

- **파일**: `GameView.swift`
- **패턴**: `@State var isLoading: Bool = true`
- **구현**: `.task { }` modifier 내에서 비동기 생성 후 `isLoading = false`
- **UI**: `isLoading ? ProgressView("퍼즐 생성 중...") : 게임 콘텐츠`

---

### `GameView` — 완료 Alert

- **파일**: `GameView.swift`
- **패턴**: `@State var showCompletionAlert: Bool = false` + `.alert("퍼즐 완료!", isPresented: $showCompletionAlert)`
- **트리거**: `.onChange(of: viewModel.isCompleted) { if newValue { showCompletionAlert = true } }`
- **버튼**: "홈으로" 단일 버튼 → `dismiss()` 호출
- **메시지**: 소요 시간 표시 (`formattedTime(elapsedSeconds)`)

---

### `GameView` — 중단 Alert (back 버튼 커스텀)

- **파일**: `GameView.swift`
- **패턴**: `.navigationBarBackButtonHidden(true)` + `.toolbar { ToolbarItem(placement: .navigationBarLeading) { ... } }`
- **Alert**: `@State var showExitAlert: Bool = false`
- **버튼 구성**: "종료" (`.destructive`, `dismiss()`) + "계속하기" (`.cancel`)
- **중단 시 기록 저장**: 저장 안 함 (cross-review 충돌 D 결정)

---

## 3. REUSE — 변경 없음

| 파일 | 경로 | 재사용 근거 |
|------|------|-----------|
| `PuzzleGenerator` | `Services/PuzzleGenerator.swift` | `generate(difficulty:) -> SudokuPuzzle` API 완성. 변경 불필요 |
| `SudokuBoard` | `Models/SudokuBoard.swift` | `detectingConflicts()`, `mock()` 완성. `mock()`은 Preview 전용 유지 |
| `SudokuCell` | `Models/SudokuCell.swift` | 구조 변경 없음 |
| `GameState` | `Models/GameState.swift` | solution은 `GameViewModel` 레벨에서 보관. `GameState` 무변경 |
| `HomeViewModel` | `HomeViewModel.swift` | `recordGame(difficulty:elapsedSeconds:isCompleted:)` 완성 |
| `GameRecordRepository` | `GameRecordRepository.swift` | 변경 없음 |
| `Difficulty` | `Difficulty.swift` | 변경 없음 |
| `SudokuGridView` | `Views/Components/SudokuGridView.swift` | 변경 없음 |
| `GameControlsView` | `Views/Components/GameControlsView.swift` | 변경 없음 |
| `NumberPadView` | `Views/Components/NumberPadView.swift` | 변경 없음 |
| `SudokuCellView` | `Views/Components/SudokuCellView.swift` | 변경 없음 |
| `ContentView` | `ContentView.swift` | 변경 없음 |
| `SdokuApp` | `SdokuApp.swift` | 변경 없음 |
| `GridGenerator` | `Services/GridGenerator.swift` | 변경 없음 |
| `UniqueSolutionValidator` | `Services/UniqueSolutionValidator.swift` | 변경 없음 |
| `Persistence` | `Persistence.swift` | 변경 없음 |

---

## 4. 구현 순서 및 의존성 그래프

```
Step 1: GameViewModel — init(difficulty:) + puzzle 저장
        ↓ 의존: PuzzleGenerator (REUSE, 이미 완성)

Step 2: GameViewModel — isCompleted + checkCompletion()
        ↓ 의존: Step 1 완료 (puzzle.solution 접근)

Step 3: GameView — 파라미터 추가 (difficulty, onGameCompleted)
        ↓ 의존: Step 1 완료 (GameViewModel(difficulty:) 사용)

Step 4: GameView — 비동기 로딩 + ProgressView
        ↓ 의존: Step 3 완료

Step 5: GameView — 타이머 + 완료 Alert + 기록 저장 콜백
        ↓ 의존: Step 2 완료 (isCompleted), Step 3 완료 (onGameCompleted)

Step 6: HomeView — navigationDestination → GameView 교체
        ↓ 의존: Step 3~5 완료 (GameView 시그니처 확정)

Step 7: GameView — 중단 Alert (back 버튼 커스텀)
        의존성 없음 (Step 6과 병렬 가능)

Step 8: HomeView — DifficultyRowView accessibilityLabel 추가
        의존성 없음 (단독 적용 가능)
```

**병렬 처리 가능 구간**:
- Step 7 + Step 8 → 상호 독립, 동시 작업 가능

---

## 5. 검증 포인트

| 항목 | 검증 방법 |
|------|---------|
| `GameViewModel(difficulty:)` init | Unit test: `PuzzleGenerator` 실제 호출, `SudokuBoard.cells` 확인 |
| `checkCompletion()` | Unit test: 완성 보드 세팅 후 `isCompleted == true` 확인 |
| 비동기 퍼즐 생성 (extreme) | UI test 또는 수동: extreme 선택 시 ProgressView 표시 확인 |
| 완료 Alert | UI test 또는 수동: 퍼즐 완료 후 Alert 표시 + "홈으로" tap → HomeView 복귀 |
| 중단 Alert | 수동: 게임 진행 중 back 버튼 탭 → Alert 표시 확인 |
| HomeView 통계 갱신 | 수동: 완료 후 홈 복귀 시 해당 난이도 completedCount +1, bestTime 갱신 확인 |
| `isCompleted` Undo 재검증 | Unit test: 완료 직후 `undo()` 호출 → `isCompleted == false` 확인 |

---

## 6. 이번 범위 제외 항목 (별도 Feature)

| 항목 | 이유 |
|------|------|
| VoiceOver 그리드 커스텀 컴포넌트 | 구현 공수 高, 핵심 연결 목적과 분리 |
| 충돌 셀 비색상 단서 | 기존 게임 플레이 화면 수정 — 범위 초과 |
| 셀 탭 44pt 미달 | 9×9 그리드 구조 변경 필요 |
| NumberPad Dynamic Type | 레이아웃 검증 필요 |
| Empty State 동기부여 디자인 | 디자인 작업 필요 |
| Resume(이어하기) 기능 | CoreData GameState 저장 — 대규모 |
