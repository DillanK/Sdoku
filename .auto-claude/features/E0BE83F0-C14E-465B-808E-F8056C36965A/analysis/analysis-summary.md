# Analysis Summary — 화면 기능 연결 (E0BE83F0)

> **통합 작성**: Coordinator
> **참조**: ui-analysis.md / ux-analysis.md / feature-analysis.md / cross-review.md / code-mapping.md
> **작성 일자**: 2026-04-10

---

## 1. 핵심 구현 포인트 (우선순위 순)

### P1 — HomeView → GameView 네비게이션 연결 [Critical]

`HomeView.swift:42-46`의 `navigationDestination` 클로저가 `Text` 플레이스홀더를 반환 중.
`GameView(difficulty:onGameCompleted:)` 호출로 교체해야 실제 게임 진입이 가능해진다.

```
HomeView.navigationDestination(difficulty)
    → GameView(difficulty: difficulty, onGameCompleted: { elapsed in
          viewModel.recordGame(difficulty:elapsedSeconds:isCompleted:true)
      })
```

### P2 — GameViewModel `init(difficulty:)` + PuzzleGenerator 연결 [Critical]

현재 `GameViewModel.init(board: SudokuBoard = .mock())`만 존재.
`init(difficulty: Difficulty)`를 추가하고 내부에서 `PuzzleGenerator().generate(difficulty:)`를 호출해 실제 퍼즐을 생성해야 한다.
`SudokuPuzzle` 전체를 `private var puzzle`로 보관하여 solution 비교에 사용.

### P3 — `isCompleted` + `checkCompletion()` [High]

`GameViewModel`에 `var isCompleted: Bool = false` 추가.
`inputNumber()` 내 `detectingConflicts()` 직후 `checkCompletion()` 호출.
완료 조건: `board.cells[r][c].value == puzzle.solution[r][c]` (전체 일치 — 방식 B).
`undo()` 호출 시 `isCompleted = false` 후 재검증.

### P4 — GameView: 타이머 + 완료 Alert + 기록 저장 콜백 [High]

- `@State var elapsedSeconds: Int = 0` + `Timer.publish(every: 1)` onReceive
- `.onChange(of: viewModel.isCompleted)` → `showCompletionAlert = true` + `onGameCompleted(Int64(elapsedSeconds))` 호출
- Alert: "퍼즐 완료!" / "홈으로" 단일 버튼 → `dismiss()`

### P5 — 비동기 퍼즐 생성 + ProgressView [Medium]

`PuzzleGenerator.generate()`는 `while true` 동기 실행 — 극악 난이도에서 Main Thread 블로킹 위험.
`.task { }` modifier에서 비동기 실행, `@State var isLoading = true`로 `ProgressView("퍼즐 생성 중...")` 표시.

### P6 — 게임 중단 Alert (back 버튼 커스텀) [Medium]

`.navigationBarBackButtonHidden(true)` + 커스텀 `ToolbarItem`.
"게임을 종료하시겠습니까?" Alert → "종료"(dismiss) / "계속하기"(cancel).
중단 시 기록 저장 안 함.

### P7 — DifficultyRowView `accessibilityLabel` [Low]

`"\(difficulty.displayName), \(stats.completedCount)회 완료, \(bestTimeLabel)"` 형태로 추가.
그리드 VoiceOver 커스텀 컴포넌트는 이번 범위 제외.

---

## 2. 재활용 vs 신규 비율

| 분류 | 파일 수 | 비율 |
|------|---------|------|
| **REUSE** (변경 없음) | 14개 | ~74% |
| **MODIFY** (부분 수정) | 3개 | ~16% |
| **NEW** (신규 추가) | 5개 항목 | ~10% (기존 파일 내 추가) |

**REUSE 주요 파일**: `PuzzleGenerator`, `SudokuBoard`, `HomeViewModel`, `GameRecordRepository`, `SudokuGridView`, `GameControlsView`, `NumberPadView`, `ContentView`, `SdokuApp` 등

**MODIFY 대상**:
- `HomeView.swift` — navigationDestination 교체 + accessibilityLabel
- `GameView.swift` — 파라미터 추가, 타이머/Alert/로딩 State 추가
- `GameViewModel.swift` — init(difficulty:) 추가, isCompleted/checkCompletion 추가

**핵심 관찰**: 퍼즐 생성/검증 엔진, 게임 플레이 UI, 기록 저장 레이어 모두 완성 상태. 이번 기능은 기존 완성된 컴포넌트를 연결하는 "글루 코드(glue code)" 성격이 강하다.

---

## 3. 구현 복잡도 평가

| 항목 | 복잡도 | 근거 |
|------|--------|------|
| HomeView navigationDestination 교체 | **Low** | 2~5줄 수정 |
| GameViewModel init(difficulty:) | **Low** | PuzzleGenerator API 이미 완성 |
| isCompleted + checkCompletion | **Low** | 이중 루프 비교, 명확한 로직 |
| 타이머 구현 | **Low** | SwiftUI 표준 패턴 |
| 완료 Alert | **Low** | SwiftUI `.alert` 표준 패턴 |
| 비동기 퍼즐 생성 | **Medium** | `.task {}` 패턴 + GameViewModel Optional 처리 필요 |
| 중단 Alert + 커스텀 back 버튼 | **Medium** | navigationBarBackButtonHidden + Toolbar 조합 |
| accessibilityLabel | **Low** | modifier 1줄 추가 |

**전체 복잡도**: **Low~Medium**. 신규 알고리즘 없음. 기존 인프라 조합 + 상태 연결이 전부.

---

## 4. 권장 구현 순서

```
Step 1: GameViewModel — init(difficulty:) + private var puzzle: SudokuPuzzle
        (의존: PuzzleGenerator — REUSE)

Step 2: GameViewModel — var isCompleted: Bool + checkCompletion() + undo() 재검증
        (의존: Step 1)

Step 3: GameView — difficulty/onGameCompleted 파라미터 추가 + GameViewModel(difficulty:) 연결
        (의존: Step 1)

Step 4: GameView — 비동기 로딩 (.task + ProgressView)
        (의존: Step 3)

Step 5: GameView — 타이머 + 완료 Alert + onGameCompleted 호출
        (의존: Step 2, Step 3)

Step 6: HomeView — navigationDestination → GameView(difficulty:onGameCompleted:)
        (의존: Step 3~5 완료 — GameView 시그니처 확정 후)

Step 7 & 8 (병렬): GameView 중단 Alert + HomeView accessibilityLabel
        (각자 독립, Step 6과 병렬 가능)
```

---

## 5. 미해결 우려사항 (각 Lead가 양보한 사항)

### 5-1. 비동기 퍼즐 생성에서 `GameViewModel` Optional 처리

**배경**: 비동기 생성을 위해 `@State var viewModel: GameViewModel?` 패턴 채택 시, body 내부 `viewModel` Optional 언래핑이 불편해진다. `.task {}` 내에서 생성 완료 후 assign하는 패턴이지만 초기 상태(nil)에서 타이머/onChange가 동작하지 않도록 처리 필요.

**Feature Lead가 양보한 사항**: `GameViewModel`을 non-optional로 유지하되 초기화를 지연시키는 대안(예: `@State var viewModel = GameViewModel.loading()`)도 검토 가능했으나, 단순성 우선으로 Optional 패턴 채택.

**구현 시 보완**: `viewModel`이 nil일 때 타이머 tick/onChange 무시되도록 guard 처리 필수.

---

### 5-2. VoiceOver 그리드 커스텀 컴포넌트 제외

**배경**: 81개 셀 개별 VoiceOver 탐색은 사용성 극히 저하. UX Lead가 커스텀 accessibility container 구현을 권고했으나, 구현 공수와 핵심 목적(화면 연결) 집중을 이유로 이번 범위 제외.

**양보한 주체**: UX Lead
**리스크**: 보조기술 사용자의 게임 플레이 불가 상태 지속.
**구현 시 보완**: 별도 접근성 Feature로 분리 후 우선순위 상향 검토 필요.

---

### 5-3. 충돌 셀 비색상 단서 미적용

**배경**: 현재 충돌 표시가 `.red` 배경 + `.red` 텍스트만 사용. 색약 사용자에게 인식 불가.
UX Lead가 테두리/아이콘/패턴 등 비색상 단서를 권고했으나, 기존 게임 플레이 화면 수정 범위 초과로 제외.

**양보한 주체**: UX Lead
**리스크**: 색각 이상 사용자 접근성 미충족.
**구현 시 보완**: 충돌 셀 border 강화 또는 SF Symbol 오버레이 추가.

---

### 5-4. 타이머 백그라운드 처리 범위

**배경**: `scenePhase` 감지로 백그라운드 전환 시 타이머 일시 정지 구현을 Feature Lead가 권고했으나, "이번 구현 범위 내 선택 사항"으로 유보.

**양보한 주체**: Feature Lead (엣지 케이스로 분류)
**리스크**: 백그라운드 전환 시 타이머 계속 증가 → 기록 시간 부정확.
**구현 시 보완**: `@Environment(\.scenePhase)` onChange에서 타이머 일시정지/재개 로직 추가.

---

### 5-5. Undo 스택 메모리 제한 미설정

**배경**: 현재 `undoStack`에 크기 제한 없음. 각 `UndoEntry`가 `SudokuBoard` 전체 스냅샷(81개 셀). 반복 입력/삭제 시 메모리 무제한 증가.

**양보한 주체**: Feature Lead (🟡 Medium 위험도로 분류, 이번 범위 제외)
**리스크**: 장시간 플레이 시 메모리 증가.
**구현 시 보완**: `undoStack`에 `maxCount = 50` 제한 추가.

---

## 6. 주요 기술 결정 요약

| 결정 사항 | 채택 방식 | 대안 포기 이유 |
|---------|---------|-------------|
| 완료 검증 | Solution 비교 (방식 B) | 충돌 기반(방식 A)은 이론적 허점 존재 |
| 타이머 위치 | GameView @State | GameViewModel 내 Timer는 테스트 어려움 |
| 기록 저장 경로 | Closure Callback | HomeViewModel 직접 주입은 과도한 결합 |
| 완료 피드백 | Alert ("홈으로") | 자동 dismiss는 완료 인지 실패 위험 |
| 중단 처리 | Alert 포함 | 진행 손실은 극악 난이도에서 좌절감 직결 |
| 중단 기록 저장 | 저장 안 함 | DB 누적 방지, 통계 영향 없음 |
| VoiceOver | HomeView 버튼만 적용 | 그리드 커스텀은 별도 Feature로 분리 |
