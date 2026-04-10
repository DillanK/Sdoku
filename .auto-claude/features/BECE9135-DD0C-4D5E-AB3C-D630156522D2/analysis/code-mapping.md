# Code Mapping — 버그 수정 및 게임 화면 UI 개선

> **작성일**: 2026-04-10
> **기준 브랜치**: master (47f1a73)
> **분석 소스**: ui-analysis.md, ux-analysis.md, feature-analysis.md, cross-review.md + 소스코드 직접 역공학

---

## 분류 기준

| 분류 | 정의 |
|------|------|
| **REUSE** | 기존 코드 그대로 재활용 — 변경 불필요 |
| **MODIFY** | 기존 파일에 변경 필요 — 변경 범위 명시 |
| **NEW** | 신규 파일/구조체 생성 필요 |

---

## 1. NEW — 신규 생성

### `Color+Sudoku.swift`

**위치**: `Sdoku/Sdoku/Views/` (또는 `Sdoku/Sdoku/` 루트)
**이유**: `SudokuCellView`(셀 배경)와 `SudokuGridView`(경계선 색상) 양쪽에서 참조 → shared extension 필수
**추천 패턴**: Swift extension on `Color`

**정의할 색상 상수**:

```swift
extension Color {
    // 셀 배경
    static let cellSelected  = Color(light: Color(hex: "#BBDEFB"), dark: Color(hex: "#1A3A5C"))
    static let cellRelated   = Color(light: Color(hex: "#E3F2FD"), dark: Color(hex: "#152840"))
    static let cellSameNumber = Color(light: Color(hex: "#C8E6C9"), dark: Color(hex: "#1A3D1A"))
    static let cellConflict  = Color(light: Color(hex: "#FFCDD2"), dark: Color(hex: "#3D1A1A"))

    // 텍스트
    static let noteText      = Color(light: Color(hex: "#616161"), dark: Color(hex: "#9E9E9E"))

    // 경계선
    static let gridLineThin  = Color(light: Color(hex: "#BDBDBD"), dark: Color(hex: "#424242"))
    static let gridLineBold  = Color(light: Color(hex: "#424242"), dark: Color(hex: "#9E9E9E"))
}
```

> Light/Dark 분기를 위한 `init(light:dark:)` 헬퍼 또는 `@Environment(\.colorScheme)` 활용
> hex 초기화 헬퍼(`Color(hex:)`)도 이 파일에 포함

**의존성**: 없음 (다른 모든 MODIFY 작업의 전제조건)

---

## 2. MODIFY — 기존 파일 수정

### 2-1. `SudokuCellView.swift`

**파일 경로**: `Sdoku/Sdoku/Views/Components/SudokuCellView.swift`

#### 변경 1: 인터페이스 — `isSameNumber` 파라미터 추가

```swift
// 현재 (L4-L9)
struct SudokuCellView: View {
    let cell: SudokuCell
    let isSelected: Bool
    let isRelated: Bool
}

// To-Be
struct SudokuCellView: View {
    let cell: SudokuCell
    let isSelected: Bool
    let isRelated: Bool
    let isSameNumber: Bool  // 신규 — 같은 숫자 셀 하이라이트
}
```

**호출 측 영향**: `SudokuGridView.swift` 단일 호출 지점 (`L21-L25`) + `#Preview` (L86-L112)

#### 변경 2: 버그 수정 — `contentShape` + `Color.clear` 제거

```swift
// 현재 (L24-L26)
}
.aspectRatio(1, contentMode: .fit)

// To-Be
}
.aspectRatio(1, contentMode: .fit)
.contentShape(Rectangle())  // 빈 셀 hit-testing 보장
```

#### 변경 3: `backgroundColor` 우선순위 재작성

```swift
// 현재 (L30-L40) — isSameNumber 없음, Color.clear 사용
private var backgroundColor: Color {
    if isSelected { return Color.blue.opacity(0.35) }
    else if cell.isConflict { return Color.red.opacity(0.15) }
    else if isRelated { return Color.blue.opacity(0.10) }
    else { return Color.clear }
}

// To-Be — 우선순위: isSelected > isSameNumber > isConflict > isRelated > default
private var backgroundColor: Color {
    if isSelected      { return .cellSelected }
    if isSameNumber    { return .cellSameNumber }
    if cell.isConflict { return .cellConflict }
    if isRelated       { return .cellRelated }
    return Color(.systemBackground)
}
```

#### 변경 4: 폰트 크기 및 weight 조정

```swift
// 현재 (L18)
.font(.system(size: 20, weight: cell.isFixed ? .bold : .regular))

// To-Be
.font(.system(size: 22, weight: cell.isFixed ? .bold : .medium))
```

#### 변경 5: `NoteGridView` 메모 폰트 비율 + 색상

```swift
// 현재 (L69-L71)
.font(.system(size: cellSize * 0.5))
.foregroundColor(.gray)

// To-Be
.font(.system(size: cellSize * 0.38))
.foregroundColor(.noteText)  // Color+Sudoku.swift 정의값
```

#### 변경 6: 접근성 레이블 추가

```swift
// ZStack 클로저 이후, aspectRatio 앞에 추가
.accessibilityLabel(accessibilityDescription)
.accessibilityAddTraits(isSelected ? .isSelected : [])

// 신규 computed property
private var accessibilityDescription: String {
    if cell.value != 0 {
        return "\(cell.isFixed ? "고정 " : "")\(cell.value)"
    } else if !cell.notes.isEmpty {
        let noteList = cell.notes.sorted().map { "\($0)" }.joined(separator: ", ")
        return "메모: \(noteList)"
    } else {
        return "빈 셀"
    }
}
```

#### 변경 7: `#Preview` — `isSameNumber` 파라미터 추가

```swift
// 기존 모든 SudokuCellView(cell:isSelected:isRelated:) 호출에
// isSameNumber: false  추가
```

**변경 크기**: Small (약 30줄 변경/추가)
**의존성**: Color+Sudoku.swift (Step 1 완료 후)

---

### 2-2. `SudokuGridView.swift`

**파일 경로**: `Sdoku/Sdoku/Views/Components/SudokuGridView.swift`

#### 변경 1: `@Environment` 주입 — colorScheme

```swift
// struct 상단에 추가
@Environment(\.colorScheme) private var colorScheme
```

#### 변경 2: `isSameNumber(row:col:)` 함수 추가

```swift
// isRelated 함수(L46-L58) 아래에 추가
/// 선택된 셀과 동일한 숫자를 가지는지 확인 (선택 셀 자체 제외)
private func isSameNumber(row: Int, col: Int) -> Bool {
    guard let selRow = viewModel.selectedRow,
          let selCol = viewModel.selectedCol else { return false }
    let selectedValue = viewModel.board.cells[selRow][selCol].value
    guard selectedValue != 0 else { return false }
    if row == selRow && col == selCol { return false }
    return viewModel.board.cells[row][col].value == selectedValue
}
```

#### 변경 3: `SudokuCellView` 호출부 — `isSameNumber` 전달

```swift
// 현재 (L21-L25)
SudokuCellView(
    cell: viewModel.board.cells[row][col],
    isSelected: viewModel.selectedRow == row && viewModel.selectedCol == col,
    isRelated: isRelated(row: row, col: col)
)

// To-Be
SudokuCellView(
    cell: viewModel.board.cells[row][col],
    isSelected: viewModel.selectedRow == row && viewModel.selectedCol == col,
    isRelated: isRelated(row: row, col: col),
    isSameNumber: isSameNumber(row: row, col: col)
)
```

#### 변경 4: 외곽 border 추가

```swift
// .aspectRatio(1, contentMode: .fit) 바로 위에 추가
.overlay(
    RoundedRectangle(cornerRadius: 4)
        .stroke(Color.gridLineBold, lineWidth: 2.5)
)
```

#### 변경 5: `GridLinesView` — 경계선 색상 Light/Dark 분리

```swift
// 현재 (L83-L87) — Light/Dark 동일
context.stroke(
    path,
    with: .color(.primary.opacity(0.8)),
    lineWidth: isBold ? 2.5 : 0.5
)

// To-Be — Color+Sudoku.swift 상수 사용
// GridLinesView에 colorScheme 주입 또는 Color extension으로 처리
context.stroke(
    path,
    with: .color(isBold ? Color.gridLineBold : Color.gridLineThin),
    lineWidth: isBold ? 2.5 : 0.5
)
```

> `private struct GridLinesView`는 `@Environment` 직접 접근 가능. `@Environment(\.colorScheme)` 추가.

**변경 크기**: Small (약 20줄 변경/추가)
**의존성**: Color+Sudoku.swift (Step 1), SudokuCellView 인터페이스 변경 (Step 3)

---

### 2-3. `NumberPadView.swift`

**파일 경로**: `Sdoku/Sdoku/Views/Components/NumberPadView.swift`

#### 변경 1: 레이아웃 — spacing, 높이, cornerRadius

```swift
// 현재 (L16-L29)
let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
LazyVGrid(columns: columns, spacing: 8) {
    ...
    .frame(height: 52)
    .background(Color(.secondarySystemBackground))
    .cornerRadius(10)

// To-Be
let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
LazyVGrid(columns: columns, spacing: 10) {
    ...
    .frame(height: 56)
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
```

#### 변경 2: 폰트 크기

```swift
// 현재 (L25)
.font(.system(size: 24, weight: .semibold))

// To-Be
.font(.system(size: 26, weight: .semibold))
```

#### 변경 3: 지우기 버튼 동일 스타일 적용 + 접근성

```swift
// 현재 (L35-L45)
.frame(height: 52)
.background(Color(.secondarySystemBackground))
.cornerRadius(10)

// To-Be
.frame(height: 56)
.background(Color(.systemBackground))
.cornerRadius(12)
.shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
.accessibilityLabel("지우기")
```

#### 변경 4: 숫자 버튼 접근성 레이블

```swift
// 각 숫자 버튼 Button label에 추가
.accessibilityLabel("\(number)")
```

**변경 크기**: Small (약 15줄 변경)
**의존성**: 없음 (독립적으로 변경 가능)

---

### 2-4. `GameControlsView.swift`

**파일 경로**: `Sdoku/Sdoku/Views/Components/GameControlsView.swift`

#### 변경 1: cornerRadius 12pt

```swift
// 현재 (L30, L35, L45, L54)
.cornerRadius(10)
RoundedRectangle(cornerRadius: 10)

// To-Be
.cornerRadius(12)
RoundedRectangle(cornerRadius: 12)
```

#### 변경 2: 레이블 폰트 13pt, 아이콘 20pt

```swift
// 현재 (L16, L18)
.font(.system(size: 18))        // 아이콘
.font(.system(size: 15, weight: .medium))  // 레이블

// To-Be
.font(.system(size: 20))        // 아이콘
.font(.system(size: 13, weight: .medium))  // 레이블
```

> 두 버튼(메모, 되돌리기) 모두 동일하게 적용

#### 변경 3: V padding 증가

```swift
// 현재 (L21, L50)
.padding(.vertical, 10)

// To-Be
.padding(.vertical, 12)
```

#### 변경 4: 비활성(되돌리기) 버튼 — `systemBackground` + shadow

```swift
// 현재 (L51)
.background(Color(.secondarySystemBackground))

// To-Be
.background(Color(.systemBackground))
// 추가
.shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
```

> 메모 버튼 비활성 상태(isPencilMode=false)도 동일하게 변경

**변경 크기**: XSmall (약 10줄 변경)
**의존성**: 없음 (독립적으로 변경 가능)

---

### 2-5. `GameView.swift`

**파일 경로**: `Sdoku/Sdoku/Views/GameView.swift`

#### 변경 1: `Text("스도쿠")` → `.navigationTitle`

```swift
// 현재 (L9-L12) — Text 직접 렌더링
VStack(spacing: 20) {
    Text("스도쿠")
        .font(.largeTitle.bold())
        .padding(.top)

// To-Be — VStack에서 Text 제거, modifier로 이동
VStack(spacing: 0) {
    // Text("스도쿠") 삭제
    ...
}
.navigationTitle("스도쿠")
.navigationBarTitleDisplayMode(.inline)
```

#### 변경 2: VStack spacing 재구성

```swift
// 현재 — spacing: 20 균등
VStack(spacing: 20) { ... }

// To-Be — spacing: 0 + 개별 Spacer
VStack(spacing: 0) {
    Spacer(minLength: 16)
    SudokuGridView(viewModel: viewModel)
        .padding(.horizontal, 16)
    Spacer(minLength: 20)
    GameControlsView(viewModel: viewModel)
    Spacer(minLength: 16)
    NumberPadView(viewModel: viewModel)
        .padding(.bottom, 24)
}
```

**변경 크기**: XSmall (약 10줄 변경)
**의존성**: 없음 (독립적으로 변경 가능)

---

## 3. REUSE — 변경 불필요

| 파일 | 재활용 이유 |
|------|------------|
| `GameViewModel.swift` | `selectCell`, `inputNumber`, `clearCell`, `undo`, `canUndo` 모두 변경 불필요. `isSameNumber` 계산은 SudokuGridView에서 처리 (cross-review 결정). |
| `Models/GameState.swift` | `selectedRow`, `selectedCol`, `isPencilMode`, `undoStack` 구조 변경 없음 |
| `Models/SudokuCell.swift` | `value`, `isFixed`, `notes`, `isConflict` 필드 변경 없음 |
| `Models/SudokuBoard.swift` | `detectingConflicts()` 로직 변경 없음 |
| `ContentView.swift` | NavigationStack 래핑 구조 변경 없음. GameView 진입점 유지. |
| `HomeView.swift` / `HomeViewModel.swift` | 범위 외 |
| `Services/` (PuzzleGenerator 등) | 범위 외 |

---

## 4. 구현 순서 (의존성 그래프)

```
Step 1: Color+Sudoku.swift (NEW)
        ↓ (의존: 없음)
        색상 상수 컴파일 오류 없이 사용 가능해짐

Step 2: SudokuCellView — 버그 수정
        .contentShape(Rectangle()) + Color.clear 제거
        (독립적, Step 1과 병렬 가능)
        ↓
        빈 셀 탭 즉시 검증 가능

Step 3: SudokuCellView — isSameNumber 파라미터 추가
        (Step 1 이후, Step 2와 통합 가능)
        ↓ 컴파일 오류 발생 (SudokuGridView #Preview 포함)

Step 4: SudokuGridView — isSameNumber 계산 함수 + 셀 전달 수정
        (Step 3 직후 — 컴파일 오류 해소 필수)

Step 5: SudokuCellView — 색상/폰트 To-Be 적용
        backgroundColor 우선순위, noteText 색상, 폰트 22pt
        (Step 1, 3, 4 완료 후)

Step 6: SudokuGridView — 경계선 색상 분리 + 외곽 border
        (Step 1 완료 후, Step 4와 통합 가능)

Step 7: NumberPadView — 스타일 업데이트
        (독립적, 어느 단계에서도 가능)

Step 8: GameControlsView — 스타일 업데이트
        (독립적, 어느 단계에서도 가능)

Step 9: GameView — navigationTitle + Spacer 재구성
        (독립적, 어느 단계에서도 가능)

Step 10: 접근성 레이블 추가
         SudokuCellView (accessibilityLabel, addTraits)
         NumberPadView (지우기, 숫자 버튼)
         (Step 5 이후 통합 권장)
```

---

## 5. 충돌 해결 결정사항 (cross-review 기반)

| 항목 | 결정 | 근거 |
|------|------|------|
| `isSameNumber` 계산 위치 | **SudokuGridView** (View 계산) | `isRelated` 동일 패턴, 코드 일관성 |
| `noteText` 색상 | **`#616161`** (Light) | WCAG AA 5.74:1 확실히 통과 |
| 선택 셀 내 사용자 숫자 대비 | **현 색상 유지** (`#1565C0` on `#BBDEFB`) | 22pt → WCAG AA Large 3:1 기준 충족 (3.8:1) |
| 접근성 레이블 스프린트 포함 | **포함** (XSmall 구현 크기) | SudokuCellView + NumberPadView 지우기 버튼 |
| `isSameNumber > isConflict` 우선순위 | **허용** | 충돌은 숫자 색상(빨강)으로 전달, 동일 숫자 컨텍스트 우선 |
| 고정 셀 동일 숫자 하이라이트 | **발동** | Sudoku.com 표준 동작, `selectCell` 이미 고정 셀 허용 |

---

## 6. 범위 외 (이번 스프린트 제외)

- HomeView 디자인 변경
- 타이머/일시정지 UI
- 힌트/자동 메모, 실수 횟수 표시
- `undoStack` 크기 제한 (메모리 안전성)
- 게임 완료 애니메이션
- NavigationBar trailing 난이도 표시
- Dynamic Type 완전 지원
- `UIAccessibility.post` announcement
