# Feature Analysis — 기능 연동 (0F0BC055)

> **역할**: Feature Lead
> **분석 방법**: Swift 소스 코드 역방향 분석. 디자인 시안 없음.
> **범위**: HomeView ↔ GameView 연동, PuzzleGenerator 비동기화, 완료 감지, 기록 저장, 뒤로가기 가드

---

## 1. 데이터 구조 (엔티티 · 필드 · 관계 · 유효성 규칙)

### 1-1. 엔티티 맵

```
SdokuApp
└── ContentView
    └── HomeView
        ├── HomeViewModel                     (소유: @State)
        │   ├── stats: [Difficulty: GameRecordStats]
        │   ├── selectedDifficulty: Difficulty?   ← NavigationStack 트리거
        │   └── repository: GameRecordRepository
        └── NavigationStack
            └── GameView (push)               ← 현재 연결 없음 (placeholder)
                └── GameViewModel             (소유: @State)
                    └── state: GameState
                        ├── board: SudokuBoard
                        │   └── cells: [[SudokuCell]]
                        ├── selectedRow/Col: Int?
                        ├── isPencilMode: Bool
                        └── undoStack: [UndoEntry]
```

### 1-2. SudokuCell 필드 및 유효성

| 필드 | 타입 | 제약 | 불변 여부 |
|------|------|------|----------|
| `value` | `Int` | 0~9 (0 = 빈 셀) | 가변 (사용자 입력) |
| `isFixed` | `Bool` | 초기 퍼즐 제공 셀 | **불변** (let) |
| `notes` | `Set<Int>` | 원소 범위 1~9 | 가변 |
| `isConflict` | `Bool` | 행/열/박스 중복 시 true | 파생값 (detectingConflicts로 계산) |

**유효성 규칙**:
- `isFixed == true`인 셀은 `value` 변경 불가. `GameViewModel.inputNumber/clearCell`에서 guard로 강제.
- `value != 0`인 셀에 `notes`가 남아 있어도 구조상 허용되나, `inputNumber`(일반 모드)는 값 설정 시 notes를 즉시 비운다.
- **엣지케이스**: `notes`에 10 이상 또는 0이 삽입되는 것을 막는 유효성 검사 없음. UI(NumberPadView)가 1~9만 전달한다고 가정하는 암묵적 계약 존재.

### 1-3. SudokuPuzzle 필드 및 관계

| 필드 | 타입 | 설명 |
|------|------|------|
| `puzzle` | `[[Int]]` | 초기 상태 (0 = 빈 셀, 81 원소) |
| `solution` | `[[Int]]` | 완성 정답 (0 없음, 81 원소) |
| `difficulty` | `Difficulty` | 생성에 사용된 난이도 |
| `givens` | `Int` | 초기 제공 숫자 수 (81 - 제거된 셀 수) |

**SudokuPuzzle → SudokuBoard 변환 (현재 미구현)**:
```
puzzle[row][col] == 0  → SudokuCell(value: 0, isFixed: false)
puzzle[row][col] != 0  → SudokuCell(value: v, isFixed: true)
```
이 변환 로직이 현재 코드베이스에 존재하지 않는다. `GameViewModel.init`에서 구현 필요.

### 1-4. GameRecord CoreData 엔티티

| 필드 | CoreData 타입 | Swift 타입 | 제약 |
|------|-------------|----------|------|
| `difficulty` | String | `String` | Difficulty.rawValue 중 하나여야 함 |
| `elapsedSeconds` | Integer 64 | `Int64` | ≥ 0. Phase 1에서 0으로 저장 |
| `completedAt` | Date | `Date` | 저장 시점 타임스탬프 |
| `isCompleted` | Boolean | `Bool` | true = 완료, false = 중도 포기 |

**역호환성**: `elapsedSeconds == 0`인 완료 기록이 Phase 1에서 생성된다. Phase 2 타이머 추가 후 `bestTime` 쿼리에서 0이 최솟값으로 잡혀 "00:00" 표시 오염이 발생한다. → **중도 포기 기록(`isCompleted: false`)은 `bestTime` 쿼리에서 제외됨을 확인**. 완료 기록 중 `elapsedSeconds == 0`이 문제. 해결책: Phase 1에서 완료 기록을 아예 저장하지 않거나, `elapsedSeconds > 0` 조건을 `bestTime` 쿼리에 추가.

### 1-5. Difficulty 열거형

| case | rawValue | removalRange | givens 범위 |
|------|----------|-------------|------------|
| easy | "easy" | 36...40 | 41~45 |
| normal | "normal" | 41...48 | 33~40 |
| hard | "hard" | 49...54 | 27~32 |
| extreme | "extreme" | 55...58 | 23~26 |

**유효성 규칙**: `Difficulty.allCases`는 4개. CoreData `difficulty` 필드가 rawValue String을 직접 저장하므로, 향후 rawValue가 변경되면 기존 레코드 조회가 불가능해진다. rawValue는 변경 금지.

---

## 2. 비즈니스 로직 (핵심 규칙 · 상태 전이 · 권한 분기)

### 2-1. 핵심 규칙 목록

| # | 규칙 | 현재 위치 | 구현 상태 |
|---|------|---------|---------|
| R1 | 고정 셀(isFixed)은 입력/삭제 불가 | `GameViewModel.inputNumber/clearCell` | ✅ |
| R2 | 숫자 입력 시 전체 보드 충돌 재계산 | `SudokuBoard.detectingConflicts()` | ✅ |
| R3 | 동일 숫자 재입력 시 삭제 (토글) | `GameViewModel.inputNumber` | ✅ |
| R4 | 펜슬 모드에서 숫자 입력은 notes 토글 | `GameViewModel.inputNumber` | ✅ |
| R5 | 일반 모드 값 입력 시 notes 초기화 | `GameViewModel.inputNumber` | ✅ |
| R6 | Undo는 값+선택 위치 함께 복원 | `GameState.undo()` | ✅ |
| R7 | 퍼즐은 유일해(Unique Solution) 보장 | `UniqueSolutionValidator` | ✅ |
| R8 | 모든 셀이 채워지고 충돌이 없으면 완료 | `SudokuBoard` (isSolved 없음) | ❌ 미구현 |
| R9 | 완료/포기 시 게임 기록 저장 | `HomeViewModel.recordGame()` | ❌ 연동 없음 |
| R10 | 난이도 선택 → 해당 난이도 퍼즐 생성 | `PuzzleGenerator.generate()` | ❌ 연동 없음 |

### 2-2. isSolved 판정 로직 (구현 필요)

```
isSolved = (모든 셀의 value != 0) AND (모든 셀의 isConflict == false)
```

근거: 퍼즐 생성기가 유일해를 보장하므로, 81개 셀이 모두 채워지고 스도쿠 규칙 위반(충돌)이 없으면 그 배치는 반드시 유일해와 동일하다. `solution` 비교 없이도 완료 판정이 가능하다.

**주의**: `detectingConflicts()`는 `value == 0`인 셀에 대해 `false`를 반환한다. 따라서 빈 셀이 존재하면 충돌 없음처럼 보일 수 있다. isSolved 조건에 "모든 셀 value != 0" 선행 조건이 필수.

### 2-3. 게임 상태 전이 다이어그램

```
                        앱 실행
                           │
                           ▼
                     ┌─────────────┐
                     │  HOME_IDLE  │ ← HomeView 표시, stats 로드
                     └──────┬──────┘
                            │ 난이도 카드 탭 (selectedDifficulty = difficulty)
                            ▼
                     ┌─────────────┐
                     │   LOADING   │ ← PuzzleGenerator.generate() 실행 중
                     └──────┬──────┘
                            │ 퍼즐 생성 완료 (비동기)
                            ▼
                     ┌─────────────┐
            ┌───────│   PLAYING   │──────────────────────────┐
            │        └──────┬──────┘                          │
            │               │                                  │
            │ 뒤로가기       │ R8 충족 (isSolved == true)      │ 뒤로가기 (미구현)
            │               ▼                                  ▼
            │        ┌─────────────┐                  ┌──────────────────┐
            │        │  COMPLETED  │                  │ ABANDON_CONFIRM  │
            │        └──────┬──────┘                  └────────┬─────────┘
            │               │ recordGame(isCompleted: true)     │ "종료" 탭
            │               ▼                                   │ recordGame(isCompleted: false)
            │        ┌─────────────┐                           │
            └──────→ │  HOME_IDLE  │ ←─────────────────────────┘
                     └─────────────┘ (stats 갱신됨)
```

**현재 구현 갭**: LOADING → PLAYING, PLAYING → COMPLETED, PLAYING → ABANDON_CONFIRM 전이가 모두 미구현.

### 2-4. 권한 분기

| 조건 | 허용 동작 | 차단 동작 |
|------|---------|---------|
| `isFixed == true` | 셀 선택, 연관 하이라이트 | 숫자 입력, 지우기 |
| `selectedRow/Col == nil` | 셀 탭(선택), 모드 전환, Undo | 숫자 입력, 지우기 (guard로 무시) |
| `canUndo == false` | — | Undo (disabled) |
| COMPLETED 상태 | "다시 하기", "홈으로" | 셀 입력 (전체 패드 비활성화 필요) |

---

## 3. 인터랙션 흐름 (화면 전환 · 입력→결과 · 동시성)

### 3-1. 화면 전환 흐름

```
HomeView
  ├─ DifficultyRowView 탭
  │     └─ viewModel.selectedDifficulty = difficulty
  │           └─ NavigationStack.navigationDestination 트리거
  │                 └─ GameView(difficulty: difficulty) push
  │                       └─ onAppear: Task { puzzle 생성 }
  │
  └─ GameView
        ├─ 완료 감지 (onChange(of: viewModel.isCompleted))
        │     ├─ recordGame(difficulty, elapsedSeconds, isCompleted: true)
        │     └─ 완료 overlay 표시 → "홈으로" 탭 → selectedDifficulty = nil (pop)
        │
        └─ 뒤로가기 버튼 (커스텀 구현)
              ├─ 미완성 게임: Alert → "종료" → recordGame(isCompleted: false) → pop
              └─ 완료 후: 바로 pop (또는 완료 overlay에서 처리)
```

### 3-2. 입력 → 결과 흐름

| 입력 이벤트 | 경로 | 결과 상태 변화 |
|-----------|------|-------------|
| 숫자 N 탭 | `NumberPadView → GameViewModel.inputNumber(N)` | `cells[r][c].value` 갱신 + `detectingConflicts()` |
| 지우기 탭 | `NumberPadView → GameViewModel.clearCell()` | `cells[r][c].value = 0`, `notes = []` + `detectingConflicts()` |
| 메모 토글 | `GameControlsView → GameViewModel.togglePencilMode()` | `isPencilMode` 반전 |
| Undo 탭 | `GameControlsView → GameViewModel.undo()` | 이전 `board` + `selectedRow/Col` 복원 |
| 셀 탭 | `SudokuCellView → GameViewModel.selectCell(row, col)` | `selectedRow/Col` 갱신 또는 nil |

### 3-3. PuzzleGenerator 동시성 분석

**현재 문제**: `PuzzleGenerator.generate(difficulty:)`는 동기 `while true` 루프.

```swift
// 최악 케이스 실행 흐름 (extreme 난이도)
while true {
    let solution = gridGenerator.generateCompleteGrid()  // 백트래킹 ~수십ms
    if let puzzle = removeCells(from: solution, count: removalCount) {
        // removeCells 내부: UniqueSolutionValidator.isUnique() 반복 호출
        // extreme(55~58 제거): 최대 58회 × isUnique() 백트래킹
        return ...
    }
    // 실패 시 재시도 — 반복 횟수 무제한
}
```

**성능 추정**:
- easy: ~수십ms, 대부분 1회 성공
- extreme: 100ms~1s 이상 가능, 재시도 횟수 불확정

**필수 비동기 처리**:
```swift
// GameViewModel 내부 (개념적)
@Observable
final class GameViewModel {
    var isLoading: Bool = true
    // Task { } 또는 Task.detached { } 로 PuzzleGenerator.generate() 호출
    // MainActor에서 board 업데이트
}
```

`PuzzleGenerator`는 순수 CPU 연산이므로 `Task.detached(priority: .userInitiated)` 또는 `Task { }` 내 `await Task.yield()` 패턴 사용. `@MainActor`로 UI 업데이트 분리 필요.

### 3-4. recordGame 호출 경로 분석

`HomeViewModel.recordGame()`은 `HomeView`의 `@State`에 속한 `viewModel`의 메서드다. `GameView`가 이를 호출하려면 다음 중 하나의 경로가 필요하다:

| 접근 방식 | 장점 | 단점 |
|---------|------|------|
| **클로저 주입**: `GameView(onGameEnd: (Difficulty, Int64, Bool) -> Void)` | 의존성 명확, 테스트 용이 | HomeView가 클로저 생성 |
| **HomeViewModel 직접 주입**: `GameView(homeViewModel: HomeViewModel)` | 단순 | GameView가 HomeViewModel에 의존 |
| **Environment**: `@Environment(HomeViewModel.self)` | SwiftUI 관용적 | @Observable 환경 주입 설정 필요 |

**추천**: 클로저 주입 방식. `GameView`는 HomeViewModel을 알 필요 없고, "게임 종료 시 호출할 클로저"만 알면 된다.

---

## 4. 저장 방식 (로컬 · 캐시 · 동기화 · 오프라인)

### 4-1. 저장 레이어 구조

```
[런타임 상태] GameState (in-memory, @Observable)
      │ 게임 종료 시
      ▼
[영속 저장소] CoreData (SQLite, 로컬 전용)
      │ 앱 실행 / HomeView.onAppear 시
      ▼
[UI 캐시] HomeViewModel.stats: [Difficulty: GameRecordStats]
```

### 4-2. CoreData 저장 정책

| 항목 | 정책 |
|------|------|
| 저장 시점 | 게임 종료 시 즉시 (`context.save()`) |
| 저장 실패 처리 | `try?`로 무시 — 실패 시 사용자 알림 없음 |
| 읽기 실패 처리 | `try?` → 빈 통계 대체 — 허용 범위 |
| iCloud 동기화 | 없음 (로컬 전용) |
| 인게임 상태 영속화 | **없음** — 앱 종료 시 게임 상태 유실 |
| 게임 재개(Resume) | **미구현** — 범위 외 |

### 4-3. 인게임 상태 영속화 부재 (엣지케이스)

`GameState`는 메모리에만 존재한다. 다음 시나리오에서 진행 상태가 유실된다:
- 전화 수신 → 앱 백그라운드 전환 → iOS가 앱 종료
- 기기 배터리 방전
- 강제 종료

**현재 범위**: 인게임 상태 영속화는 구현 범위 외. 단, 뒤로가기 시 중도 포기 기록 저장은 포함되어야 한다.

---

## 5. 엣지 케이스 매트릭스

### 5-1. 퍼즐 생성 엣지케이스

| 케이스 | 발생 조건 | 현재 처리 | 위험도 |
|-------|---------|---------|--------|
| 생성 무한루프 | extreme 난이도에서 유일해 찾기 실패 반복 | `while true` — 무제한 재시도 | **높음** (UI 완전 블로킹) |
| 생성 중 뒤로가기 | 사용자가 LOADING 중 탭 | 처리 없음 — Task 취소 로직 필요 | **높음** |
| 동일 퍼즐 재생성 | removalRange가 좁아 동일 퍼즐 생성 가능성 | 없음 (수학적으로 매우 낮음) | 낮음 |

**extreme 무한루프 대책 필요**: 최대 시도 횟수(예: 100회) 제한 + 초과 시 hard 난이도로 fallback 또는 에러 처리.

### 5-2. 입력 엣지케이스

| 케이스 | 발생 조건 | 현재 처리 | 위험도 |
|-------|---------|---------|--------|
| 셀 미선택 숫자 입력 | `selectedRow == nil`에서 숫자 탭 | `guard`로 무시, 피드백 없음 | 낮음 (UX 이슈) |
| 고정 셀 입력 시도 | isFixed 셀 선택 후 숫자 탭 | `guard`로 무시, 패드 disabled | ✅ |
| 완료 후 추가 입력 | COMPLETED 상태에서 입력 | 처리 없음 — 완료 감지 미구현 | **중간** |
| notes에 0 또는 10+ 삽입 | UI 외부 경로(프리뷰 등)에서 직접 주입 시 | 검증 없음 | 낮음 |
| Undo 후 완료 상태 재진입 | 완료 후 Undo로 빈 셀 만들기 | 처리 없음 — 완료 상태에서 Undo 가능 여부 정책 필요 | **중간** |

**Undo 후 완료 재진입**: COMPLETED 상태에서 Undo를 허용하면 `isCompleted`가 `false`로 돌아간다. 이 경우 이미 저장된 완료 기록과 실제 게임 상태가 불일치. 해결: COMPLETED 진입 즉시 Undo 스택 초기화 또는 COMPLETED에서 Undo 비활성화.

### 5-3. CoreData 엣지케이스

| 케이스 | 발생 조건 | 현재 처리 | 위험도 |
|-------|---------|---------|--------|
| 저장 실패 | 디스크 풀 또는 CoreData 오류 | `try?` 무시 | 낮음 (로컬 게임 특성상 허용) |
| `elapsedSeconds == 0` 완료 기록 | Phase 1 타이머 미구현 | bestTime이 "00:00" 표시 | **중간** (Phase 2 마이그레이션 필요) |
| 동시 context 접근 | 백그라운드 Task에서 CoreData 접근 | `viewContext` 직접 사용 | **중간** (viewContext는 main thread 전용) |
| 기록 무한 증가 | 게임 반복 플레이 | 제한 없음 | 낮음 (로컬 저장소) |

**CoreData 동시성**: `PuzzleGenerator`를 background Task로 실행하더라도, `recordGame()` 호출은 반드시 MainActor(viewContext) 컨텍스트에서 이뤄져야 한다.

### 5-4. 네비게이션 엣지케이스

| 케이스 | 발생 조건 | 현재 처리 | 위험도 |
|-------|---------|---------|--------|
| LOADING 중 뒤로가기 | 퍼즐 생성 Task 실행 중 pop | Task 취소 없음 → 유령 Task 지속 | **높음** |
| 빠른 연속 탭 | DifficultyRowView 빠르게 여러 번 탭 | `selectedDifficulty`가 연속 설정 → 중복 GameView push 가능 | **중간** |
| 게임 완료 후 시스템 뒤로가기 (스와이프) | iOS 스와이프 제스처 | 가로채기 없음 → 기록 저장 없이 pop | **높음** |

**빠른 연속 탭 방어**: `navigationDestination(item:)`은 non-nil일 때 push이므로, 동일 difficulty 재탭은 이미 표시 중이면 효과 없다. 단, 다른 difficulty 연속 탭은 `selectedDifficulty` 교체 → 기존 GameView pop + 새 GameView push (정상 동작이나 퍼즐 생성 Task 누적 위험).

---

## 6. 코드 매핑 (REUSE / MODIFY / NEW)

| 파일/컴포넌트 | 분류 | 변경 내용 |
|-------------|------|---------|
| `SudokuBoard` | **MODIFY** | `isSolved: Bool` computed property 추가 |
| `GameViewModel` | **MODIFY** | `init(difficulty:)` 추가, `isCompleted` computed property 추가, `isLoading` 상태 추가, async 퍼즐 생성 로직 추가 |
| `GameView` | **MODIFY** | `difficulty: Difficulty` 파라미터 수신, `onGameEnd` 클로저 수신, 완료 감지 `onChange`, 뒤로가기 가드 구현 |
| `HomeView` | **MODIFY** | `navigationDestination` placeholder → `GameView(difficulty:onGameEnd:)` 연결 |
| `SudokuPuzzle` | **REUSE** | 변경 없음 |
| `PuzzleGenerator` | **REUSE** | 변경 없음 (호출 측에서 비동기 처리) |
| `HomeViewModel` | **REUSE** | `recordGame()` 시그니처 변경 없음 |
| `GameRecordRepository` | **REUSE** | 변경 없음 |
| `Difficulty` | **REUSE** | 변경 없음 |
| 완료 overlay 뷰 | **NEW** | 완료 피드백 UI (UI Lead 설계 후) |
| 로딩 overlay 뷰 | **NEW** | 퍼즐 생성 중 ProgressView (UI Lead 설계 후) |

---

## 7. Feature Lead → 다른 Lead 전달 주의사항

### UI Lead에게

1. **로딩 상태 UI 필요**: `GameViewModel.isLoading: Bool` 상태를 소비할 overlay 또는 skeleton 디자인 요청. 퍼즐 생성 중 그리드 영역에 표시 권장.

2. **완료 overlay 디자인 필요**: COMPLETED 상태 진입 시 표시할 overlay. "다시 하기" + "홈으로" 버튼 포함. Feature에서 `isCompleted` 상태를 제공하고, UI가 이를 소비.

3. **`elapsedSeconds == 0` 표시 정책**: Phase 1에서 완료 기록의 bestTime이 "00:00"으로 표시될 수 있음. 타이머 미구현 동안 bestTime 표시를 억제하는 UI 처리 필요 (예: `elapsedSeconds == 0`이면 "기록 없음"으로 표시).

### UX Lead에게

1. **COMPLETED 이후 Undo 정책 결정 필요**: COMPLETED 진입 후 Undo 허용 시 완료 상태가 되돌아감. Feature는 정책 결정에 따라 Undo 비활성화 또는 스택 초기화 중 하나를 구현.

2. **LOADING 중 뒤로가기 허용 여부 결정 필요**: 허용 시 Task 취소 + 기록 미저장. 차단 시 `.interactiveDismissDisabled(true)` + 커스텀 취소 버튼 필요.

3. **빠른 연속 난이도 탭 시나리오**: 사용자가 실수로 다른 난이도를 탭하면 기존 게임 진행이 즉시 파기됨. 홈에서 난이도 선택 시 확인 불필요하나, PLAYING → 다른 난이도로 전환 경로가 발생하면 경고 필요. (현재는 HomeView에서만 선택하므로 PLAYING 중 이 경로는 없음 — 확인)

---

## 8. 예시 데이터

### 8-1. 정상 완료 시나리오 예시 데이터

```swift
// HomeViewModel.recordGame 호출 시 (Phase 1, 타이머 없음)
difficulty: .easy
elapsedSeconds: 0       // Phase 1 임시값
isCompleted: true

// CoreData 저장 결과
GameRecord {
    difficulty: "easy"
    elapsedSeconds: 0
    completedAt: 2026-04-10T14:23:00Z
    isCompleted: true
}

// HomeViewModel.stats 갱신 후
stats[.easy] = GameRecordStats(completedCount: 1, bestTime: 0)
// → DifficultyRowView: "1회 완료", "00:00" ← Phase 1 이슈
```

### 8-2. 중도 포기 시나리오 예시 데이터

```swift
difficulty: .hard
elapsedSeconds: 0
isCompleted: false

// bestTime 쿼리: isCompleted == YES 조건으로 필터링
// → 이 기록은 bestTime에 반영되지 않음 ✅
// → completedCount에도 반영되지 않음 ✅
```

### 8-3. Difficulty.removalRange 예시 (extreme)

```
removalRange: 55...58
→ removalCount = Int.random(in: 55...58) = 예: 56
→ givens = 81 - 56 = 25
→ 25개 숫자만 보이는 퍼즐
→ UniqueSolutionValidator: 56번 × isUnique() 호출
→ 실패 시 gridGenerator.generateCompleteGrid() 재호출
```

### 8-4. isSolved 판정 예시

```
// 완료 상태
cells: 모든 value ∈ [1~9], 모든 isConflict == false
→ isSolved = true

// 미완료 상태 A (빈 셀 존재)
cells: cells[3][4].value == 0
→ isSolved = false (value != 0 조건 위반)

// 미완료 상태 B (충돌 존재)
cells: 모든 value ∈ [1~9], cells[0][0].isConflict == true
→ isSolved = false (isConflict 조건 위반)
```

---

> 생성일: 2026-04-10 | Feature Lead 역할 | 코드 기반 역방향 분석
