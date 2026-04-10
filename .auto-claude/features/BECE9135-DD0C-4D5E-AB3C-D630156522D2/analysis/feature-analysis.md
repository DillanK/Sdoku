# Feature Analysis — 버그 수정 및 게임 화면 UI 개선

> **역할**: Feature Lead
> **분석 기준**: 소스코드 직접 역공학 + Spark 대화 합의 사항
> **분석 범위**: GameView, SudokuGridView, SudokuCellView, NumberPadView, GameControlsView, GameViewModel, GameState, SudokuBoard, SudokuCell
> **리서치 자료**: 참고 이미지(`aa.jpg`) 미첨부 → Spark 대화에서 Sudoku.com 스타일로 합의

---

## 1. 데이터 구조 (엔티티, 필드, 관계, 유효성 규칙)

### 1.1 엔티티 맵

```
GameState
├── board: SudokuBoard
│   └── cells: [[SudokuCell]]  // [0..8][0..8]
│       ├── value: Int          // 0 = 빈 셀, 1~9 = 숫자
│       ├── isFixed: Bool       // true = 초기 퍼즐 셀 (불변)
│       ├── notes: Set<Int>     // 메모 숫자 집합 {1..9}
│       └── isConflict: Bool    // 충돌 상태 (파생 속성)
├── selectedRow: Int?           // nil = 선택 없음, 0~8
├── selectedCol: Int?           // nil = 선택 없음, 0~8
├── isPencilMode: Bool
└── undoStack: [UndoEntry]
    ├── board: SudokuBoard      // 스냅샷
    ├── selectedRow: Int?
    └── selectedCol: Int?
```

### 1.2 유효성 규칙

| 필드 | 유효 범위 | 검증 위치 | 위반 시 |
|------|-----------|-----------|---------|
| `SudokuCell.value` | `[0, 9]` (정수) | 없음 — 퍼즐 생성기 보장 | 미정의 동작 (방어 로직 없음) |
| `SudokuCell.notes` | 각 원소 `[1, 9]` | 없음 — UI 입력 경로가 1~9만 허용 | 미정의 동작 |
| `SudokuCell.isFixed` | Bool, 생성 후 불변 (`let`) | 컴파일 타임 보장 | — |
| `selectedRow/Col` | `nil` 또는 `[0, 8]` | `selectCell` 파라미터가 GridView 루프(0..<9)에서 생성되므로 묵시적 보장 | 없음 |
| `undoStack` 크기 | 제한 없음 ⚠️ | 없음 | 장시간 플레이 시 메모리 누적 |
| `isSameNumber` (신규) | `cell.value == selectedValue && !isSelected && value != 0` | GameViewModel 또는 SudokuGridView에서 계산 | — |

### 1.3 파생 속성 의존 관계

```
SudokuCell.isConflict
  ← SudokuBoard.detectingConflicts()
    ← inputNumber(), clearCell() 호출 후 재계산
    ← 행/열/박스 중복 검사 (value != 0만 검사)

GameViewModel.selectedValue (신규 — 현재 없음)
  ← selectedRow, selectedCol, board.cells[r][c].value
  ← value != 0일 때만 non-nil

SudokuGridView.isRelated(row:col:)
  ← selectedRow, selectedCol
  ← 선택 셀 자체는 false 반환 (isSelected로 처리)

NumberPadView.isDisabled
  ← selectedRow, selectedCol
  ← board.cells[row][col].isFixed
```

---

## 2. 비즈니스 로직 (핵심 규칙, 상태 전이, 권한 분기)

### 2.1 버그: 빈 셀 선택 불가 — 근본 원인

**파일**: `SudokuCellView.swift:30-40`

```swift
// 현재 코드 — 버그 원인
private var backgroundColor: Color {
    if isSelected { return Color.blue.opacity(0.35) }
    else if cell.isConflict { return Color.red.opacity(0.15) }
    else if isRelated { return Color.blue.opacity(0.10) }
    else { return Color.clear }  // ← value=0, notes=[] 인 빈 셀
}
// SudokuCellView.swift:25: .aspectRatio(1, contentMode: .fit)
// .contentShape() 없음 → Color.clear 영역은 hit-testing 불가
```

**동작 메커니즘**:
1. 빈 셀(value=0, notes=[])은 `backgroundColor = Color.clear` 반환
2. ZStack 내 콘텐츠 없음 (`Text`, `NoteGridView` 모두 미렌더링)
3. SwiftUI hit-testing: 렌더링 픽셀 없는 투명 영역 → 탭 이벤트 무시
4. `SudokuGridView:27`의 `.onTapGesture { viewModel.selectCell(row:col:) }` 발동 안 됨
5. **단, 이미 다른 셀이 선택된 후** 빈 셀 탭 → 선택 셀이 `isRelated=true`로 `Color.blue.opacity(0.10)` 렌더링 → hit-testing 가능해지는 원인. 이것이 "숫자 선택 후 선택하면 동작"의 정확한 이유.

**수정 방법 (두 가지 모두 적용)**:
```swift
// Fix 1: contentShape 추가 (hit-testing 영역 명시)
ZStack { ... }
    .aspectRatio(1, contentMode: .fit)
    .contentShape(Rectangle())  // ← 추가

// Fix 2: Color.clear → Color(.systemBackground) (UI 개선 + 버그 보완)
else { return Color(.systemBackground) }
```

### 2.2 셀 배경색 우선순위 규칙 (To-Be)

```
우선순위 (높음 → 낮음):
1. isSelected       → cellSelected   (#BBDEFB / #1A3A5C)
2. isSameNumber     → cellSameNumber (#C8E6C9 / #1A3D1A)  [신규]
3. isConflict       → cellConflict   (#FFCDD2 / #3D1A1A)
4. isRelated        → cellRelated    (#E3F2FD / #152840)
5. default          → systemBackground
```

**우선순위 근거**:
- 선택(1)이 최우선: 현재 작업 컨텍스트 표시
- 동일 숫자(2) > 충돌(3): 선택 숫자 전체 현황 파악이 충돌 정보보다 더 넓은 컨텍스트 제공
- 충돌(3) > 연관(4): 오류 정보가 위치 힌트보다 중요
- **주의**: isSameNumber가 isConflict보다 높은 우선순위이므로, 동일 숫자이면서 충돌 상태인 셀은 초록 배경으로 표시됨 (충돌 표시가 숫자 색상으로만 전달됨 — 수용 가능)

### 2.3 selectCell 동작 규칙

```swift
// GameViewModel.swift:29-37
func selectCell(row: Int, col: Int) {
    if state.selectedRow == row, state.selectedCol == col {
        // 이미 선택된 셀 재탭 → 선택 해제
        state.selectedRow = nil; state.selectedCol = nil
    } else {
        state.selectedRow = row; state.selectedCol = col
    }
}
```

**중요**: `isFixed` 체크 없음 → 고정 셀도 선택 가능. NumberPad만 비활성화됨 (`NumberPadView.isDisabled`). 고정 셀 선택 시 `selectedValue`가 계산되므로 **동일 숫자 하이라이트가 고정 셀 선택에서도 작동해야 함**.

### 2.4 Undo 동작 규칙

- `pushUndo()`: `inputNumber()`, `clearCell()` 호출 전에만 실행 → 선택 상태 변경(selectCell)은 Undo 대상 아님
- `undo()`: 보드 + selectedRow/Col 복원 → 복원 후 충돌 재계산 없음 (Undo 스냅샷이 이미 충돌 계산 완료된 보드를 저장하므로 올바름)
- `canUndo`: `!undoStack.isEmpty` — GameControlsView에서 `disabled(!viewModel.canUndo)` 적용 ✅
- **Undo 후 isSameNumber**: selectedRow/Col가 복원되므로 `selectedValue`가 자동 재계산됨 → 별도 처리 불필요

### 2.5 inputNumber 동작 규칙

```
inputNumber(n) 호출 시:
1. selectedRow/Col 없으면 return
2. isFixed 셀이면 return
3. pushUndo() (현재 상태 스냅샷)
4. isPencilMode = true → notes.toggle(n)
   isPencilMode = false:
     value == n → value = 0 (동일 숫자 재입력 = 지우기)
     value != n → value = n, notes = []
5. detectingConflicts() 전체 보드 재계산
```

---

## 3. 상태 전이 다이어그램

### 3.1 셀 선택 상태 머신

```
[초기 상태]
selectedRow=nil, selectedCol=nil
모든 셀: default background

        ↓ 빈 셀 탭 (bug fix 후)

[셀 선택: 빈 셀]
selectedRow=r, selectedCol=c, cell.value=0
해당 셀: isSelected=true (cellSelected)
행/열/박스: isRelated=true (cellRelated)
동일 숫자 하이라이트: 없음 (value=0 → selectedValue=nil)

        ↓ 숫자 패드 n 탭

[셀 선택: 숫자 입력됨]
cell.value=n, notes=[]
동일 숫자 셀: isSameNumber=true (cellSameNumber)
충돌 시: isConflict=true, numberColor=red

        ↓ 같은 셀 재탭

[선택 해제]
selectedRow=nil, selectedCol=nil
→ 초기 상태로 복귀

        ↓ 다른 셀 탭

[셀 선택: 다른 셀]
이전 셀: 배경 초기화
새 셀: isSelected=true
```

### 3.2 동일 숫자 하이라이트 상태 전이

```
selectedValue = nil (선택 없음 또는 value=0 선택)
  → 전체 셀 isSameNumber=false

selectedValue = n (value=n인 셀 선택)
  → board.cells에서 value==n인 모든 (row,col)
  → isSelected인 셀 제외
  → isSameNumber=true
  → 배경색 우선순위에 따라 렌더링
```

### 3.3 게임 완료 조건 (기존 로직, 변경 없음)

```
모든 cells[r][c].value != 0
AND 모든 cells[r][c].isConflict == false
→ 완료 감지 (현재 GameViewModel에 isCompleted 프로퍼티 없음 — ContentView에서 처리)
```

**주의**: `isCompleted` 감지 로직이 `GameViewModel`에 없고 상위 레이어에서 처리 중. 이번 변경으로 영향 없음.

---

## 4. 인터랙션 흐름

### 4.1 버그 수정 후 전체 탭 흐름

```
사용자 탭 이벤트
  → SudokuGridView (onTapGesture, ForEach 루프에서 row/col 캡처)
  → viewModel.selectCell(row:col:)
  → @Observable 변경 → SwiftUI 재렌더링
  → SudokuGridView:
      - isSelected = (selectedRow==row && selectedCol==col)
      - isRelated = isRelated(row:col:)
      - isSameNumber = (selectedValue != nil && cell.value == selectedValue && !isSelected) [신규]
  → SudokuCellView 재렌더링
      - backgroundColor 재계산 (우선순위 적용)
```

### 4.2 동일 숫자 하이라이트 데이터 흐름

**방안 A: GameViewModel에서 계산 (권장)**
```swift
// GameViewModel에 추가
var selectedValue: Int? {
    guard let row = selectedRow, let col = selectedCol else { return nil }
    let v = board.cells[row][col].value
    return v != 0 ? v : nil
}
```

```swift
// SudokuGridView에서 전달
SudokuCellView(
    cell: viewModel.board.cells[row][col],
    isSelected: ...,
    isRelated: ...,
    isSameNumber: viewModel.selectedValue.map { $0 == viewModel.board.cells[row][col].value } ?? false
)
```

**방안 B: SudokuGridView에서 계산**
```swift
// SudokuGridView 내 함수로 추가
private func isSameNumber(row: Int, col: Int) -> Bool {
    guard let selRow = viewModel.selectedRow,
          let selCol = viewModel.selectedCol else { return false }
    let selectedValue = viewModel.board.cells[selRow][selCol].value
    guard selectedValue != 0 else { return false }
    if row == selRow && col == selCol { return false }  // 선택 셀 자체 제외
    return viewModel.board.cells[row][col].value == selectedValue
}
```

**권장**: 방안 B — `selectedValue`가 View 로직에 가까우며, ViewModel은 게임 규칙 로직만 유지. `isRelated`와 동일한 패턴으로 일관성 유지.

---

## 5. 저장 방식 (이번 기능 영향 없음)

| 레이어 | 저장 대상 | 방식 |
|--------|-----------|------|
| `GameState.undoStack` | 인메모리 스냅샷 | 앱 생명주기 내 메모리 한정 |
| `GameRecordRepository` | 완료 기록 | CoreData (변경 없음) |
| 현재 진행 중 게임 | **저장 없음** | 앱 종료 시 소실 (이번 기능 범위 외) |

---

## 6. 엣지 케이스 매트릭스

### 6.1 버그 관련 엣지 케이스

| 케이스 | 입력 조건 | 기대 동작 | 현재 동작 (버그) | 수정 후 |
|--------|-----------|-----------|-----------------|---------|
| EC-01 | 앱 최초 진입, 빈 셀 탭 | 셀 선택됨 | **탭 무시** | ✅ 수정됨 |
| EC-02 | 숫자 있는 셀 탭 후 빈 셀 탭 | 빈 셀 선택됨 | ✅ 동작 (isRelated 배경 덕분) | ✅ 유지 |
| EC-03 | 고정 셀 탭 후 빈 셀 탭 | 빈 셀 선택됨 | ✅ 동작 (고정 셀도 isFixed 상관없이 선택 가능) | ✅ 유지 |
| EC-04 | 메모가 있는 빈 셀(value=0, notes≠[]) 탭 | 선택됨 | ✅ NoteGridView 렌더링으로 hit-testing 가능 | ✅ 유지 + contentShape 중복 적용 |
| EC-05 | 이미 선택된 빈 셀 재탭 | 선택 해제 | **탭 무시 (isSelected=true면 배경 있으나)** → 실제로는 선택 후 재탭 가능 | ✅ 유지 |

> **EC-04 상세**: `notes` 있는 `value=0` 셀은 `NoteGridView`가 렌더링되어 hit-testing이 이미 작동함. `contentShape` 추가 후 더 안전해짐.

### 6.2 동일 숫자 하이라이트 엣지 케이스

| 케이스 | 조건 | 기대 동작 |
|--------|------|-----------|
| EC-06 | value=0 셀 선택 | isSameNumber=false (selectedValue=nil) → 하이라이트 없음 |
| EC-07 | 고정 셀 선택 (isFixed=true, value=n) | isSameNumber 동작 ✅ (selectCell은 isFixed 무관) |
| EC-08 | 동일 숫자가 충돌 상태 | isSameNumber=true, isConflict=true → 우선순위: `isSameNumber > isConflict` → 초록 배경, 빨간 숫자 |
| EC-09 | 9개 숫자 모두 완성된 상태에서 선택 | 전체 9개 셀 isSameNumber=true (isSelected 제외 8개) |
| EC-10 | 선택 해제 (selectedRow=nil) | selectedValue=nil → 모든 isSameNumber=false |
| EC-11 | Undo 후 | selectedRow/Col 복원 → selectedValue 자동 재계산 → 이전 하이라이트 상태 복원 |
| EC-12 | 메모 입력 중 (isPencilMode=true) 숫자 셀 선택 | isSameNumber 동작 (pencilMode와 무관) |

### 6.3 셀 상태 조합 매트릭스

| isSelected | isSameNumber | isConflict | isRelated | 배경색 |
|-----------|-------------|-----------|-----------|-------|
| ✅ | any | any | any | cellSelected (파란색) |
| ❌ | ✅ | ✅ | any | cellSameNumber (초록색) — 충돌은 숫자 색상으로만 표시 |
| ❌ | ✅ | ❌ | any | cellSameNumber (초록색) |
| ❌ | ❌ | ✅ | any | cellConflict (빨간색) |
| ❌ | ❌ | ❌ | ✅ | cellRelated (연파란색) |
| ❌ | ❌ | ❌ | ❌ | systemBackground (흰색/다크) |

### 6.4 경계값 케이스

| 케이스 | 조건 | 위험도 |
|--------|------|--------|
| EC-13 | undoStack 무한 성장 | 장시간 입력 반복 시 메모리 누적. 현재 제한 없음. **이번 범위 외** |
| EC-14 | board.cells 범위 초과 | `selectCell` 파라미터가 ForEach 0..<9에서 생성 → 실질적 불가능 |
| EC-15 | notes에 0 또는 10 삽입 | UI 경로에서 1~9만 허용 → 실질적 불가능 |
| EC-16 | 완료 상태(모든 셀 채움)에서 추가 탭 | `selectCell` 제한 없음 → 셀 선택은 가능. 완료 감지는 상위 레이어 처리 |

---

## 7. 에러 처리 전략

### 7.1 현재 에러 처리 패턴

```swift
// GameViewModel — guard + early return 패턴
func inputNumber(_ number: Int) {
    guard let row = state.selectedRow, let col = state.selectedCol else { return }
    let cell = state.board.cells[row][col]
    guard !cell.isFixed else { return }
    // ...
}
```

모든 사용자 입력 함수가 guard + early return으로 처리됨 → 에러를 사용자에게 노출하지 않음. 이번 기능 추가 시 동일 패턴 유지.

### 7.2 이번 기능 추가 시 에러 처리

| 상황 | 처리 방법 |
|------|-----------|
| `selectedValue` 계산 실패 | `guard` + `nil` 반환 (자동 처리) |
| `isSameNumber` 계산 시 board 범위 접근 | ForEach 루프 내 생성이므로 실질적 범위 초과 없음 |
| Color extension 미정의 | 컴파일 에러 → 개발 시 즉시 발견 |

---

## 8. 역호환성 확인

### 8.1 변경 영향 범위

| 변경 파일 | 인터페이스 변경 | 호출 측 영향 |
|-----------|----------------|-------------|
| `SudokuCellView.swift` | `isSameNumber: Bool` 파라미터 추가 | `SudokuGridView`에서 전달 필요 — **단일 호출 지점** |
| `SudokuGridView.swift` | `isSameNumber` 계산 + 전달 추가 | 변경 없음 (GameView, Preview만 사용) |
| `GameViewModel.swift` | `selectedValue: Int?` 추가 | 추가 전용, 기존 인터페이스 변경 없음 |
| `NumberPadView.swift` | 스타일 변경만 | 인터페이스 변경 없음 |
| `GameControlsView.swift` | 스타일 변경만 | 인터페이스 변경 없음 |
| `GameView.swift` | `.navigationTitle` 변경, 레이아웃 수정 | 인터페이스 변경 없음 |

### 8.2 Preview 업데이트 필요

```swift
// SudokuCellView.swift #Preview — isSameNumber 파라미터 추가 필요
SudokuCellView(
    cell: ...,
    isSelected: false,
    isRelated: false,
    isSameNumber: false  // ← 추가
)
```

### 8.3 CoreData / GameRecord 영향

없음. 이번 변경은 순수 게임 플레이 화면 UI/Logic이며, 데이터 영속성 레이어와 무관.

---

## 9. 코드 매핑 (REUSE / MODIFY / NEW)

| 파일 | 분류 | 변경 내용 | 변경 크기 |
|------|------|-----------|-----------|
| `Views/Components/SudokuCellView.swift` | **MODIFY** | `.contentShape(Rectangle())` 추가, `isSameNumber` 파라미터 추가, `backgroundColor` 우선순위 업데이트, `Color.clear` → `Color(.systemBackground)`, 폰트 22pt | Small |
| `Views/Components/SudokuGridView.swift` | **MODIFY** | `isSameNumber(row:col:)` 함수 추가, SudokuCellView 호출부 수정, 경계선 색상 분리(Light/Dark), 외곽 border 추가 | Small |
| `ViewModels/GameViewModel.swift` | **MODIFY** | `selectedValue: Int?` 프로퍼티 추가 (선택적 — 방안 A 채택 시) | XSmall |
| `Views/Components/NumberPadView.swift` | **MODIFY** | 높이 56, 폰트 26, cornerRadius 12, shadow, spacing 10, `systemBackground` | Small |
| `Views/Components/GameControlsView.swift` | **MODIFY** | cornerRadius 12, 레이블 폰트 13, 아이콘 20pt, 비활성 버튼 shadow 추가 | XSmall |
| `Views/GameView.swift` | **MODIFY** | `.navigationTitle(.inline)`, VStack spacing 재구성 | XSmall |
| `Color+Sudoku.swift` (신규) 또는 SudokuCellView 내 extension | **NEW** | `cellSelected`, `cellRelated`, `cellSameNumber`, `cellConflict` 시맨틱 색상 정의 | XSmall |

---

## 10. 예시 데이터

### 10.1 버그 재현 케이스

```swift
// 앱 시작 직후 상태
let state = GameState(
    board: SudokuBoard.mock(),  // value=0 셀 다수 포함
    selectedRow: nil,
    selectedCol: nil
)
// mock 보드의 (0,2) 셀: value=0, isFixed=false, notes=[], isConflict=false
// 탭 시: SudokuCellView.backgroundColor = Color.clear → hit-testing 실패
```

### 10.2 동일 숫자 하이라이트 예시

```swift
// SudokuBoard.mock() 기준
// cells[0][0].value = 5, cells[0][4].value = 7
// 사용자가 (0,0)을 탭 (value=5)
// selectedValue = 5
// isSameNumber=true인 셀들:
//   cells[r][c].value == 5 && !(r==0 && c==0)
//   → 보드 내 5가 있는 모든 셀 (고정 포함, 선택 셀 제외)
```

### 10.3 우선순위 충돌 예시

```swift
// 시나리오: 사용자가 (1,0)에 6을 입력했는데 충돌 발생 (cells[0][0].value도 6)
// 사용자가 cells[0][0] (value=6, isFixed=true) 탭
// → selectedValue = 6
// → cells[1][0] (value=6, isConflict=true):
//     isSameNumber=true, isConflict=true
//     우선순위: isSameNumber > isConflict
//     → backgroundColor = cellSameNumber (초록)
//     → numberColor = .red (isConflict 유지)
//     // 결과: 초록 배경 + 빨간 숫자 → 충돌이면서 같은 숫자임을 표현
```

---

## 11. 다른 Lead에게 전달할 Feature 주의사항

### UI Lead에게

1. **`Color.clear` → `Color(.systemBackground)` 변경**: hit-testing 수정 효과와 동시에 UI 개선. Dark Mode에서 `systemBackground = #1C1C1E` — GridLinesView의 `Canvas` 그리기 위에 올라오므로 색상 충돌 없음 (`GridLinesView.allowsHitTesting(false)` ✅).

2. **Color extension 파일**: `Color+Sudoku.swift` 분리 권장. 현재 프로젝트 규모상 `SudokuCellView.swift` 내 `private extension Color`도 허용. 단, `SudokuGridView`에서도 경계선 색상을 참조하므로 shared extension이 더 적합.

3. **GridLinesView Canvas 색상 분리**: `colorScheme` 환경변수 없이 `primary.opacity(0.8)` 단일값 사용 중. Light/Dark 분리 시 `@Environment(\.colorScheme)` 주입 필요. `private struct GridLinesView`이므로 `SudokuGridView`에서 전달하거나 직접 환경값 접근.

4. **`NoteGridView.font(.system(size: cellSize * 0.5))`**: cellSize * 0.38로 변경 시 메모 숫자 크기 축소 → 셀 여백 확보. `private struct`로 `SudokuCellView.swift`에 위치.

### UX Lead에게

1. **동일 숫자 하이라이트와 `isConflict` 동시 표시**: isSameNumber > isConflict 우선순위로 구현 시, 충돌 정보가 배경색으로 전달되지 않고 숫자 색상(빨간색)으로만 전달됨. 이 UX 트레이드오프가 허용 가능한지 최종 확인 요청.

2. **`GameControlsView` Undo 버튼**: 이미 `disabled(!viewModel.canUndo)` + `foregroundColor(canUndo ? .primary : .secondary)` 적용됨 ✅. 추가 opacity 변경 불필요 (foregroundColor 변경으로 충분히 구분됨).

3. **`selectCell`의 고정 셀 처리**: 고정 셀 탭 시 선택 상태 업데이트됨 → `selectedValue` 계산 → 동일 숫자 하이라이트 발동. 이 동작이 의도한 UX인지 확인 요청.

---

## 12. 범위 외 (이번 스프린트 제외)

- HomeView 디자인 변경
- 타이머/일시정지 UI
- 힌트/자동 메모
- 실수 횟수 제한 및 표시
- undoStack 크기 제한 (메모리 안전성)
- 게임 완료 애니메이션
- 접근성 레이블 (accessibilityLabel) — UX 분석에서 권장사항으로 제안되었으나 필수 아님
- Dynamic Type 완전 지원
- NavigationBar trailing 난이도 표시
