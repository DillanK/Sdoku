# Analysis Summary — 버그 수정 및 UI 변경

> **작성일**: 2026-04-10
> **기반 문서**: ui-analysis.md, ux-analysis.md, feature-analysis.md, cross-review.md, code-mapping.md
> **플랫폼**: iOS 17+, SwiftUI

---

## 1. 핵심 구현 포인트 (우선순위 순)

### P0 — 버그 수정 (블로커)
| # | 구현 포인트 | 파일 | 변경 규모 |
|---|------------|------|-----------|
| 1 | `SudokuCellView` ZStack에 `.contentShape(Rectangle())` 추가 — 빈 셀 hit-testing 보장 | `SudokuCellView.swift` | 1줄 |
| 2 | `backgroundColor` 기본값 `Color.clear` → `Color(.systemBackground)` 변경 — 버그 보완 + 배경색 통일 | `SudokuCellView.swift` | 1줄 |

> **버그 근본 원인**: 빈 셀(value=0, notes=[])의 ZStack 배경이 `Color.clear`로 렌더링 픽셀 없음 → SwiftUI hit-testing 무시 → `onTapGesture` 발동 안 됨. 단, `isRelated=true`인 셀은 배경색이 있어 탭이 되므로 "다른 셀 선택 후에는 됨"의 근거.

---

### P1 — 신규 기능 (동일 숫자 하이라이트)
| # | 구현 포인트 | 파일 | 변경 규모 |
|---|------------|------|-----------|
| 3 | `Color+Sudoku.swift` 신규 생성 — 시맨틱 색상 상수 정의 (Light/Dark 분기) | `Color+Sudoku.swift` (NEW) | XSmall |
| 4 | `SudokuCellView`에 `isSameNumber: Bool` 파라미터 추가 + `backgroundColor` 우선순위 재작성 | `SudokuCellView.swift` | Small |
| 5 | `SudokuGridView`에 `isSameNumber(row:col:)` 계산 함수 추가 + 셀 전달 | `SudokuGridView.swift` | Small |

**배경색 우선순위**: `isSelected > isSameNumber > isConflict > isRelated > default`

---

### P2 — UI 디자인 개선 (Sudoku.com 스타일)
| # | 구현 포인트 | 파일 | 변경 규모 |
|---|------------|------|-----------|
| 6 | 셀 폰트 20pt → 22pt, weight `.regular` → `.medium` / `.bold` 유지 | `SudokuCellView.swift` | 1줄 |
| 7 | 메모 폰트 비율 `cellSize * 0.5` → `cellSize * 0.38`, 메모 색상 `noteText(#616161)` | `SudokuCellView.swift` | 2줄 |
| 8 | 그리드 경계선 Light/Dark 색상 분리 + 외곽 `RoundedRectangle(cornerRadius:4)` border 추가 | `SudokuGridView.swift` | Small |
| 9 | 숫자 패드 버튼: 높이 52→56pt, 폰트 24→26pt, cornerRadius 10→12pt, shadow 추가, spacing 8→10pt, `secondarySystemBackground` → `systemBackground` | `NumberPadView.swift` | Small |
| 10 | 컨트롤 버튼: cornerRadius 10→12pt, 레이블 폰트 15→13pt, 아이콘 18→20pt, V padding 10→12pt, shadow 추가 | `GameControlsView.swift` | XSmall |
| 11 | `Text("스도쿠")` `.largeTitle` 제거 → `.navigationTitle("스도쿠") .inline` 변경, VStack `spacing:20` → `spacing:0` + 개별 Spacer | `GameView.swift` | XSmall |

---

### P3 — 접근성 (이번 스프린트 포함 — XSmall)
| # | 구현 포인트 | 파일 | 변경 규모 |
|---|------------|------|-----------|
| 12 | `SudokuCellView` — `accessibilityLabel` (고정/사용자 숫자, 메모, 빈 셀 구분) + `accessibilityAddTraits(.isSelected)` | `SudokuCellView.swift` | XSmall |
| 13 | `NumberPadView` 지우기 버튼 `.accessibilityLabel("지우기")` + 숫자 버튼 `.accessibilityLabel("\(number)")` | `NumberPadView.swift` | XSmall |

---

## 2. 재활용 vs 신규 비율

| 분류 | 파일 수 | 파일 목록 |
|------|---------|-----------|
| **REUSE** (변경 없음) | 6 | `GameViewModel.swift`, `GameState.swift`, `SudokuCell.swift`, `SudokuBoard.swift`, `ContentView.swift`, `HomeView.swift` |
| **MODIFY** (기존 파일 수정) | 5 | `SudokuCellView.swift`, `SudokuGridView.swift`, `NumberPadView.swift`, `GameControlsView.swift`, `GameView.swift` |
| **NEW** (신규 파일 생성) | 1 | `Color+Sudoku.swift` |

**비율**: REUSE 50% / MODIFY 42% / NEW 8%

> `GameViewModel.swift`는 완전 재활용 — `isSameNumber` 계산을 View 레이어(`SudokuGridView`)에 위임하므로 변경 불필요.

---

## 3. 구현 복잡도 평가

| 항목 | 복잡도 | 근거 |
|------|--------|------|
| 버그 수정 (P0) | **Low** | 1-2줄 변경. 원인 명확, 수정 방법 단순. |
| 동일 숫자 하이라이트 (P1) | **Low-Medium** | 파라미터 추가 → 컴파일 오류 연쇄. `isSameNumber` 함수 자체는 단순하나 `SudokuCellView` 인터페이스 변경이 `SudokuGridView` #Preview까지 전파됨. |
| Color 시스템 구축 (P2 전제) | **Low** | hex 초기화 헬퍼 + Light/Dark 분기 static 상수 정의. 패턴 명확. |
| UI 스타일 변경 (P2) | **Low** | 수치 변경 위주. 레이아웃 재구성(`GameView`) 포함되나 Spacer 조정 수준. |
| 접근성 레이블 (P3) | **Low** | 약 15줄 추가. 복잡한 로직 없음. |
| **전체 종합** | **Low-Medium** | 기능 규모 작음. 단, 색상 시스템 신규 도입 + 인터페이스 변경 연쇄가 순서 오류 시 컴파일 오류 유발. |

---

## 4. 권장 구현 순서

```
Step 1: Color+Sudoku.swift 신규 생성 (의존성 없음, 전제조건)
        → hex 초기화 헬퍼, 셀 배경 4종, noteText, 경계선 2종

Step 2: SudokuCellView — 버그 수정 (Step 1과 병렬 가능)
        → .contentShape(Rectangle()) 추가
        → Color.clear → Color(.systemBackground)

Step 3: SudokuCellView — isSameNumber 파라미터 추가
        → 인터페이스 변경 → 컴파일 오류 발생 (Step 4 즉시 필요)

Step 4: SudokuGridView — isSameNumber 계산 함수 + 셀 전달 수정 [Step 3 직후]
        → 컴파일 오류 해소
        → @Environment(\.colorScheme) 추가

Step 5: SudokuCellView — 색상/폰트 To-Be 전면 적용
        → backgroundColor 우선순위 재작성 (.cellSelected/.cellSameNumber/.cellConflict/.cellRelated)
        → 폰트 22pt, noteText 색상, 메모 비율 0.38

Step 6: SudokuGridView — 경계선 색상 분리 + 외곽 border [Step 4와 통합 가능]

Step 7: NumberPadView 스타일 업데이트 (독립적)
Step 8: GameControlsView 스타일 업데이트 (독립적)
Step 9: GameView 레이아웃 변경 (독립적)

Step 10: 접근성 레이블 추가 [Step 5 이후]
         → SudokuCellView accessibilityLabel + addTraits
         → NumberPadView 지우기/숫자 버튼
```

---

## 5. 미해결 우려사항 (각 Lead 양보 사항)

### 5-1. isSameNumber vs isConflict 동시 발생 시 표현 [Feature Lead 양보]
- **상황**: 동일 숫자이면서 충돌 상태인 셀 → `isSameNumber > isConflict` 우선순위로 **초록 배경 + 빨간 숫자** 조합
- **우려**: 배경색으로 충돌이 표현되지 않아 빨간 숫자만으로 충돌 인지 필요
- **Coordinator 결정**: 허용 — 숙련 사용자는 빨간 숫자로 충돌 인식
- **구현 시 보완**: 이 조합이 실제 플레이에서 자주 발생하는지 테스트. 문제 보고 시 우선순위 재검토(`isConflict > isSameNumber` 역전) 고려.

### 5-2. 접근성 레이블 범위 축소 [UX Lead 양보]
- **상황**: UX Lead가 제안한 `UIAccessibility.post(notification: .announcement, ...)` (셀 선택 시 "행 n열 n 선택" 음성 안내)를 이번 스프린트에서 제외
- **우려**: VoiceOver 사용자의 셀 선택 피드백 미흡
- **구현 시 보완**: SudokuCellView의 `accessibilityLabel` + `addTraits(.isSelected)` 최소 구현 완료 후, 여유 시 announcement 추가 권장.

### 5-3. isSameNumber 계산 위치 [UI Lead 양보]
- **상황**: UI Lead가 `GameViewModel.selectedValue: Int?` 프로퍼티 추가 방안 제안 → Feature Lead 방안(SudokuGridView 내 계산)으로 채택
- **우려**: 향후 테스트 코드 작성 시 View 레이어 로직 테스트 불편
- **구현 시 보완**: `isSameNumber` 로직이 복잡해지거나 재사용 필요 시 `GameViewModel.selectedValue` 추가로 마이그레이션. 현재 `isRelated` 동일 패턴으로 일관성 확보됨.

### 5-4. 선택 셀 사용자 숫자 색상 대비 [UX Lead 양보]
- **상황**: `#1565C0` on `#BBDEFB` = 3.8:1로 WCAG AA Normal(4.5:1) 미달 → AA Large 기준(3:1) 적용으로 현 색상 유지
- **우려**: 시각 약자 사용자에게 선택 셀 내 사용자 숫자 가독성 저하 가능
- **구현 시 보완**: 코드 내 `// WCAG AA Large (3:1) 기준 적용 — 22pt 텍스트` 주석 필수 기재. 추후 접근성 감사 시 검토 대상으로 표시.

### 5-5. undoStack 크기 제한 없음 [Feature Lead 미결]
- **상황**: 이번 스프린트 범위 외로 제외. 장시간 플레이 시 메모리 누적 가능성.
- **구현 시 보완**: 별도 이슈로 트래킹 권장 (예: 최대 100개 제한 + FIFO).

---

## 6. 범위 외 (전체 Lead 합의)

- HomeView 디자인 변경
- 타이머/일시정지 UI
- 힌트/자동 메모, 실수 횟수 표시
- `undoStack` 크기 제한
- 게임 완료 애니메이션
- NavigationBar trailing 난이도 표시
- Dynamic Type 완전 지원
- `UIAccessibility.post` announcement
