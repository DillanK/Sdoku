# 가이드라인 업데이트 제안

> Feature: 버그 수정 및 UI 변경
> 완료일: 2026-04-10T07:50:52Z
> 이 파일은 자동 생성되었습니다. 내용을 검토한 후 ui-guidelines.md 또는 design-tokens.md에 반영하세요.
> 반영 후 이 파일을 삭제하세요.

## UI 분석에서 발견된 패턴

# UI Analysis — 버그 수정 및 게임 화면 UI 개선

> **분석 기준**: 참고 이미지(`aa.jpg`) 미첨부 → Spark 대화에서 합의된 **Sudoku.com 스타일** 기준 분석
> **분석 범위**: 게임 플레이 화면 (GameView, SudokuGridView, SudokuCellView, NumberPadView, GameControlsView)
> **플랫폼**: iOS 17+, SwiftUI, HIG 준수, Dark/Light 모드 고려

---

## 1. 현재 UI 상태 역공학 (As-Is)

### 1.1 GameView 레이아웃 계층

```
NavigationStack (ContentView)
└─ GameView
   └─ VStack(spacing: 20)
      ├─ Text("스도쿠")               // .largeTitle.bold(), .padding(.top)
      ├─ SudokuGridView               // .padding(.horizontal)
      ├─ GameControlsView
      └─ NumberPadView               // .padding(.bottom)
```

- Safe Area: 별도 처리 없음 (SwiftUI 기본 insets 활용)
- 배경: 시스템 기본 (`.systemBackground`)
- Navigation bar: 미사용 (`.navigationTitle` 없음)

### 1.2 SudokuCellView 컴포넌트 스펙 (현재)

| 속성 | 값 |
|------|-----|
| 레이아웃 | `ZStack`, `aspectRatio(1, .fit)` |
| 선택 배경 | `Color.blue.opacity(0.35)` |
| 연관 배경 (행/열/박스) | `Color.blue.opacity(0.10)` |
| 충돌 배경 | `Color.red.opacity(0.15)` |
| 기본 배경 | `Color.clear` ← **버그 원인** |
| 고정 숫자 폰트 | `system(size: 20, weight: .bold)`, color: `.primary` |
| 사용자 숫자 폰트 | `system(size: 20, weight: .regular)`, color: `.blue` |
| 충돌 숫자 색상 | `.red` |
| 메모 숫자 폰트 | `cellSize * 0.5` (GeometryReader 기준) |
| 메모 색상 | `.gray` |
| 메모 padding | `2pt` |
| contentShape | **없음** ← **버그** |

### 1.3 SudokuGridView 스펙 (현재)

| 속성 | 값 |
|------|-----|
| 크기 | `GeometryReader`, `min(width, height)` 정방형 |
| 셀 크기 | `gridSize / 9` |
| 얇은 경계선 | `lineWidth: 0.5`, `primary.opacity(0.8)` |
| 굵은 경계선 (3x3) | `lineWidth: 2.5`, `primary.opacity(0.8)` |
| GridLinesView | `allowsHitTesting(false)` ✅ |

### 1.4 NumberPadView 스펙 (현재)

| 속성 | 값 |
|------|-----|
| 레이아웃 | `LazyVGrid`, 3열, `spacing: 8` |
| 버튼 높이 | `52pt` |
| 숫자 폰트 | `system(size: 24, weight: .semibold)` |
| 지우기 아이콘 | `"delete.left"`, size `22` |
| 배경 | `Color(.secondarySystemBackground)` |
| cornerRadius | `10pt` |
| padding | `.horizontal` (시스템 기본 16pt) |
| 비활성 opacity | `0.4` |

### 1.5 GameControlsView 스펙 (현재)

| 속성 | 값 |
|------|-----|
| 레이아웃 | `HStack(spacing: 24)` |
| 버튼 padding | `H: 16pt`, `V: 10pt` |
| cornerRadius | `10pt` |
| 메모 활성 배경 | `accentColor.opacity(0.15)` |
| 메모 활성 테두리 | `accentColor`, `lineWidth: 1.5` |
| 메모 비활성 배경 | `Color(.secondarySystemBackground)` |
| 아이콘 크기 | `18pt` |
| 텍스트 | `system(size: 15, weight: .medium)` |

---

## 2. 버그 분석

### Bug: 빈 셀 선택 불가

**증상**: 숫자가 없고 메모도 없는 셀(value=0, notes 비어있음)을 탭해도 선택이 안 됨
**재현 조건**: 앱 처음 실행 직후 (아무 셀도 선택 안 된 상태)

**원인**:
```swift
// SudokuCellView.swift:30-40
private var backgroundColor: Color {
    if isSelected { return Color.blue.opacity(0.35) }
    else if cell.isConflict { return Color.red.opacity(0.15) }
    else if isRelated { return Color.blue.opacity(0.10) }
    else { return Color.clear }  // ← 빈 셀의 경우 Color.clear 반환
}
```

`Color.clear`는 SwiftUI hit-testing에서 투명 영역으로 처리 → 탭 이벤트 전달 안 됨
ZStack 내 콘텐츠도 없으므로(value=0, notes 비어있음) 터치 가능 영역 자체가 없음

**수정 방법**:
```swift
// SudokuCellView.swift — ZStack에 contentShape 추가
ZStack { ... }
    .aspectRatio(1, contentMode: .fit)
    .contentShape(Rectangle())  // ← 이 한 줄 추가
```

---

## 3. To-Be UI 스펙 (Sudoku.com 스타일)

### 3.1 디자인 시스템

#### 색상 팔레트 (시맨틱 명칭 병기)

| 시맨틱 명 | Light Mode | Dark Mode | 용도 |
|-----------|-----------|-----------|------|
| `cellBackground` | `#FFFFFF` | `#1C1C1E` | 셀 기본 배경 |
| `cellSelected` | `#BBDEFB` | `#1A3A5C` | 선택된 셀 배경 |
| `cellRelated` | `#E3F2FD` | `#152840` | 같은 행/열/박스 셀 배경 |
| `cellSameNumber` | `#C8E6C9` (연두) | `#1A3D1A` | 동일 숫자 셀 배경 (신규) |
| `cellConflict` | `#FFCDD2` | `#3D1A1A` | 충돌 셀 배경 |
| `numberFixed` | `#263238` | `#E0E0E0` | 고정 숫자 (진한 회색/거의 검정) |
| `numberUser` | `#1565C0` | `#64B5F6` | 사용자 입력 숫자 |
| `numberConflict` | `#D32F2F` | `#EF9A9A` | 충돌 숫자 |
| `noteText` | `#757575` | `#9E9E9E` | 메모 숫자 |
| `gridLineThin` | `#BDBDBD` | `#424242` | 셀 경계선 |
| `gridLineBold` | `#424242` | `#9E9E9E` | 3x3 박스 경계선 |
| `padButtonBackground` | `#FFFFFF` | `#2C2C2E` | 숫자 패드 버튼 배경 |
| `padButtonText` | `#263238` | `#E0E0E0` | 숫자 패드 텍스트 |
| `controlActive` | `#1565C0` (tint 15%) | `#64B5F6` (tint 15%) | 컨트롤 버튼 활성 상태 |

> SwiftUI 시맨틱 매핑:
> - `cellBackground` → `Color(.systemBackground)`
> - `numberFixed` → `Color(.label)`
> - `numberUser` → `Color.blue` (또는 `Color(.systemBlue)`)
> - `padButtonBackground` → `Color(.systemBackground)` with shadow
> - `cellSelected`, `cellRelated`, `cellSameNumber`, `cellConflict` → 신규 Color extension 정의 권장

#### 타이포그래피

| 용도 | 폰트 | 사이즈 | Weight |
|------|------|--------|--------|
| 화면 타이틀 | SF Pro | 17pt | `.semibold` (NavigationTitle 스타일) |
| 고정 숫자 | SF Pro | 22pt | `.bold` |
| 사용자 숫자 | SF Pro | 22pt | `.medium` |
| 메모 숫자 | SF Pro | `cellSize * 0.38` | `.regular` |
| 숫자 패드 | SF Pro | 26pt | `.semibold` |
| 컨트롤 버튼 레이블 | SF Pro | 13pt | `.medium` |

> 현재 고정 숫자 20pt → **22pt**로 상향 (가독성 개선)
> 컨트롤 레이블 현재 15pt → **13pt**로 하향 (버튼 컴팩트화)

#### 간격 시스템

| 토큰 | 값 | 용도 |
|------|----|------|
| `spacing-xs` | 4pt | 메모 내부 padding |
| `spacing-sm` | 8pt | 숫자 패드 열 간격 |
| `spacing-md` | 16pt | 수평 padding, 버튼 내부 H padding |
| `spacing-lg` | 20pt | VStack 주요 간격 |
| `spacing-xl` | 24pt | 컨트롤 버튼 간격 |
| `spacing-2xl` | 32pt | 섹션 상단 여백 |

#### cornerRadius

| 컴포넌트 | 현재 | To-Be |
|----------|------|-------|
| 숫자 패드 버튼 | 10pt | **12pt** |
| 컨트롤 버튼 | 10pt | **12pt** |
| 그리드 외곽 | 없음 | **4pt** (전체 그리드 외곽 border radius) |

#### 그림자 (숫자 패드 버튼)

```
shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
```

> 현재 `secondarySystemBackground`로 구분 → 흰 배경 + 미세 그림자로 변경 (Sudoku.com 스타일)

---

### 3.2 화면 레이아웃 (To-Be)

```
NavigationStack
└─ GameView
   └─ VStack(spacing: 0)
      ├─ [NavigationBar 영역]
      │   └─ .navigationTitle("스도쿠") (.inline)
      │       + trailing: 난이도 표시 Text (caption, secondary)
      ├─ Spacer(minLength: 16)
      ├─ SudokuGridView                // .padding(.horizontal, 16), aspectRatio(1)
      ├─ Spacer(minLength: 20)
      ├─ GameControlsView              // HStack, centered
      ├─ Spacer(minLength: 16)
      └─ NumberPadView                 // .padding(.horizontal, 16), .padding(.bottom, 24)
```

**변경 포인트**:
- `Text("스도쿠")` 직접 렌더링 → `.navigationTitle("스도쿠")` 변경 (iOS HIG 준수)
- VStack `spacing: 20` → `spacing: 0` + 개별 Spacer로 fine-grained 제어

---

### 3.3 SudokuCellView To-Be 스펙

#### 색상 변경

| 상태 | 현재 | To-Be |
|------|------|-------|
| 선택 | `blue.opacity(0.35)` | `#BBDEFB` (Light) / `#1A3A5C` (Dark) |
| 연관 | `blue.opacity(0.10)` | `#E3F2FD` (Light) / `#152840` (Dark) |
| 동일 숫자 | 없음 | `#C8E6C9` (Light) / `#1A3D1A` (Dark) — **신규** |
| 충돌 | `red.opacity(0.15)` | `#FFCDD2` (Light) / `#3D1A1A` (Dark) |
| 기본 | `Color.clear` | `Color(.systemBackground)` |

> `Color.clear` → `Color(.systemBackground)` 변경은 hit-testing 수정과 동일 효과를 가지나,
> `.contentShape(Rectangle())` 추가가 더 정확한 버그 수정. 두 가지 모두 적용 권장.

#### 우선순위 규칙 (동시 상태)

```
isSelected > isSameNumber > isConflict > isRelated > default
```

> 동일 숫자 강조는 충돌보다 낮은 우선순위 (충돌이 더 중요 정보)

#### 숫자 폰트 변경

```swift
// 현재
.font(.system(size: 20, weight: cell.isFixed ? .bold : .regular))

// To-Be
.font(.system(size: 22, weight: cell.isFixed ? .bold : .medium))
```

#### contentShape 추가 (버그 수정)

```swift
ZStack { ... }
    .aspectRatio(1, contentMode: .fit)
    .contentShape(Rectangle())  // ← 신규
```

---

### 3.4 SudokuGridView To-Be 스펙

#### 경계선 색상

| 선 종류 | 현재 | To-Be Light | To-Be Dark |
|---------|------|------------|------------|
| 얇은 셀 경계 | `primary.opacity(0.8)`, 0.5pt | `#BDBDBD`, 0.5pt | `#424242`, 0.5pt |
| 굵은 3x3 경계 | `primary.opacity(0.8)`, 2.5pt | `#424242`, 2.5pt | `#9E9E9E`, 2.5pt |

> 현재 Light/Dark 동일 색상 사용 → 분리 필요 (Light에서 굵은선이 너무 진하게 보임)

#### 외곽 border

```swift
// GridView 전체 외곽에 추가
.overlay(
    RoundedRectangle(cornerRadius: 4)
        .stroke(Color(hex: "#424242"), lineWidth: 2.5)
)
```

---

### 3.5 NumberPadView To-Be 스펙

| 속성 | 현재 | To-Be |
|------|------|-------|
| 버튼 높이 | 52pt | **56pt** |
| 숫자 폰트 | system(24, .semibold) | system(26, .semibold) |
| 배경 | `secondarySystemBackground` | `systemBackground` + shadow |
| cornerRadius | 10pt | **12pt** |
| 그림자 | 없음 | `shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)` |
| 열 간격 | 8pt | **10pt** |
| 행 간격 | 8pt | **10pt** |
| 지우기 아이콘 | "delete.left", size 22 | "delete.left", size **22** (유지) |

---

### 3.6 GameControlsView To-Be 스펙

| 속성 | 현재 | To-Be |
|------|------|-------|
| 버튼 padding V | 10pt | **12pt** |
| 버튼 cornerRadius | 10pt | **12pt** |
| 컨트롤 레이블 폰트 | system(15, .medium) | system(13, .medium) |
| 아이콘 크기 | 18pt | **20pt** |
| 버튼 간격 | 24pt | **24pt** (유지) |
| 메모 비활성 배경 | `secondarySystemBackground` | `systemBackground` + shadow (패드 버튼과 통일) |

---

## 4. 신규 기능: 동일 숫자 하이라이트

### 동작 정의
- 선택된 셀의 `value != 0`일 때, 같은 숫자를 가진 모든 셀의 배경을 `cellSameNumber` 색상으로 표시
- `isSelected` 상태의 셀은 제외 (선택 색상 우선)
- `value == 0` 셀 선택 시: 동일 숫자 하이라이트 없음

### GameViewModel 추가 프로퍼티
```swift
// GameViewModel에 추가
var selectedValue: Int? {
    guard let row = state.selectedRow,
          let col = state.selectedCol else { return nil }
    let v = state.board.cells[row][col].value
    return v != 0 ? v : nil
}
```

### SudokuCellView 인터페이스 변경
```swift
// 현재
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
    let isSameNumber: Bool  // ← 신규
}
```

---

## 5. 코드 매핑 (REUSE / MODIFY / NEW)

| 파일 | 분류 | 변경 내용 |
|------|------|-----------|
| `SudokuCellView.swift` | **MODIFY** | `.contentShape(Rectangle())` 추가 (버그), `isSameNumber` 파라미터 추가, 색상 시스템 업데이트, 폰트 size 22 |
| `SudokuGridView.swift` | **MODIFY** | `isSameNumber` 전달 로직 추가, 경계선 색상 분리, 외곽 border 추가 |
| `NumberPadView.swift` | **MODIFY** | 버튼 높이 56, 폰트 26, cornerRadius 12, shadow 추가, spacing 10 |
| `GameControlsView.swift` | **MODIFY** | cornerRadius 12, 레이블 폰트 13, 아이콘 20, 비활성 버튼 shadow |
| `GameView.swift` | **MODIFY** | `.navigationTitle` 변경, 레이아웃 Spacer 재구성 |
| `GameViewModel.swift` | **MODIFY** | `selectedValue: Int?` 프로퍼티 추가 |
| Color extension | **NEW** | `cellSelected`, `cellRelated`, `cellSameNumber`, `cellConflict` 시맨틱 색상 정의 |

---

## 6. 다른 Lead에게 전달할 UI 주의사항

### UX Lead에게
- **동일 숫자 하이라이트 우선순위**: `isSelected > isSameNumber > isConflict > isRelated` 순서로 구현 요청 필요
- **선택 해제 동작**: 빈 셀 탭 후 다시 탭하면 선택 해제 → 기존 `selectCell` 토글 로직 유지 (변경 불필요)
- **고정 셀 선택**: 고정 셀도 선택은 가능하되 NumberPad가 비활성화됨 → 동일 숫자 하이라이트는 고정 셀 선택 시에도 작동해야 함

### Feature Lead에게
- `Color.clear` → `Color(.systemBackground)` 변경 시 다크모드에서 그리드 내부가 시스템 배경과 동일해야 함 — Dark Mode에서 `#1C1C1E` 확인 필요
- `isSameNumber` 계산은 `GameViewModel`에서 수행, `SudokuGridView`에서 전달하는 구조 권장 (View 로직 최소화)
- 신규 Color extension은 `Color+Sudoku.swift` 파일로 분리 권장 (하지만 현재 프로젝트 규모상 `SudokuCellView.swift` 내 private extension도 허용)
- `NoteGridView`의 `cellSize * 0.5` → `cellSize * 0.38`로 변경 시 빈 공간 확보 → 메모가 있는 셀의 가독성 향상

---

## 7. 범위 외 (이번 스프린트 제외)

- HomeView 디자인 변경
- 타이머/일시정지 UI
- 힌트/자동 메모
- 실수 횟수 표시
- NavigationBar trailing 난이도 표시 (선택사항 — 구현 시간 여유 있을 때)
