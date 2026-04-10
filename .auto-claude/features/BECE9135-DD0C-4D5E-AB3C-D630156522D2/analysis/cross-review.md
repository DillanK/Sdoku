# Cross-Review — 버그 수정 및 게임 화면 UI 개선

> **역할**: Coordinator
> **검토 대상**: ui-analysis.md, ux-analysis.md, feature-analysis.md
> **작성일**: 2026-04-10

---

## 1. 합의 사항 (충돌 없음)

세 Lead 모두 동일한 방향으로 합의된 항목들.

| 항목 | 합의 내용 |
|------|-----------|
| 버그 수정 방법 | `.contentShape(Rectangle())` + `Color.clear` → `Color(.systemBackground)` 두 가지 모두 적용 |
| `contentShape` 위치 | `SudokuCellView` ZStack에 `.aspectRatio` 바로 아래 추가 |
| 셀 배경 우선순위 | `isSelected > isSameNumber > isConflict > isRelated > default` |
| `isSameNumber` 미발동 조건 | `value == 0` 셀 선택 시 하이라이트 없음 |
| 고정 셀 동일 숫자 하이라이트 | 고정 셀 탭 시에도 `selectedValue` 계산 → 하이라이트 발동 |
| Undo 비활성화 | 이미 `disabled(!viewModel.canUndo)` 구현됨 → 추가 변경 불필요 |
| `.navigationTitle` 변경 | `Text("스도쿠")` largeTitle → `.navigationTitle("스도쿠")` `.inline` 으로 교체 |
| 숫자 패드 버튼 높이 | 52pt → 56pt |
| cornerRadius 통일 | 숫자 패드 버튼 + 컨트롤 버튼 모두 10pt → 12pt |
| 그림자 추가 | 숫자 패드 버튼, 컨트롤 버튼 비활성 상태 모두 `shadow(.black.opacity(0.08), radius:4, x:0, y:2)` |
| 고정 숫자 폰트 | 20pt → 22pt `.bold` |
| 사용자 숫자 폰트 | 20pt `.regular` → 22pt `.medium` |
| 메모 폰트 비율 | `cellSize * 0.5` → `cellSize * 0.38` |
| 컨트롤 레이블 폰트 | 15pt → 13pt |
| 컨트롤 아이콘 | 18pt → 20pt |
| 그리드 외곽 border | `RoundedRectangle(cornerRadius:4)`, lineWidth 2.5, `#424242` |
| CoreData 영향 없음 | 이번 변경은 게임 플레이 UI/Logic 한정, 데이터 영속성 무관 |

---

## 2. 충돌 및 해결

### 충돌 1: `isSameNumber` 계산 위치

**상충**
- UI Lead → `GameViewModel`에 `selectedValue: Int?` 추가하여 ViewModel 레이어에서 계산
- Feature Lead → `SudokuGridView` 내 `isSameNumber(row:col:)` 함수로 계산 (`isRelated`와 동일 패턴)

**트레이드오프**

| 방안 | 장점 | 단점 |
|------|------|------|
| ViewModel 계산 (UI Lead) | 테스트 용이, 비즈니스 로직 ViewModel 집중 | `selectedValue`가 실제론 View 파생 정보 — ViewModel 책임 범위 논쟁 가능 |
| View 계산 (Feature Lead) | `isRelated`와 동일 패턴 → 코드 일관성, ViewModel 책임 최소화 | View 로직 분산 |

**결정**: **Feature Lead 방안 채택 — SudokuGridView에서 계산**

**근거**: `isRelated`가 이미 동일한 계산 패턴으로 View에서 처리 중이며, 코드 일관성이 더 중요. `selectedValue`는 UI 파생 속성이므로 ViewModel에 추가 불필요. 단, 계산 로직은 `private func isSameNumber(row:col:)` 형태로 명확히 분리.

```swift
// SudokuGridView 내 추가 함수
private func isSameNumber(row: Int, col: Int) -> Bool {
    guard let selRow = viewModel.selectedRow,
          let selCol = viewModel.selectedCol else { return false }
    let selectedValue = viewModel.board.cells[selRow][selCol].value
    guard selectedValue != 0 else { return false }
    if row == selRow && col == selCol { return false }
    return viewModel.board.cells[row][col].value == selectedValue
}
```

---

### 충돌 2: `noteText` 색상

**상충**
- UI Lead → `#757575` 제안 (WCAG AA 4.5:1 borderline)
- UX Lead → `#616161` 이상 진한 회색 권장 (AA 명확히 통과)

**트레이드오프**: `#757575` on white = ~4.48:1로 AA를 간신히 통과하지만 borderline. 시스템 다크모드 반전 시 별도 처리 필요.

**결정**: **UX Lead 방안 채택 — `#616161` 적용**

**근거**: 사용성(UX) > 심미성(UI) 우선순위 원칙. 메모 숫자는 작은 크기(`cellSize * 0.38`)이므로 최소 대비 기준 충족이 필수. `#616161` on white = ~5.74:1로 AA 확실히 통과. 시각적 차이 미미.

| 항목 | 결정값 |
|------|--------|
| `noteText` Light Mode | `#616161` |
| `noteText` Dark Mode | `#9E9E9E` (UI Lead 원안 유지 — Dark에서는 충분한 대비) |

---

### 충돌 3: 선택 셀 내 사용자 숫자 색상 대비

**상충**
- UI Lead → `numberUser = #1565C0`, `cellSelected = #BBDEFB` 제안
- UX Lead → `#1565C0` on `#BBDEFB` 조합 대비 3.8:1 — WCAG AA Normal(4.5:1) **미달** 지적

**트레이드오프**

| 대안 | 대비 | 영향 |
|------|------|------|
| 선택 셀 내 사용자 숫자를 더 진하게 오버라이드 | 통과 가능 | SudokuCellView 분기 로직 복잡도 증가 |
| `cellSelected` 배경을 더 밝게 조정 | 통과 가능 | 선택 하이라이트 시각적 효과 약화 |
| AA Large 기준 적용 (3:1, 18pt+ 텍스트) | 22pt는 AA Large 해당 → 3.8:1 **통과** | 기술적 정당성 있음 |

**결정**: **AA Large 기준 적용으로 현재 UI Lead 색상 유지**

**근거**: 사용자 숫자는 22pt bold/medium으로 WCAG 기준 "Large Text"(18pt+ 일반, 14pt+ bold) 에 해당. AA Large 기준 3:1 충족(3.8:1). 이 예외를 코드 주석으로 명시하여 추후 대비 검토 시 참고 가능하게 유지.

> `// WCAG AA Large (3:1) 기준 적용 — 22pt regular/medium 텍스트 해당`

---

### 충돌 4: 접근성 레이블 (accessibilityLabel) 스프린트 포함 여부

**상충**
- UX Lead → "권장 최소 구현"으로 이번 스프린트에 포함, 구체적 코드 제시
- Feature Lead → "범위 외"로 제외

**트레이드오프**: 구현 크기 XSmall(~15줄), VoiceOver 사용자 기본 사용성 보장 vs 스프린트 집중도.

**결정**: **UX Lead 방안 채택 — 이번 스프린트에 포함 (SudokuCellView + NumberPad 지우기 버튼 한정)**

**근거**: 사용성(UX) > 완전성(Feature) 원칙. 구현 크기가 매우 작고(XSmall), 추후 별도 스프린트로 처리하면 현재 코드를 다시 열어야 하는 비용 발생. 단, UX Lead가 제안한 "선택 상태 announcement" (`UIAccessibility.post`)는 선택적 적용.

**포함 범위**:
- `SudokuCellView` — `accessibilityLabel` (고정/사용자 숫자, 메모, 빈 셀 구분)
- `SudokuCellView` — `accessibilityAddTraits(.isSelected)` 선택 상태
- `NumberPadView` 지우기 버튼 — `.accessibilityLabel("지우기")`
- `NumberPadView` 숫자 버튼 — `.accessibilityLabel("\(number)")` (기본 동작이지만 명시적 추가)
- **제외**: `UIAccessibility.post` announcement (선택 사항, 이번 범위 외)

---

## 3. 미결 사항 확인

Feature Lead가 UX Lead에게 확인 요청한 트레이드오프 — **Coordinator 결정**:

### Q1: `isSameNumber > isConflict` 우선순위 — 초록 배경 + 빨간 숫자 조합 허용 여부

**결정**: **허용**

**근거**: 충돌 정보는 숫자 색상(빨간색)으로 충분히 전달됨. 동일 숫자 하이라이트가 더 넓은 컨텍스트(퍼즐 전체 현황 파악)를 제공하므로 우선 표시가 타당. 스도쿠 숙련 사용자는 빨간 숫자로 충돌을 인식함.

### Q2: 고정 셀 탭 → 동일 숫자 하이라이트 발동 — 의도한 UX 여부

**결정**: **의도한 UX로 확정**

**근거**: Sudoku.com 등 주요 앱에서도 고정 셀 탭 시 동일 숫자 하이라이트 발동. 사용자가 보드 내 특정 숫자의 분포를 확인하는 자연스러운 탐색 동작. `selectCell`이 이미 고정 셀 선택 허용 → 추가 변경 불필요.

---

## 4. 최종 코드 매핑

| 파일 | 분류 | 변경 내용 | 크기 |
|------|------|-----------|------|
| `SudokuCellView.swift` | **MODIFY** | `.contentShape(Rectangle())`, `Color.clear` → `systemBackground`, `isSameNumber` 파라미터, `backgroundColor` 우선순위 재작성, 폰트 22pt, 접근성 레이블 | Small |
| `SudokuGridView.swift` | **MODIFY** | `isSameNumber(row:col:)` 함수 추가, 셀 생성부 수정, 경계선 Light/Dark 색상 분리(`@Environment(\.colorScheme)`), 외곽 border 추가 | Small |
| `NumberPadView.swift` | **MODIFY** | 높이 56pt, 폰트 26pt, cornerRadius 12pt, shadow, spacing 10pt, `systemBackground`, 접근성 레이블 | Small |
| `GameControlsView.swift` | **MODIFY** | cornerRadius 12pt, 레이블 폰트 13pt, 아이콘 20pt, 비활성 버튼 shadow | XSmall |
| `GameView.swift` | **MODIFY** | `.navigationTitle(.inline)`, VStack spacing 0 + 개별 Spacer | XSmall |
| `Color+Sudoku.swift` | **NEW** | `cellSelected`, `cellRelated`, `cellSameNumber`, `cellConflict` 시맨틱 색상 (Light/Dark 분기), `noteText`, 경계선 색상 | XSmall |

> **Color+Sudoku.swift 분리 근거**: `SudokuGridView`(경계선 색상)와 `SudokuCellView`(셀 배경 색상) 모두 참조 → shared extension 필수.

---

## 5. 구현 순서 권장

1. **`Color+Sudoku.swift` 신규 생성** — 모든 색상 상수 정의. 컴파일 오류 없는 베이스라인 확보.
2. **`SudokuCellView.swift` 버그 수정** — `.contentShape(Rectangle())` + `Color.clear` 제거. 빈 셀 탭 즉시 검증 가능.
3. **`SudokuCellView.swift` `isSameNumber` 파라미터 추가** — 인터페이스 변경 → `SudokuGridView` Preview 포함 컴파일 오류 동반 수정.
4. **`SudokuGridView.swift` `isSameNumber` 계산 + 색상 업데이트** — 경계선 색상 분리, 외곽 border, 셀 전달.
5. **`SudokuCellView.swift` 색상 시스템 + 폰트 업데이트** — To-Be 디자인 시스템 적용.
6. **`NumberPadView.swift` 스타일 업데이트** — 높이, 그림자, spacing.
7. **`GameControlsView.swift` 스타일 업데이트** — cornerRadius, 폰트, 아이콘.
8. **`GameView.swift` 레이아웃 변경** — navigationTitle, Spacer 재구성.
9. **접근성 레이블 추가** — `SudokuCellView`, `NumberPadView` 지우기 버튼.

---

## 6. 범위 외 (전체 Lead 합의)

- HomeView 디자인 변경
- 타이머/일시정지 UI
- 힌트/자동 메모, 실수 횟수 표시
- `undoStack` 크기 제한
- 게임 완료 애니메이션
- `NavigationBar trailing` 난이도 표시
- Dynamic Type 완전 지원
- `UIAccessibility.post` announcement
