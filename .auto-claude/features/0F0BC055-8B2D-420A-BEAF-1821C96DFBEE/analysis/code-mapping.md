# Code Mapping — 기능 연동 (0F0BC055)

> **역할**: Coordinator
> **기반**: UI/UX/Feature 분석 + 소스 코드 역방향 탐색
> **분류 기준**: REUSE / MODIFY / NEW
> **구현 순서**: 의존성 그래프 기반 (번호 = 구현 순서)

---

## 1. REUSE — 변경 없이 재활용

| # | 파일 | 경로 | 재활용 이유 |
|---|------|------|------------|
| — | `SudokuPuzzle` | `Models/SudokuPuzzle.swift` | 데이터 구조 완결. 호출 측에서만 소비 |
| — | `HomeViewModel` | `HomeViewModel.swift` | `recordGame(difficulty:elapsedSeconds:isCompleted:)` 시그니처 변경 없음. 연동 측에서 클로저로 래핑 |
| — | `Difficulty` | `Difficulty.swift` | rawValue 변경 금지. 현행 유지 |
| — | `GridGenerator` | `Services/GridGenerator.swift` | 내부 로직 완결. PuzzleGenerator가 호출 |
| — | `UniqueSolutionValidator` | `Services/UniqueSolutionValidator.swift` | 내부 로직 완결. PuzzleGenerator가 호출 |
| — | `SudokuGridView` | `Views/Components/SudokuGridView.swift` | UI 변경 없음 |
| — | `SudokuCellView` | `Views/Components/SudokuCellView.swift` | Tier 2 접근성은 후속 작업. 이번 범위 외 |
| — | `GameState` | `Models/GameState.swift` | `pushUndo()`, `undo()`, `canUndo` 변경 없음 |
| — | `SudokuCell` | `Models/SudokuCell.swift` | 필드 변경 없음 |
| — | `ContentView` | `ContentView.swift` | `HomeView` 주입 구조 변경 없음 |
| — | `SdokuApp` | `SdokuApp.swift` | 진입점 변경 없음 |
| — | `PersistenceController` | `Persistence.swift` | CoreData 설정 변경 없음 |

---

## 2. MODIFY — 기존 코드 수정 필요

### 구현 순서: 의존성 없는 것 먼저

---

### [Step 1] `SudokuBoard` — `isSolved` 추가
**경로**: `Sdoku/Sdoku/Models/SudokuBoard.swift`
**변경 범위**: computed property 1개 추가
**의존성**: 없음 (최우선 구현)

```
추가 위치: detectingConflicts() 이후
```

| 변경 내용 | 상세 |
|----------|------|
| `var isSolved: Bool` 추가 | `모든 cell.value != 0 AND 모든 cell.isConflict == false` |

**구현 근거** (feature-analysis.md §2-2):
- `detectingConflicts()`는 value == 0 셀에 대해 false 반환
- → `value != 0` 선행 조건 필수
- 유일해 보장(PuzzleGenerator)으로 solution 비교 불필요

---

### [Step 2] `GameRecordRepository` — bestTime 쿼리 수정
**경로**: `Sdoku/Sdoku/GameRecordRepository.swift`
**변경 범위**: `fetchStats(for:)` 내부 bestTime NSPredicate 조건 1개 추가
**의존성**: 없음

| 변경 내용 | 상세 |
|----------|------|
| `fetchStats(for:)`의 bestTime 쿼리 | `isCompleted == YES AND elapsedSeconds > 0` 조건으로 수정 |

**구현 근거** (cross-review.md C4):
- Phase 1에서 완료 기록을 `elapsedSeconds: 0`으로 저장
- bestTime 쿼리에서 0 필터링 → "기록 없음" 표시 정상화
- completedCount는 기존 쿼리 유지 (0도 카운팅)

---

### [Step 3] `PuzzleGenerator` — 최대 재시도 횟수 제한
**경로**: `Sdoku/Sdoku/Services/PuzzleGenerator.swift`
**변경 범위**: `generate(difficulty:)` 내부 `while true` 루프에 카운터 추가
**의존성**: 없음

| 변경 내용 | 상세 |
|----------|------|
| `while true` → `while attempts < 100` | attempts 카운터 추가 |
| 초과 시 hard 난이도로 fallback | `generate(difficulty: .hard)` 재귀 또는 hard 고정 반환 |

**구현 근거** (cross-review.md §2 + feature-analysis.md §5-1):
- extreme 난이도 무한루프 위험도: **높음**
- 100회 제한 + hard fallback으로 UI 블로킹 방지

---

### [Step 4] `GameViewModel` — difficulty 연동 + 완료 감지 + 비동기 처리
**경로**: `Sdoku/Sdoku/ViewModels/GameViewModel.swift`
**변경 범위**: init 오버로드 + 프로퍼티 3개 추가 + 비동기 생성 메서드 추가
**의존성**: Step 1 (SudokuBoard.isSolved)

| 변경 내용 | 상세 |
|----------|------|
| `init(difficulty: Difficulty)` 추가 | 기존 `init(board: .mock())` 유지 (프리뷰용) |
| `var isLoading: Bool = true` 추가 | 퍼즐 생성 중 로딩 상태 |
| `var isCompleted: Bool` computed property | `state.board.isSolved` 위임 |
| `private var puzzleTask: Task<Void, Never>?` | Task 취소를 위한 참조 보관 |
| `func loadPuzzle(difficulty: Difficulty) async` | `Task.detached` + `@MainActor` UI 업데이트 |
| `func cancelLoading()` | `puzzleTask?.cancel()` |
| SudokuPuzzle → SudokuBoard 변환 로직 | `puzzle[r][c] == 0 → SudokuCell(value:0, isFixed:false)` |
| COMPLETED 상태에서 입력 차단 | `inputNumber`, `clearCell`에 `guard !isCompleted` 추가 |

**SudokuPuzzle → SudokuBoard 변환** (feature-analysis.md §1-3):
```
puzzle[row][col] == 0  → SudokuCell(value: 0, isFixed: false)
puzzle[row][col] != 0  → SudokuCell(value: v, isFixed: true)
```

**비동기 처리 패턴** (cross-review.md §2):
- `Task { }` 내부에서 PuzzleGenerator.generate() 호출
- `await MainActor.run { }` 로 board 업데이트
- GameView `.task {}` modifier 사용 시 뷰 소멸 시 자동 취소

---

### [Step 5] `GameControlsView` — 탭 영역 44pt 보장
**경로**: `Sdoku/Sdoku/Views/Components/GameControlsView.swift`
**변경 범위**: 버튼 modifier 2개 추가 (메모, 되돌리기 각각)
**의존성**: 없음 (독립 수정)

| 변경 내용 | 상세 |
|----------|------|
| 각 버튼에 `.frame(minHeight: 44)` 추가 | HIG 44pt 최소 탭 영역 |
| 각 버튼에 `.contentShape(Rectangle())` 추가 | hit testing 영역 확장 |

**구현 근거** (cross-review.md C5):
- 현재 38pt → 44pt 미달
- 시각적 크기 변경 없이 탭 영역만 확장

---

### [Step 6] `DifficultyRowView` — Tier 1 접근성
**경로**: `Sdoku/Sdoku/HomeView.swift` (line 55~111, private struct)
**변경 범위**: Button modifier에 accessibilityLabel 추가
**의존성**: 없음 (독립 수정)

| 변경 내용 | 상세 |
|----------|------|
| `.accessibilityLabel(...)` | `"\(difficulty.displayName), \(stats?.completedCount ?? 0)회 완료, \(bestTimeText)"` |
| `.accessibilityAddTraits(.isButton)` | 버튼 트레잇 명시 |

**구현 근거** (cross-review.md C7 Tier 1):
- 현재 SF Symbol 이름이 그대로 VoiceOver에 노출됨
- 앱 첫 진입점이므로 우선순위 높음

---

### [Step 7] `NumberPadView` — 접근성 + 미선택 햅틱
**경로**: `Sdoku/Sdoku/Views/Components/NumberPadView.swift`
**변경 범위**: 지우기 버튼 accessibilityLabel + 숫자 버튼 탭 시 햅틱 조건 추가
**의존성**: Step 4 (GameViewModel.selectedRow 상태 접근)

| 변경 내용 | 상세 |
|----------|------|
| 지우기 버튼 `.accessibilityLabel("지우기")` | SF Symbol "delete.left" 이름 노출 방지 |
| 숫자 버튼 탭 핸들러에 햅틱 추가 | `selectedRow == nil`일 때 `UISelectionFeedbackGenerator().selectionChanged()` |

**구현 근거** (cross-review.md C1, C7 Tier 1):
- 미선택 시 패드 비활성화 금지 (고정 셀과 시각 구분 불가)
- 경미한 햅틱만으로 피드백 제공

---

### [Step 8] `HomeView` — navigationDestination 연결
**경로**: `Sdoku/Sdoku/HomeView.swift`
**변경 범위**: `navigationDestination(item:)` 클로저 내부 교체
**의존성**: Step 4 (GameViewModel), Step 9 (GameView 수정 완료 후)

| 변경 내용 | 상세 |
|----------|------|
| `Text placeholder` → `GameView(difficulty:onGameEnd:)` | difficulty 주입 |
| `onGameEnd` 클로저 구성 | `viewModel.recordGame(difficulty:elapsedSeconds:isCompleted:)` 호출 + `viewModel.selectedDifficulty = nil` (pop) |

**클로저 시그니처**:
```
onGameEnd: { difficulty, elapsed, isCompleted in
    viewModel.recordGame(difficulty: difficulty, elapsedSeconds: elapsed, isCompleted: isCompleted)
    viewModel.selectedDifficulty = nil
}
```

---

### [Step 9] `GameView` — difficulty 수신 + 완료 감지 + 뒤로가기 가드
**경로**: `Sdoku/Sdoku/Views/GameView.swift`
**변경 범위**: 파라미터 추가 + modifier 추가 + 커스텀 back 버튼 구현
**의존성**: Step 4 (GameViewModel 변경), Step 10/11 (NEW 뷰 완료 후 통합)

| 변경 내용 | 상세 |
|----------|------|
| `let difficulty: Difficulty` 파라미터 추가 | HomeView에서 주입 |
| `let onGameEnd: (Difficulty, Int64, Bool) -> Void` 파라미터 추가 | 클로저 주입 (feature-analysis.md §3-4 추천 방식) |
| `@State private var viewModel` | `GameViewModel(difficulty: difficulty)` 로 초기화 변경 |
| `.task { await viewModel.loadPuzzle(difficulty: difficulty) }` | 뷰 생성 시 비동기 퍼즐 생성. 뷰 소멸 시 자동 취소 |
| `.onChange(of: viewModel.isCompleted)` | true 전환 시 `onGameEnd(difficulty, 0, true)` 호출 |
| `.navigationBarBackButtonHidden(true)` | 시스템 뒤로가기 버튼 숨김 |
| 커스텀 back 버튼 (toolbar) | 미완성 게임 Alert 트리거. `viewModel.isLoading`인 경우 Alert 없이 바로 pop |
| `@State private var showAbandonAlert: Bool` | Alert 표시 상태 |
| `@State private var showCompletionOverlay: Bool` | 완료 overlay 표시 상태 (isCompleted onChange에서 true 설정) |
| 완료 시 전체 입력 차단 | `isCompleted == true` 시 overlay가 덮음 (GameViewModel 내부에서도 guard 처리) |

**뒤로가기 Alert 내용** (ux-analysis.md 시나리오 C):
```
제목: "게임을 종료하시겠어요?"
메시지: "진행 상황은 저장되지 않습니다."
버튼: "종료" (isCompleted: false 기록 저장 후 pop), "계속"
```

---

## 3. NEW — 신규 구현 필요

---

### [Step 10] `GameCompletionView` — 완료 overlay
**경로**: `Sdoku/Sdoku/Views/Components/GameCompletionView.swift` (신규)
**의존성**: Step 4 (GameViewModel.isCompleted)
**패턴**: SwiftUI overlay or fullscreenCover (미결 항목 C7 — 구현 시 결정)

| 구성 요소 | 상세 |
|----------|------|
| 배경 dimming | `Color.black.opacity(0.4)` overlay |
| 완료 메시지 | "퍼즐 완료!" 또는 난이도명 포함 |
| "다시 하기" 버튼 | `onGameEnd(difficulty, 0, true)` 호출 후 새 GameView push 또는 현재 뷰 리셋 |
| "홈으로" 버튼 | dismiss (NavigationStack pop) |

**추천 패턴**: `.overlay` modifier (GameView 내부에서 `showCompletionOverlay` 상태로 제어)
- fullscreenCover는 별도 NavigationStack 생성 위험

---

### [Step 11] `PuzzleLoadingView` — 로딩 overlay
**경로**: `Sdoku/Sdoku/Views/Components/PuzzleLoadingView.swift` (신규)
**의존성**: Step 4 (GameViewModel.isLoading)
**패턴**: SwiftUI overlay

| 구성 요소 | 상세 |
|----------|------|
| 배경 | `Color(.systemBackground).opacity(0.9)` |
| 로딩 인디케이터 | `ProgressView()` + 텍스트 "퍼즐 생성 중..." |
| 표시 조건 | `viewModel.isLoading == true` |

**추천 패턴**: GameView body에서 `.overlay { if viewModel.isLoading { PuzzleLoadingView() } }`

---

## 4. 구현 순서 의존성 그래프

```
Step 1: SudokuBoard.isSolved ──────────────────────────────────┐
Step 2: GameRecordRepository.bestTime 수정 ────────────────────┤
Step 3: PuzzleGenerator 재시도 제한 ──────────────────────────┤
                                                               │
Step 4: GameViewModel(difficulty:, isCompleted, isLoading) ←──┘
        │
        ├── Step 5: GameControlsView 44pt (독립, 병렬 가능)
        ├── Step 6: DifficultyRowView 접근성 (독립, 병렬 가능)
        ├── Step 7: NumberPadView 접근성+햅틱
        ├── Step 10: GameCompletionView (NEW)
        └── Step 11: PuzzleLoadingView (NEW)
                │
                └── Step 9: GameView (모든 MODIFY)
                              │
                              └── Step 8: HomeView navigationDestination 연결
```

**병렬 가능 그룹**:
- Group A (독립): Step 1, 2, 3, 5, 6
- Group B (Step 4 완료 후): Step 7, 10, 11
- Group C (Group B 완료 후): Step 9
- Group D (Step 9 완료 후): Step 8

---

## 5. 미결 항목 (구현 시 결정)

| 항목 | 기본 결정 | 구현 단계 |
|------|---------|---------|
| 완료 overlay 방식 (`.overlay` vs `.fullscreenCover`) | `.overlay` 권장 | Step 10 착수 전 |
| 퍼즐 생성 실패 시 Alert vs 자동 홈 복귀 | Alert 후 홈 복귀 권장 | Step 9 구현 시 |
| COMPLETED 상태에서 연관 셀 하이라이트 유지 여부 | overlay 덮으면 불필요. 유지 | Step 9 구현 시 |
| extreme fallback 시 사용자 알림 여부 | 조용히 hard 전환 | Step 3 구현 시 |

---

## 6. 핵심 주의사항 (크로스 리뷰 결정 요약)

| 결정 코드 | 내용 |
|----------|------|
| C1 | 미선택 패드 비활성화 금지. 햅틱만 추가 |
| C2 | COMPLETED 상태에서 모든 입력 비활성화. Undo 스택 보존 |
| C3 | LOADING 중 뒤로가기 허용. `.task {}` modifier로 자동 취소 |
| C4 | 완료 기록 Phase 1에서도 저장. bestTime 쿼리에 `elapsedSeconds > 0` 필터 |
| C5 | GameControlsView `.frame(minHeight: 44)` + `.contentShape(Rectangle())` |
| C6 | SudokuCellView HIG 게임 그리드 예외. 처리 없음 |
| C7 | 접근성 Tier 1만 이번 범위: DifficultyRowView, 지우기 버튼, 메모 상태값 |

---

> 생성일: 2026-04-10 | Coordinator 역할 | UI/UX/Feature 분석 종합 + 소스 코드 직접 탐색
