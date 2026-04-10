# Feature Analysis — 화면 기능 연결 (E0BE83F0)

> **Role**: Feature Lead
> **분석 기준**: 코드베이스 역공학(reverse engineering) — 디자인 리소스 없음
> **분석 일자**: 2026-04-10

---

## 1. 데이터 구조

### 1.1 엔티티 정의

```
SudokuPuzzle (struct)
├── puzzle: [[Int]]        // 사용자에게 보여지는 초기 퍼즐 (0 = 빈 셀)
├── solution: [[Int]]      // 완성 정답 그리드
├── difficulty: Difficulty // 퍼즐 난이도
└── givens: Int            // 초기 제공 셀 수 (= 81 - 제거 셀 수)

SudokuBoard (struct)
└── cells: [[SudokuCell]]  // 9×9 배열 [행][열]
    ※ solution 필드 없음 — 완료 검증에 별도 solution 접근 필요

SudokuCell (struct)
├── value: Int             // 현재 입력값 (0 = 빈 셀, 1~9 = 유효값)
├── isFixed: Bool          // 초기 퍼즐 제공 셀 여부 (불변)
├── notes: Set<Int>        // 펜슬 모드 메모 (1~9 중 복수 선택)
└── isConflict: Bool       // 행/열/박스 내 중복 충돌 상태

GameState (struct)
├── board: SudokuBoard
├── selectedRow: Int?      // nil = 선택 없음
├── selectedCol: Int?      // nil = 선택 없음
├── isPencilMode: Bool
└── undoStack: [UndoEntry] // LIFO 스냅샷 스택 (크기 제한 없음)
    ※ solution/difficulty/elapsedTime 필드 없음 — 완료 검증/타이머에 별도 보관 필요

UndoEntry (struct)
├── board: SudokuBoard     // 전체 보드 스냅샷
├── selectedRow: Int?
└── selectedCol: Int?

GameRecordStats (struct, DTO)
├── completedCount: Int    // 완료 횟수
└── bestTime: Int?         // 최단 시간(초), 완료 기록 없으면 nil

Difficulty (enum: String, CaseIterable, Codable)
├── easy    → removalRange: 36...40
├── normal  → removalRange: 41...48
├── hard    → removalRange: 49...54
└── extreme → removalRange: 55...58
   ※ 총 81칸 기준 givens: easy=41~45, normal=33~40, hard=27~32, extreme=23~26
```

### 1.2 엔티티 관계

```
HomeViewModel ──has──> [Difficulty: GameRecordStats]  (메모리 캐시)
HomeViewModel ──owns──> GameRecordRepository
GameRecordRepository ──writes/reads──> GameRecord (CoreData)

GameViewModel ──owns──> GameState
GameState ──owns──> SudokuBoard
SudokuBoard ──contains──> SudokuCell[9][9]
GameState ──contains──> [UndoEntry]  (전체 보드 스냅샷 목록)

PuzzleGenerator ──produces──> SudokuPuzzle
SudokuPuzzle ──contains──> puzzle: [[Int]], solution: [[Int]]
SudokuPuzzle ──maps to──> SudokuBoard  (변환 필요, 직접 연결 없음)
```

### 1.3 유효성 규칙

| 필드 | 유효 범위 | 위반 시 동작 |
|------|-----------|------------|
| `SudokuCell.value` | 0~9 | 0 = 빈 셀. 10+ 입력 경로 없음 (NumberPad가 1~9+Delete만 제공) |
| `SudokuCell.notes` | Set<Int>, 원소 1~9 | 펜슬 모드에서만 설정. value != 0일 때 notes는 의미 없음 (value 설정 시 notes = []) |
| `SudokuCell.isFixed` | Bool, 초기화 후 불변 | `GameViewModel.inputNumber/clearCell`에서 `isFixed == true` 시 early return |
| `UndoEntry` | 개수 제한 없음 | 메모리 무제한 증가 가능 (엣지 케이스 참조) |
| `GameRecordRepository.elapsedSeconds` | Int64 | 타이머 구현 시 Int → Int64 변환 필요 (HomeViewModel.recordGame 파라미터) |
| `PuzzleGenerator.removalRange` | extreme: 55~58 (givens 23~26) | 유일해 충족이 어려워 while true 재시도 |

---

## 2. 비즈니스 로직

### 2.1 핵심 연결 갭 — 현재 미구현

```
[현재 상태]
HomeView.navigationDestination → Text("게임 화면: \(difficulty.displayName)")
                                  ↑ 플레이스홀더. 실제 GameView 미연결.

[필요 상태]
HomeView.navigationDestination → GameView(difficulty: difficulty, onGameCompleted: ...)
                                  ↓
                              GameViewModel(difficulty: difficulty)
                                  ↓
                              PuzzleGenerator().generate(difficulty:)  ← 이미 완성
```

**Gap 1**: `HomeView:42-46` — `navigationDestination` 클로저가 `Text` 렌더링
**Gap 2**: `GameViewModel.init(board:)` — difficulty 파라미터 없음. `PuzzleGenerator` 연결 없음
**Gap 3**: `GameViewModel` — `isCompleted: Bool` 프로퍼티 없음
**Gap 4**: `GameView` — 타이머(`elapsedSeconds`) 없음
**Gap 5**: `GameView` → `HomeViewModel.recordGame()` 호출 경로 없음

### 2.2 퍼즐 완료 검증 로직

퍼즐 완료 조건은 두 가지 방식이 가능하다:

**방식 A: 충돌 기반** (현재 인프라 활용)
```
isCompleted = 모든 cell.value != 0 AND 모든 cell.isConflict == false
```
- 장점: 추가 데이터 없이 기존 SudokuBoard 상태만으로 판정 가능
- 단점: `detectingConflicts()`는 동일 행/열/박스 내 중복만 검사. 이론상 충돌 없는 잘못된 답안이 완료로 판정될 수 있음 (스도쿠 규칙상 발생 가능성 극히 낮으나 이론적 허점 존재)

**방식 B: Solution 비교** (권장)
```
isCompleted = 모든 cell.value == solution[row][col]
```
- 장점: 정확한 완료 보장
- 단점: `GameState` 또는 `GameViewModel`에 solution 배열 보관 필요
- 구현: `GameViewModel`이 `SudokuPuzzle`을 저장하고, `solution` 프로퍼티 노출

> **권고**: 방식 B. `SudokuPuzzle`이 이미 `solution: [[Int]]`를 가지고 있으므로 `GameViewModel`이 `puzzle: SudokuPuzzle`을 저장하는 것이 자연스럽다.

### 2.3 완료 감지 시점

`inputNumber()` 호출 후 `detectingConflicts()` 재계산이 완료된 시점에 완료 체크.
`clearCell()` 호출 후에는 완료 체크 불필요 (빈 셀이 생기므로 완료 불가).

```
inputNumber() 흐름:
  pushUndo → 값 설정 → detectingConflicts → [NEW] checkCompletion → isCompleted 갱신
```

### 2.4 기록 저장 연결 경로

`HomeViewModel`을 `GameView`에서 접근하는 방법이 현재 없음. 세 가지 옵션:

**옵션 A: Closure Callback (권장)**
```swift
GameView(difficulty: difficulty, onGameCompleted: { elapsed in
    viewModel.recordGame(difficulty: difficulty, elapsedSeconds: elapsed, isCompleted: true)
})
```
- 장점: 단방향 데이터 흐름. GameView가 HomeViewModel에 직접 의존하지 않음
- 단점: 클로저 캡처에 주의 필요

**옵션 B: HomeViewModel 직접 주입**
```swift
GameView(difficulty: difficulty, homeViewModel: viewModel)
```
- 단점: GameView가 HomeViewModel에 직접 결합됨 — 과도한 의존성

**옵션 C: @Environment 전달**
- 단점: HomeViewModel의 @Observable + @Environment 설정 추가 필요. 현재 HomeView가 init에서 viewModel을 받는 구조와 불일치.

> **권고**: 옵션 A (Closure Callback). 최소 변경으로 단방향 의존성 유지.

### 2.5 타이머 설계

`elapsedSeconds`는 `GameViewModel` 또는 `GameView` 레벨 결정 필요:

- **GameViewModel 내**: Timer를 @Observable 모델에서 관리 → 순수 로직과 타이머 혼재. 테스트 어려움
- **GameView 내 (권고)**: `@State var elapsedSeconds: Int` + `Timer.publish`를 View에서 관리 → ViewModel은 게임 로직만 담당

> **권고**: GameView에서 `TimelineView` 또는 `onReceive(Timer.publish(...))` 로 관리.

---

## 3. 상태 전이 다이어그램

### 3.1 앱 수준

```
[앱 실행]
    ↓
[HomeView: idle]
    ↓ 난이도 탭 (selectedDifficulty 설정)
[HomeView → GameView 네비게이션 전환]
    ↓
[GameView: loading] ← PuzzleGenerator.generate() 실행 (동기)
    ↓ 퍼즐 생성 완료
[GameView: playing]
    ↓ (A) 퍼즐 완료           ↓ (B) back 제스처/버튼
[GameView: completed]      [GameView: dismissed]
    ↓                           ↓
[recordGame(isCompleted:true)] [타이머 정지, 상태 소멸]
    ↓
[HomeView 복귀 + stats 갱신]
```

### 3.2 GameViewModel 내부 상태

```
[초기화: init(difficulty:)]
    ↓ PuzzleGenerator().generate(difficulty:)
[playing: isCompleted = false]
    ↓ inputNumber / clearCell / undo / togglePencilMode
[playing: isCompleted = false] ← 루프
    ↓ inputNumber 후 완료 조건 충족
[completed: isCompleted = true]  ← 단방향, 취소 불가
```

> 완료 상태에서 undo로 되돌리면 isCompleted = false 복귀 여부 결정 필요.
> **권고**: Undo 시 완료 상태 재검증하여 isCompleted = false 처리.

### 3.3 UndoStack 상태

```
[빈 스택: canUndo = false]
    ↓ inputNumber() 또는 clearCell()
[스택에 UndoEntry 추가: canUndo = true]
    ↓ undo()
[스택에서 마지막 항목 pop, 보드 복원]
    ↓ (스택 비면)
[canUndo = false]
```

---

## 4. 저장 방식

### 4.1 영속 저장 (CoreData)

```
GameRecord (NSManagedObject)
├── difficulty: String     // Difficulty.rawValue
├── elapsedSeconds: Int64  // 소요 시간 (초)
├── completedAt: Date      // 기록 시점
└── isCompleted: Bool      // 완료 여부

저장 경로: GameRecordRepository.save() → NSManagedObjectContext.save()
조회 경로: GameRecordRepository.fetchStats() → NSFetchRequest with predicate
갱신 트리거: HomeViewModel.recordGame() → repository.save() → refresh()
```

### 4.2 메모리 상태 (비영속)

```
GameState (in-memory only)
- 게임 진행 상태: 보드, 선택 셀, 펜슬 모드, Undo 스택
- 앱 종료/백그라운드 복귀 시 소멸
- Resume(이어하기) 기능 없음
```

### 4.3 오프라인 동작

- 완전 로컬 앱 — 네트워크 의존성 없음
- 퍼즐 생성: 순수 알고리즘 (PuzzleGenerator, GridGenerator, UniqueSolutionValidator)
- 기록 저장: CoreData (SQLite) 로컬

---

## 5. 엣지 케이스 매트릭스

### 5.1 퍼즐 생성 엣지 케이스

| 케이스 | 발생 조건 | 현재 처리 | 위험도 | 권고 |
|--------|-----------|----------|--------|------|
| 퍼즐 생성 지연 | `extreme` 난이도, `removalRange: 55~58`에서 유일해 찾기 실패 반복 | `while true` 무한 루프 (동기) | 🔴 High | `async/await` 또는 `Task { }` 에서 비동기 생성, 로딩 인디케이터 표시 |
| 생성 중 화면 이탈 | 사용자가 생성 중 back 제스처 | Task 취소 처리 없음 | 🟠 Medium | `Task` 사용 시 `.task {}` modifier로 자동 취소 |
| 유일해 불가 그리드 | GridGenerator가 매우 드문 케이스 생성 | while true로 재시도 → 이론상 무한 대기 | 🟡 Low | 재시도 횟수 제한(예: 1000회) 후 fallback |

### 5.2 게임 플레이 엣지 케이스

| 케이스 | 발생 조건 | 현재 처리 | 위험도 | 권고 |
|--------|-----------|----------|--------|------|
| Undo 스택 메모리 과다 | 81셀 × 반복 입력/삭제, 각 UndoEntry = SudokuBoard 전체 스냅샷 | 크기 제한 없음 | 🟡 Medium | 최대 50개 제한 또는 diff 기반 저장 |
| 완료 후 Undo | `isCompleted = true` 상태에서 undo() 호출 | 미처리 (현재 isCompleted 없음) | 🟠 Medium | undo 후 완료 조건 재검증, isCompleted = false 복귀 |
| 고정 셀에 입력 시도 | `isFixed == true` 셀 선택 후 숫자 입력 | `guard !cell.isFixed` early return | ✅ 처리됨 | — |
| 펜슬 모드에서 값 있는 셀 | `cell.value != 0 && !isFixed`인 셀에 pencil 입력 | 현재: notes에 추가됨 (value는 유지) | 🟡 Low | value != 0 셀에서 pencil 입력 차단 또는 명확한 정책 정의 |
| 선택 없이 숫자 입력 | 셀 미선택 상태에서 NumberPad 탭 | `guard let row` early return | ✅ 처리됨 | — |
| 동일 숫자 재입력 | `cell.value == number` 재탭 | value = 0 (지우기)으로 처리 | ✅ 의도된 동작 | — |

### 5.3 완료 감지 엣지 케이스

| 케이스 | 발생 조건 | 처리 방안 |
|--------|-----------|----------|
| 충돌 있는데 모든 셀 채워짐 | 잘못된 숫자를 모두 입력한 경우 | 완료 조건: `isConflict == false` 필수 포함 |
| Solution 비교 vs 충돌 기반 불일치 | 충돌 없이 오답 완성 (이론적) | Solution 비교 방식 사용 시 불가능 |
| 퍼즐 완료 직후 Undo | 완료 직후 undo 탭 | isCompleted 재검증 필수 |
| 완료 감지 누락 | pencil 메모만 있고 value = 0인 셀이 마지막에 남음 | `cell.value != 0` 조건으로 정상 처리 |

### 5.4 타이머 엣지 케이스

| 케이스 | 위험도 | 처리 방안 |
|--------|--------|----------|
| 앱 백그라운드 전환 | 🟠 Medium | `scenePhase` 감지하여 타이머 일시 정지/재개 |
| 게임 완료 후 타이머 계속 실행 | 🟡 Low | `isCompleted` 감지 시 타이머 정지 |
| GameView dismiss 시 타이머 미정지 | 🟡 Low | `.task {}` 또는 `onDisappear`에서 정지 |
| elapsedSeconds overflow (Int → Int64) | 🟡 Low | Int 타이머 → `Int64(elapsedSeconds)` 변환. 스도쿠 게임 특성상 2^63초 초과 불가능 |
| 99시간+ 게임 | 매우 낮음 | mm:ss 포맷은 99:59까지 정상. 그 이상은 표시 형식 깨짐 (실용적 무시) |

### 5.5 네비게이션 엣지 케이스

| 케이스 | 발생 조건 | 현재 처리 | 권고 |
|--------|-----------|----------|------|
| 게임 중 back 제스처 | NavigationStack 스와이프 백 | 진행 데이터 소멸 (경고 없음) | Alert 확인 다이얼로그 ("게임을 종료하시겠습니까?") |
| 완료 후 자동 복귀 타이밍 | 완료 이후 HomeView 자동 전환 | 미구현 | 완료 Alert → 확인 시 dismiss |
| 중단 기록 저장 여부 | back 제스처로 이탈 시 | 저장 없음 | 이탈 확인 Alert에서 "기록 저장 없이 종료" 또는 `recordGame(isCompleted: false)` |

---

## 6. 에러 처리 전략

### 6.1 CoreData 저장 실패

```swift
// 현재: try? 로 에러 무시
func recordGame(...) {
    try? repository.save(...)  // 저장 실패 시 통계 갱신 안 됨
}
```

**현재 전략**: 저장 실패 시 무시 (사일런트 실패). 홈 통계가 갱신되지 않아 사용자가 인지하지 못함.
**위험도**: 🟡 Low — 로컬 앱에서 CoreData 저장 실패는 디스크 용량 부족 등 심각한 경우만 발생.
**권고**: 현재 전략 유지 허용. 단, refresh()는 저장 성공 여부와 무관하게 항상 호출할 것 (현재 코드는 save 후 refresh 호출하므로 OK).

### 6.2 fetchStats 실패

```swift
let s = (try? repository.fetchStats(for: difficulty))
    ?? GameRecordStats(completedCount: 0, bestTime: nil)
```

**현재 전략**: 실패 시 빈 통계(`completedCount: 0, bestTime: nil`)로 폴백. 사용자에게 "기록 없음"으로 표시됨.
**평가**: 적절한 폴백. 변경 불필요.

### 6.3 PuzzleGenerator 무한 루프

**현재 전략**: `while true` — 유일해를 만족할 때까지 무한 재시도.
**위험도**: 🔴 High — Main Thread에서 동기 실행 시 UI 블로킹.
**권고**: `Task { }` + `await` 처리. 극악 난이도에서 최소 수 초 소요 가능.

---

## 7. 역호환성 확인

### 7.1 GameViewModel.init 변경

**현재**: `init(board: SudokuBoard = .mock())`
**변경 후**: `init(difficulty: Difficulty)` 또는 `init(puzzle: SudokuPuzzle)`

```swift
// Preview 역호환성 유지 방법:
init(difficulty: Difficulty) { ... }                     // 실제 게임
init(board: SudokuBoard = .mock()) { ... }               // Preview 유지 (오버로딩)
// 또는:
static func preview() -> GameViewModel { ... }          // Preview 전용 팩토리
```

> **권고**: 별도 `init(board:)` 를 Preview 전용으로 유지하되 `private` 처리, `#if DEBUG` 또는 Preview에서만 사용.

### 7.2 GameView 인터페이스 변경

**현재**: `struct GameView: View` — 파라미터 없음
**변경 후**: `init(difficulty: Difficulty, onGameCompleted: (Int64) -> Void)` 추가

```swift
// #Preview 역호환:
#Preview {
    GameView(difficulty: .easy, onGameCompleted: { _ in })
}
```

### 7.3 ContentView / SdokuApp 영향 없음

`ContentView` → `HomeView(viewModel:)` 전달 구조는 변경 불필요.

---

## 8. 예시 데이터

### 8.1 정상 완료 흐름

```
입력 시나리오: easy 난이도 퍼즐 완료

1. HomeView: difficulty = .easy 탭
2. GameView 초기화: PuzzleGenerator().generate(.easy) 실행
   → givens: ~43개 셀이 채워진 SudokuPuzzle 반환
3. GameViewModel: SudokuBoard 구성 (isFixed = puzzle[r][c] != 0)
4. 사용자: 38개 빈 셀을 순서대로 채움 (~5분 소요)
5. 마지막 inputNumber() 호출 후:
   - board.cells 모두 value != 0
   - detectingConflicts() 후 모든 isConflict == false
   - (또는) board 값 == solution 모두 일치
   → isCompleted = true
6. GameView: onGameCompleted(Int64(elapsedSeconds)) 호출
7. HomeViewModel.recordGame(difficulty: .easy, elapsedSeconds: 312, isCompleted: true)
8. repository.save → CoreData 저장
9. refresh() → stats[.easy] = GameRecordStats(completedCount: 1, bestTime: 312)
10. NavigationStack dismiss → HomeView 복귀
    → "쉬움: 1회 완료, 05:12" 표시
```

### 8.2 게임 중단 흐름 (중단 기록 저장 시)

```
1. normal 난이도 게임 3분 진행 중
2. 사용자: back 제스처
3. Alert: "게임을 종료하시겠습니까?"
4. 확인 탭
5. HomeViewModel.recordGame(difficulty: .normal, elapsedSeconds: 180, isCompleted: false)
   → CoreData: isCompleted = false로 저장 (최고기록 집계에서 제외됨)
   → completedCount 변화 없음 (predicate: isCompleted == YES)
6. HomeView 복귀: 통계 변화 없음 (완료 기록만 집계)
```

### 8.3 Undo 스택 예시

```
초기: undoStack = [], board = [퍼즐 초기 상태]

Step 1: inputNumber(5) at (0,2)
  → pushUndo: undoStack = [Entry{board=초기, row=0, col=2}]
  → board[0][2].value = 5

Step 2: inputNumber(3) at (1,1)
  → pushUndo: undoStack = [Entry{초기,0,2}, Entry{board=step1, row=1, col=1}]
  → board[1][1].value = 3

Step 3: undo()
  → pop: Entry{board=step1, row=1, col=1}
  → board 복원 = step1 상태 (board[1][1].value = 0)
  → selectedRow=1, selectedCol=1 복원
  → undoStack = [Entry{초기,0,2}]
```

---

## 9. 다른 Lead들에게 전달할 주의사항

### → UI Lead

1. **GameView 파라미터 추가**: `GameView(difficulty: Difficulty, onGameCompleted: (Int64) -> Void)` 형태로 변경됨. Preview에서는 `GameView(difficulty: .easy, onGameCompleted: { _ in })` 형태로 갱신 필요.
2. **로딩 상태 UI**: PuzzleGenerator.generate()가 비동기 처리될 경우 로딩 인디케이터(`ProgressView`) 상태 추가 필요. 극악 난이도에서 최대 수 초 소요 가능.
3. **완료 피드백 UI**: `isCompleted` 감지 시 Alert 또는 Sheet 필요. Feature Lead 구현 후 연결.
4. **타이머 표시 공간**: 경과 시간 표시가 필요하다면 `GameView` 상단에 mm:ss 레이블 배치 공간 필요. 현재 "스도쿠" 타이틀 옆 또는 상단 별도 영역 검토.

### → UX Lead

1. **완료 후 흐름 확정 필요**: 퍼즐 완료 시 Alert → "홈으로" 버튼으로 dismiss할지, 자동 dismiss할지 결정 필요. Feature Lead는 두 방식 모두 구현 가능.
2. **중단 기록 저장 여부**: back 제스처 시 `isCompleted: false`로 기록 저장할지, 저장하지 않을지 UX 정책 결정 요청. (현재 repository.save는 isCompleted: false 저장 지원)
3. **펜슬 모드 + 값 있는 셀**: `cell.value != 0 && !isFixed` 셀에서 pencil 모드로 입력 시 현재 notes에 추가됨 (value 유지). 이 동작을 차단할지, 허용할지 UX 정책 확인 필요.

---

## 10. 코드 매핑 (REUSE / MODIFY / NEW)

### MODIFY

| 파일 | 변경 위치 | 변경 내용 |
|------|---------|----------|
| `HomeView.swift` | L42-46 | `navigationDestination` → `GameView(difficulty:, onGameCompleted:)` |
| `GameView.swift` | L4-23 | `difficulty: Difficulty`, `onGameCompleted: (Int64) -> Void` 파라미터 추가. 타이머 State 추가. `isCompleted` onChange 처리 |
| `GameViewModel.swift` | L22-24 | `init(difficulty: Difficulty)` 추가. `PuzzleGenerator().generate(difficulty:)` 연결. solution 보관 |

### NEW

| 대상 | 내용 |
|------|------|
| `GameViewModel.isCompleted: Bool` | `@Observable` 프로퍼티. 완료 조건 충족 시 true로 전환 (단방향) |
| `GameViewModel.checkCompletion()` | `inputNumber()` 호출 후 실행. solution 비교 또는 충돌 기반 검증 |
| `GameView` — 타이머 | `@State var elapsedSeconds = 0` + `onReceive(Timer.publish(every: 1, on: .main, in: .common))` |
| `GameView` — 완료 처리 | `.onChange(of: viewModel.isCompleted)` → `onGameCompleted(Int64(elapsedSeconds))` 호출 + Alert 또는 자동 dismiss |
| `GameView` — 비동기 퍼즐 생성 | `.task { }` 에서 `PuzzleGenerator().generate()` 비동기 실행 (Main Thread 블로킹 방지) |

### REUSE (변경 없음)

| 파일 | 이유 |
|------|------|
| `PuzzleGenerator.swift` | `generate(difficulty:)` API 완성 |
| `SudokuBoard.swift` | `detectingConflicts()` 완성, `mock()` Preview 유지 |
| `SudokuCell.swift` | 변경 없음 |
| `GameState.swift` | 변경 없음 (solution은 GameViewModel 레벨에서 보관) |
| `HomeViewModel.swift` | `recordGame(difficulty:elapsedSeconds:isCompleted:)` 완성 |
| `GameRecordRepository.swift` | 변경 없음 |
| `Difficulty.swift` | 변경 없음 |
| 모든 Component 뷰 | `SudokuGridView`, `GameControlsView`, `NumberPadView` 변경 없음 |
| `ContentView.swift`, `SdokuApp.swift` | 변경 없음 |
