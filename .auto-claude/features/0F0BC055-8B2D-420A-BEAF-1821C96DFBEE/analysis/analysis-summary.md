# Analysis Summary — 기능 연동 (0F0BC055)

> **작성**: Coordinator 종합
> **기반**: ui-analysis.md + ux-analysis.md + feature-analysis.md + cross-review.md + code-mapping.md
> **작성일**: 2026-04-10

---

## 1. 핵심 구현 포인트 (우선순위 순)

### P1 — HomeView ↔ GameView 네비게이션 연결 [Critical]

현재 `HomeView.navigationDestination`에 `Text` placeholder만 존재. 난이도 선택 후 게임 화면으로 진입하는 흐름이 완전히 끊겨 있다.

- `GameView(difficulty: Difficulty, onGameEnd: (Difficulty, Int64, Bool) -> Void)` 시그니처로 연결
- `HomeView`가 `onGameEnd` 클로저를 구성 → `HomeViewModel.recordGame()` 호출 + `selectedDifficulty = nil` (pop)
- `GameViewModel`은 `HomeViewModel`을 직접 알지 못함 (클로저 주입 방식으로 의존성 격리)

### P2 — PuzzleGenerator 비동기화 [Critical]

`PuzzleGenerator.generate(difficulty:)`는 동기 백트래킹 루프. extreme 난이도에서 1초 이상 메인 스레드 블로킹 가능.

- `GameView.task { }` modifier + `await viewModel.loadPuzzle(difficulty:)` 패턴
- `@MainActor`에서 board 업데이트. `.task {}` 뷰 소멸 시 자동 취소 (LOADING 중 뒤로가기 허용)
- `while true` → 최대 100회 제한 + hard 난이도 fallback (extreme 무한루프 방어)

### P3 — 게임 완료 감지 및 기록 저장 [Critical]

`SudokuBoard.isSolved`, `GameViewModel.isCompleted`, `HomeViewModel.recordGame()` 연동이 모두 미구현.

- `SudokuBoard.isSolved`: `모든 cell.value != 0 AND 모든 cell.isConflict == false` (solution 비교 불필요)
- `GameViewModel.isCompleted`: `state.board.isSolved` computed property
- `GameView.onChange(of: viewModel.isCompleted)` → `onGameEnd(difficulty, 0, true)` 호출
- Phase 1 타이머 미구현: `elapsedSeconds: 0` 임시 저장. bestTime 쿼리에 `elapsedSeconds > 0` 필터 추가

### P4 — 뒤로가기 가드 [High]

iOS 스와이프 제스처로 기록 저장 없이 pop 가능. 미완성 게임 진행 상태가 유실됨.

- `.navigationBarBackButtonHidden(true)` + toolbar 커스텀 back 버튼
- 미완성 게임: Alert "게임을 종료하시겠어요?" → "종료" 시 `recordGame(isCompleted: false)` 후 pop
- LOADING 중 뒤로가기: Alert 없이 바로 pop (`.task {}` 자동 취소, 기록 저장 없음)

### P5 — SudokuPuzzle → SudokuBoard 변환 [High]

변환 로직이 현재 코드베이스에 없음. `GameViewModel.init(difficulty:)` 내부에서 구현 필요.

```
puzzle[row][col] == 0  → SudokuCell(value: 0, isFixed: false)
puzzle[row][col] != 0  → SudokuCell(value: v, isFixed: true)
```

### P6 — 완료/로딩 UI 컴포넌트 [Medium]

- `GameCompletionView`: 완료 overlay ("다시 하기" + "홈으로"). `.overlay` 패턴 권장 (fullscreenCover는 별도 NavigationStack 위험)
- `PuzzleLoadingView`: `ProgressView()` + "퍼즐 생성 중..." 텍스트. `viewModel.isLoading` 조건으로 표시

### P7 — 접근성 Tier 1 [Low]

| 항목 | 처리 |
|------|------|
| `DifficultyRowView` | `.accessibilityLabel(...)` (SF Symbol 이름 노출 방지) |
| 지우기 버튼 | `.accessibilityLabel("지우기")` |
| 메모 버튼 | `.accessibilityValue(isPencilMode ? "켜짐" : "꺼짐")` |

### P8 — GameControlsView HIG 탭 영역 [Low]

현재 38pt → `.frame(minHeight: 44)` + `.contentShape(Rectangle())` 추가로 해결.

---

## 2. 재활용 vs 신규 비율

| 분류 | 컴포넌트 수 | 비율 |
|------|-----------|------|
| **REUSE** (변경 없음) | 12 | 52% |
| **MODIFY** (수정) | 9 | 39% |
| **NEW** (신규) | 2 | 9% |
| **합계** | 23 | 100% |

**REUSE**: SudokuPuzzle, HomeViewModel, Difficulty, GridGenerator, UniqueSolutionValidator, SudokuGridView, SudokuCellView, GameState, SudokuCell, ContentView, SdokuApp, PersistenceController

**MODIFY**: SudokuBoard, GameRecordRepository, PuzzleGenerator, GameViewModel, GameControlsView, DifficultyRowView, NumberPadView, HomeView, GameView

**NEW**: GameCompletionView, PuzzleLoadingView

---

## 3. 구현 복잡도 평가

| Step | 대상 | 복잡도 | 근거 |
|------|------|--------|------|
| 1 | `SudokuBoard.isSolved` | **Low** | computed property 1개 추가 |
| 2 | `GameRecordRepository.bestTime` 쿼리 | **Low** | NSPredicate 조건 1개 추가 |
| 3 | `PuzzleGenerator` 재시도 제한 | **Low** | while 카운터 + fallback 분기 |
| 4 | `GameViewModel` 리팩토링 | **High** | async/await, Task 취소, 완료 감지, 상태 추가 등 다수 변경 |
| 5 | `GameControlsView` 탭 영역 | **Low** | modifier 2개 추가 |
| 6 | `DifficultyRowView` 접근성 | **Low** | accessibilityLabel modifier 추가 |
| 7 | `NumberPadView` 접근성+햅틱 | **Low** | 조건 분기 + UIFeedbackGenerator 추가 |
| 8 | `HomeView` navigationDestination | **Low** | placeholder → GameView 교체 |
| 9 | `GameView` 전면 수정 | **High** | 파라미터 추가, 커스텀 back 버튼, 완료/로딩 overlay 통합, onChange 핸들러 |
| 10 | `GameCompletionView` 신규 | **Medium** | 단순 overlay UI + 버튼 2개 |
| 11 | `PuzzleLoadingView` 신규 | **Low** | ProgressView + 텍스트 |

**전체 복잡도**: **Medium-High**
- Low 단계가 많지만, Step 4(GameViewModel)와 Step 9(GameView)가 구현의 핵심 병목
- 비동기 처리 + NavigationStack 상태 관리 + 클로저 주입 패턴이 복합적으로 얽힘

---

## 4. 권장 구현 순서

```
[Group A — 독립 병렬 실행 가능]
Step 1: SudokuBoard.isSolved
Step 2: GameRecordRepository.bestTime 쿼리 수정
Step 3: PuzzleGenerator 최대 재시도 제한
Step 5: GameControlsView 44pt 탭 영역
Step 6: DifficultyRowView Tier 1 접근성

        ↓ Group A 완료 후

[Group B — Step 4 의존]
Step 4: GameViewModel (difficulty init, isCompleted, isLoading, async 퍼즐 생성)

        ↓ Step 4 완료 후

[Group C — Step 4 의존, 병렬 가능]
Step 7:  NumberPadView 접근성 + 미선택 햅틱
Step 10: GameCompletionView (신규)
Step 11: PuzzleLoadingView (신규)

        ↓ Group C 완료 후

[Group D — 순차]
Step 9: GameView (모든 MODIFY 통합)
Step 8: HomeView navigationDestination 연결
```

---

## 5. 미해결 우려사항

### 5-1. Lead 간 양보 사항 (구현 시 보완 필요)

| # | 양보한 Lead | 내용 | 보완 방향 |
|---|------------|------|---------|
| A | UX Lead | 미선택 셀 패드 비활성화 포기 → 햅틱만으로 대체 (C1) | 햅틱 강도 검증 필요. 향후 "셀을 먼저 선택하세요" 토스트 메시지 추가 고려 |
| B | UX Lead | VoiceOver Tier 2 후속 작업으로 연기 | SudokuCellView 행/열 좌표, 충돌/고정 상태 레이블, Dynamic Type 미적용 상태로 릴리스됨 |
| C | Feature Lead | Phase 1 완료 기록 `elapsedSeconds: 0` 저장 허용 (C4) | Phase 2 타이머 추가 시 `elapsedSeconds > 0` 필터 유지 확인 필수. 기존 0 기록이 bestTime에 반영되지 않음을 QA 검증 |
| D | UI Lead | GameControlsView 패딩 증가 대신 `.contentShape` 방식으로 타협 (C5) | 실제 탭 인식률 기기별 검증 권장 (특히 iPhone SE) |
| E | Feature Lead | COMPLETED 후 Undo 비활성화로 자유도 포기 (C2) | overlay가 전체를 덮어 자연스럽게 차단되는지 구현 후 확인 필요 |

### 5-2. 구현 단계 결정 필요 사항 (미결)

| 항목 | 권장 방향 | 결정 시점 |
|------|---------|---------|
| 완료 overlay 방식 (`.overlay` vs `.fullscreenCover`) | `.overlay` 권장 | Step 10 착수 전 |
| 퍼즐 생성 실패 시 알림 방식 | Alert 표시 후 홈 복귀 권장 | Step 9 구현 시 |
| extreme fallback 시 사용자 알림 여부 | 조용히 hard 전환 (사용자 혼란 최소화) | Step 3 구현 시 |
| COMPLETED 상태에서 연관 셀 하이라이트 유지 여부 | overlay가 덮으므로 사실상 불필요 | Step 9 구현 시 |

### 5-3. Phase 2 기술 부채

| 항목 | 현재 상태 | Phase 2 작업 |
|------|---------|------------|
| 타이머 | 미구현. `elapsedSeconds: 0` 임시 저장 | 타이머 UI + 실제 elapsed 전달. bestTime 쿼리 필터 유지 |
| 인게임 상태 영속화 | 없음. 앱 백그라운드 종료 시 게임 상태 유실 | UserDefaults/CoreData에 GameState 직렬화 |
| VoiceOver Tier 2 | SudokuCellView 접근성 레이블 없음 | 행/열 좌표, 충돌/고정 상태 레이블 + Dynamic Type |
| 색상 대비 | 메모(.gray), 사용자 입력(.blue), 충돌(.red) 숫자가 WCAG AA 미달 | Dark Mode 포함 검증 + 보정 색상 지정 |

---

> 작성일: 2026-04-10 | Coordinator 종합 | 전체 분석 파일 기반
