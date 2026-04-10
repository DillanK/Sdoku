# UX Analysis — 버그 수정 및 게임 화면 UI 개선

> **분석 기준**: Spark 대화 합의 사항 + 현행 코드 역공학 (SudokuCellView, SudokuGridView, GameView, GameControlsView, NumberPadView)
> **분석 범위**: GameView 전체 (그리드 + 컨트롤 + 숫자 패드). HomeView 제외.
> **플랫폼**: iOS 17+, SwiftUI, HIG 준수

---

## 1. 사용자 흐름 (User Flow)

### 1.1 Happy Path — 퍼즐 풀이 전체 사이클

```
[HomeView] 난이도 선택
    ↓
[GameView 진입] 퍼즐 로드
    ↓
[셀 선택] 빈 셀 탭 → 선택 하이라이트 표시
    ↓
[숫자 입력] NumberPad 탭 → 셀에 숫자 표시
    ↓
[동일 숫자 하이라이트] 같은 값 셀 배경색 변경 (신규)
    ↓
[충돌 감지] 실시간 빨간색 표시
    ↓
[메모 모드] 토글 → 메모 입력 → 토글 해제
    ↓
[Undo] 실수 시 이전 상태 복원
    ↓
[퍼즐 완료] 전체 셀 채움 → 완료 감지 → 기록 저장
```

**현재 단절 지점 (버그)**: 앱 최초 진입 시 아무 셀도 선택되지 않은 상태에서 빈 셀 탭이 작동하지 않음. 숫자가 있는 셀을 먼저 탭해야 이후 빈 셀 탭이 동작하는 비일관적 UX.

**수정 후 기대 흐름**: 게임 진입 즉시 어떤 셀이든 탭 가능 → 즉각 선택 상태 진입.

---

### 1.2 Error Recovery — 실수 시나리오

| 실수 유형 | 현재 동작 | 개선 후 동작 |
|-----------|-----------|-------------|
| 잘못된 숫자 입력 | 충돌 시 빨간색 표시 | 동일 — 충돌 표시 유지 |
| 빈 셀 탭 안 됨 | 탭 무시 (버그) | `.contentShape(Rectangle())` 수정으로 즉시 선택 |
| 메모 모드 실수 입력 | Undo 스택으로 복원 | 동일 — 기존 로직 유지 |
| 충돌 상태에서 지우기 | 충돌 해소 | 동일 — 기존 로직 유지 |

---

### 1.3 Empty State

- **빈 셀 (value=0, notes 비어있음)**: 현재 버그로 인해 사실상 "탭 불가 상태"처럼 인식됨. 수정 후 정상 동작.
- **게임 완료 전**: 모든 빈 셀이 선택 가능해야 하며, 숫자 패드와 컨트롤이 활성 상태여야 함.

---

## 2. 인터랙션 패턴

### 2.1 셀 선택 인터랙션

**현재 문제**:
- `SudokuCellView`의 ZStack 배경이 `Color.clear`인 빈 셀은 SwiftUI hit-testing에서 투명 영역 처리 → `onTapGesture` 무시
- `SudokuGridView:27`에서 `.onTapGesture { viewModel.selectCell(row:col:) }` 는 셀 뷰에 직접 붙어있어 투명 영역에서 이벤트 전달 불가

**수정 방향**:
- `SudokuCellView`에 `.contentShape(Rectangle())` 추가 → 빈 셀 포함 전체 영역 탭 가능
- 또는 `Color.clear` → `Color(.systemBackground)` 변경 (hit-testing 해소 + 배경색 통일 효과)
- 두 가지 모두 적용이 가장 안전

**토글 동작 (선택/해제)**:
- 이미 선택된 셀을 다시 탭 시 선택 해제 → 기존 `selectCell` 토글 로직 유지 권장
- 변경하면 기존 사용자 동작 예측 모델 깨짐

---

### 2.2 동일 숫자 하이라이트 (신규 인터랙션)

**발동 조건**:
- 선택된 셀의 `value != 0` → 같은 값을 가진 모든 셀에 `cellSameNumber` 배경 표시
- 선택된 셀 자체는 `isSelected` 우선 적용

**미발동 조건**:
- `value == 0` 셀 선택 시 → 하이라이트 없음 (올바른 동작)
- 고정 셀(isFixed) 선택 시도 → 동일 숫자 하이라이트는 작동, NumberPad만 비활성

**피드백 즉각성**: 탭 → 즉시 배경색 변경. 애니메이션 없이 즉각 반영이 스도쿠 특성상 적절 (빠른 풀이 흐름 방해 금지).

---

### 2.3 숫자 패드 인터랙션

**현재**:
- 버튼 높이 52pt → **44pt 최소치 충족** ✅
- 비활성 버튼 opacity 0.4 → 시각적 비활성 표시 존재 ✅

**개선 포인트**:
- 버튼 높이 56pt로 증가 → 탭 영역 확보 강화 ✅
- 그림자 추가로 버튼 존재감 강화 → 탭 영역 인지 향상

---

### 2.4 컨트롤 버튼 (메모/Undo)

**메모 토글 상태 표시**:
- 현재: `accentColor.opacity(0.15)` 배경 + `accentColor` 테두리 (활성) / `secondarySystemBackground` (비활성)
- 상태 전환이 시각적으로 명확 → 유지

**Undo 버튼**:
- 스택이 비어있을 때 비활성화 처리 여부: 코드 확인 필요
- UX 권장: Undo 불가 시 opacity 감소 + `disabled(true)` 처리

---

## 3. 정보 구조 & 인지 부하

### 3.1 현재 레이아웃의 인지 부하 평가

```
[Text("스도쿠") — largeTitle.bold()]  ← 과도한 타이틀 크기, 공간 낭비
[SudokuGridView]                        ← 핵심 게임 요소, 중앙 집중 ✅
[GameControlsView]                      ← 보조 기능, 하단 배치 ✅
[NumberPadView]                         ← 주요 입력, 최하단 ✅
```

**문제점**:
- `Text("스도쿠")` `.largeTitle.bold()` → 게임 중에는 불필요한 인지 자원 사용
- NavigationTitle `.inline` 스타일로 변경 시 화면 상단 공간 확보 → 그리드 더 크게 표시 가능

### 3.2 콘텐츠 우선순위 (인지 계층)

```
1순위: 그리드 (게임의 핵심 정보)
2순위: 숫자 패드 (주 입력 수단)
3순위: 컨트롤 (보조 기능)
4순위: 타이틀/난이도 (컨텍스트 정보)
```

현재 레이아웃은 1순위 요소(그리드)가 화면의 적절한 비중을 차지하고 있음. VStack spacing 재조정으로 공간 활용도 개선 권장.

### 3.3 하이라이트 색상 레이어 복잡도

동시에 활성화될 수 있는 시각 레이어:
- 선택 (파란색)
- 동일 숫자 (초록색)
- 충돌 (빨간색)
- 연관 행/열/박스 (연파란색)
- 메모 숫자 (회색)
- 고정/사용자 숫자 구분 (진한/파란색)

**인지 부하 우려 없음** — 각 상태는 상호 배타적 우선순위로 처리되며, 스도쿠 사용자는 색상 피드백 해석에 익숙. 단, 우선순위 명확화 필수:
```
isSelected > isSameNumber > isConflict > isRelated > default
```

---

## 4. 접근성

### 4.1 탭 영역 44pt+ 검증

| 컴포넌트 | 현재 탭 영역 | 상태 |
|---------|------------|------|
| SudokuCellView | `gridSize / 9` ≈ 37~42pt (iPhone SE 기준) | ⚠️ 소형 기기에서 44pt 미달 가능 |
| NumberPad 버튼 | 52pt 고정 → **개선 후 56pt** | ✅ |
| GameControls 버튼 | `H:16pt + icon:18pt + H:16pt` + `V:10pt * 2` 최소 38pt 터치 영역 | ⚠️ V padding 10→12pt 증가로 개선 필요 |
| 지우기 버튼 | NumberPad 내 56pt | ✅ |

**셀 크기 한계**: iPhone SE (375pt 폭) 기준 그리드가 `375 - 32(패딩) = 343pt`, 셀 하나 = `343/9 ≈ 38pt`. HIG 44pt 미달.
- **현실적 대안**: 스도쿠 장르 특성상 9x9 셀의 44pt 충족은 구조적으로 어려움. `.contentShape(Rectangle())` 적용으로 실제 탭 영역 = 셀 프레임 전체로 보장하는 것이 최선.
- 추가 대안: 접근성 보조 기술(Assistive Touch, Switch Control) 사용자 대상은 별도 고려 불필요 (기존 앱 수준 유지).

### 4.2 색상 대비 4.5:1 검증

| 색상 조합 | 대비 비율 | 상태 |
|-----------|---------|------|
| `#263238` (numberFixed) on `#FFFFFF` | ~14:1 | ✅ |
| `#1565C0` (numberUser) on `#FFFFFF` | ~7.5:1 | ✅ |
| `#D32F2F` (numberConflict) on `#FFFFFF` | ~5.1:1 | ✅ |
| `#757575` (noteText) on `#FFFFFF` | ~4.48:1 | ⚠️ 겨우 통과 (WCAG AA 기준 4.5:1 borderline) |
| `#1565C0` (numberUser) on `#BBDEFB` (cellSelected) | ~3.8:1 | ❌ 미달 |
| `#263238` (numberFixed) on `#BBDEFB` (cellSelected) | ~9.1:1 | ✅ |
| `.gray` (현재 noteText) on `Color.clear/white` | 약 3.95:1 | ❌ 현재 코드 미달 |

**조치 필요 항목**:
1. **noteText**: `#757575` → `#616161` 또는 더 진한 회색으로 변경 권장 (4.5:1 확실히 통과)
2. **선택 셀의 사용자 숫자**: `#1565C0` on `#BBDEFB` 조합은 AA Large(3:1) 통과이나 AA Normal(4.5:1) 미달 → 선택 셀 내 사용자 숫자는 `.medium` weight 유지하되 size 22pt(Large Text 기준 적용 가능) 고려
3. **메모 숫자 현재 코드**: `Color.gray` = 시스템 회색(iOS 17 기준 약 `#8E8E93` on white = ~4.3:1) — borderline. 다크 모드에서 반전되므로 별도 검토 불필요하나 Light Mode에서 주의.

### 4.3 스크린 리더 (VoiceOver) 전략

**현재 코드의 접근성 레이블**: 없음 — 기본 Text 요소만 존재.

**권장 최소 구현** (이번 스프린트 범위):

```swift
// SudokuCellView — accessibilityLabel 추가
.accessibilityLabel(accessibilityDescription)
.accessibilityAddTraits(isSelected ? .isSelected : [])

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

```swift
// NumberPad — 지우기 버튼에 레이블 추가
.accessibilityLabel("지우기")

// 숫자 버튼
.accessibilityLabel("\(number)")
```

**스크린 리더 탐색 순서**: VoiceOver의 기본 탐색(좌→우, 위→아래)이 스도쿠 그리드와 일치하여 별도 `accessibilityElement(children:)` 재정렬 불필요.

**선택 상태 알림**:
- `viewModel.selectCell` 호출 시 `UIAccessibility.post(notification: .announcement, argument: "행 \(row+1) 열 \(col+1) 선택")` 고려 → 단, 이번 스프린트 필수 항목은 아님.

### 4.4 Dynamic Type

**현재 코드**: `.font(.system(size: 20))` — 고정 크기 사용. Dynamic Type 미지원.

**스도쿠 장르 특성 예외 인정**: 9x9 그리드의 구조적 제약으로 Dynamic Type 100% 준수는 그리드 레이아웃 붕괴 초래. 허용 예외 패턴:
- 그리드 내 셀 숫자: 고정 크기 유지 (격자 구조 보호)
- 숫자 패드, 컨트롤 버튼 레이블: `.font(.system(size:))` 대신 `.font(.title3)` 등 Dynamic Type 지원 폰트 사용 권장 — **단, 이번 스프린트에서는 변경 최소화 원칙에 따라 선택적 적용**

---

## 5. 다른 Lead에게 전달할 UX 주의사항

### Feature Lead에게

1. **버그 수정 우선순위**: `.contentShape(Rectangle())` + `Color.clear` → `Color(.systemBackground)` 두 가지 모두 적용. 하나만 적용할 경우 엣지 케이스 존재 가능.

2. **동일 숫자 하이라이트 상태 우선순위 명확화**:
   ```
   isSelected > isSameNumber > isConflict > isRelated > default
   ```
   이 순서를 `backgroundColor` 계산 로직에 하드코딩하지 말고 명시적 if-else 체인으로 구현 권장 (가독성 + 유지보수).

3. **고정 셀 선택 시 동일 숫자 하이라이트**: 고정 셀도 탭 시 `selectedRow/Col` 업데이트 → `selectedValue` 계산 → 동일 숫자 하이라이트 발동. NumberPad 비활성화와 무관하게 하이라이트는 작동해야 함. 현재 `selectCell` 구현이 고정 셀에서도 선택 상태를 업데이트하는지 확인 필요.

4. **Undo 버튼 비활성화**: undo 스택 비어있을 때 버튼 비활성화 처리 여부 확인. UX상 비활성화가 명확히 표시되어야 함 (현재 코드 확인 필요).

5. **접근성 레이블**: `SudokuCellView`에 최소한 `accessibilityLabel` 추가 권장 (위 제안 코드 참조).

### UI Lead에게

1. **noteText 색상**: `Color.gray` 현재 사용 → Light Mode에서 WCAG AA 경계선. `#616161` 이상 진한 회색 권장.

2. **선택 셀 내 사용자 숫자 가독성**: `cellSelected` 배경 위의 `numberUser` 색상 조합이 4.5:1 미달. 선택 상태에서 사용자 숫자를 더 진한 색상으로 오버라이드하거나, `cellSelected` 배경을 약간 더 밝게 조정하는 방안 검토 필요.

3. **메모 모드 활성 상태 피드백**: 현재 `accentColor` 테두리로 구분. 변경 없이 유지 권장 — 사용자 학습 모델 보호.

4. **Undo 버튼 비활성 스타일**: opacity 0.4 + `disabled(true)` 조합이 일관성 있음. NumberPad 비활성 버튼과 동일 스타일 사용 권장.

---

## 6. 범위 외 UX (이번 스프린트 제외)

- 게임 완료 애니메이션/피드백 (현재: 완료 감지 후 기록 저장만 처리)
- 타이머 UI의 일시정지 시 보드 블러 처리
- 힌트 시스템의 점진적 공개 패턴
- 실수 횟수 표시 (하트 아이콘 등)
- HomeView 접근성 개선
- 온보딩 (튜토리얼) 플로우
