# UX Analysis — 기능 연동 (0F0BC055)

> **분석 방법**: 디자인 시안 없음. Swift 소스 코드 역방향 분석 + HIG/WCAG 2.1 기준 적용.
> **플랫폼**: iOS, SwiftUI, NavigationStack 기반 단방향 탐색 구조.

---

## 1. 사용자 흐름 (User Flows)

### 1-1. Happy Path (정상 흐름)

```
[앱 실행]
    └─ HomeView 표시
         ├─ 난이도 카드 4개 로드 (CoreData 통계 포함)
         └─ 사용자가 난이도 카드 탭
              └─ [현재: placeholder] → [연동 후: GameView push]
                   ├─ 퍼즐 생성 (PuzzleGenerator)
                   ├─ 그리드 표시 (SudokuGridView)
                   ├─ 셀 선택 → NumberPad 활성화
                   ├─ 숫자 입력 / 메모 / 되돌리기
                   └─ 마지막 셀 완성 (isCompleted)
                        └─ [미구현] 완료 감지 → 기록 저장 → HomeView 복귀
```

**현재 미연결 단계**: 난이도 선택 탭 이후 `GameView`로 진입하지 않음. `HomeView.navigationDestination`에 `Text` placeholder만 존재.

### 1-2. Empty State 흐름

| 상태 | 현재 처리 | 평가 |
|------|---------|------|
| 통계 없음 (신규 유저) | `"0회 완료"` + `"기록 없음"` Label 표시 | ✅ 처리됨 |
| 셀 미선택 시 숫자 패드 | 패드가 활성화 상태로 표시됨, 탭해도 무시 | ⚠️ 피드백 없음 (입력 무반응) |
| Undo 스택 빈 상태 | 버튼 `.disabled(true)` + `.secondary` 색상 | ✅ 처리됨 |

**셀 미선택 시 숫자 패드 미반응**: 사용자는 왜 숫자가 안 눌리는지 알 수 없음. `isDisabled`가 고정 셀 기준으로만 작동하고 "선택 없음" 상태를 포함하지 않는 구조적 공백.

### 1-3. 에러 복구 흐름

| 오류 시나리오 | 현재 처리 | 권장 UX |
|-------------|---------|---------|
| PuzzleGenerator 실패 | 없음 (미연동) | 생성 실패 시 재시도 버튼 또는 홈 복귀 alert |
| CoreData fetch 실패 | `try?`로 무시 → 빈 통계 표시 | 현재 허용 범위 (로컬 데이터 안정적) |
| 게임 중 뒤로가기 | 확인 없이 NavigationStack pop → 진행 상태 유실 | 미완성 게임 종료 확인 dialog 필요 |

### 1-4. 게임 완료 흐름 (미구현 — 최우선 설계 필요)

```
마지막 빈 셀 입력
  └─ board.detectingConflicts() 완료 후
       └─ isCompleted 감지 (GameViewModel에 없음)
            ├─ 완료 피드백 (시각/햅틱)
            ├─ HomeViewModel.recordGame(difficulty:elapsedSeconds:isCompleted:) 호출
            ├─ 통계 갱신
            └─ 홈으로 복귀 또는 완료 overlay 표시
```

`GameViewModel`에 완료 감지 로직이 없음. `SudokuBoard`가 완성된 보드를 판별하는 프로퍼티/메서드가 필요하고, `GameViewModel`이 이를 구독해야 함.

---

## 2. 인터랙션 패턴

### 2-1. 입력 방식

| 입력 | 동작 | 피드백 |
|------|------|--------|
| 셀 탭 | selectCell() — 선택/해제 토글 | 배경색 변화 (blue.opacity(0.35)) ✅ |
| 고정 셀 탭 | selectCell() 허용, NumberPad 비활성 | 패드 opacity 0.4 ✅, 햅틱 없음 |
| 숫자 버튼 탭 | inputNumber() | 그리드 숫자 업데이트 ✅, 충돌 시 빨간색 ✅ |
| 동일 숫자 재탭 | value = 0 (지우기) | 숫자 사라짐 ✅ |
| 지우기 버튼 탭 | clearCell() | 숫자/메모 제거 ✅ |
| 메모 토글 | isPencilMode toggle | 버튼 배경/테두리 변화 ✅ |

**피드백 공백**: 숫자 입력 성공/실패에 대한 햅틱(UIImpactFeedbackGenerator) 없음. 특히 충돌 감지 시 시각 피드백만 존재.

### 2-2. 마이크로인터랙션 부재 목록

- 게임 완료 애니메이션/햅틱 — 미구현
- 퍼즐 생성 중 로딩 인디케이터 — 미구현 (PuzzleGenerator가 백트래킹 기반이므로 수백ms 소요 가능)
- 충돌 감지 시 진동 피드백 — 없음
- 셀 선택 시 미세 스케일 애니메이션 — 없음

---

## 3. 정보 구조 (Information Architecture)

### 3-1. 네비게이션 계층

```
NavigationStack (in HomeView)
├─ HomeView                    [Level 0 — 루트]
│   ├─ 앱 타이틀 "Sdoku"
│   └─ 난이도 카드 × 4 (통계 포함)
└─ GameView (push)             [Level 1 — 게임 화면]
    ├─ .navigationTitle(difficulty.displayName) — 뒤로가기 "<쉬움" 자동 생성
    ├─ SudokuGridView (9×9)
    ├─ GameControlsView (메모/되돌리기)
    └─ NumberPadView (1~9 + 삭제)
```

**깊이 2 이상 없음**: 단순 선형 구조. 인지 부하 낮음.

### 3-2. 콘텐츠 그룹핑

| 영역 | 정보 그룹 | 사용자 멘탈 모델 |
|------|---------|---------------|
| HomeView 카드 | 난이도명 + 완료 횟수 + 최고 기록 | "내가 얼마나 해봤는가" → 재플레이 동기 유발 ✅ |
| GameView 상단 | 타이틀만 존재 | 난이도 표시, 경과 시간 없음 → 컨텍스트 정보 부족 ⚠️ |
| 그리드 하단 | 컨트롤 → 숫자 패드 순서 | 자연스러운 위→아래 사용 흐름 ✅ |

### 3-3. 인지 부하 평가

| 요소 | 부하 수준 | 비고 |
|------|---------|------|
| 9×9 그리드 자체 | 높음 (불가피) | 스도쿠의 본질적 복잡도 |
| 연관 셀 하이라이트 | 낮춤 ✅ | 동행/열/박스 파악 도움 |
| 충돌 색상 즉시 표시 | 낮춤 ✅ | 오류 조기 발견 |
| 메모 모드 시각 구분 | 낮춤 ✅ | 버튼 색/테두리로 현재 모드 명확 |
| 타이머 없음 | 낮춤 (현재) | 압박 없음. 단, 기록 저장 시 `elapsedSeconds` 필요 → 연동 후 타이머 추가 시 부하 증가 고려 |
| 게임 완료 상태 없음 | 혼란 유발 ❌ | 완성 후 어떤 변화도 없으면 사용자가 완료 여부 알 수 없음 |

---

## 4. 접근성 검증

### 4-1. 탭 영역 44pt+ 검증

| 컴포넌트 | 실제 탭 영역 | 판정 |
|---------|------------|------|
| NumberPadView 버튼 | height: 52pt, width: 동적(균등 1/3) | ✅ 통과 |
| DifficultyRowView 카드 | padding 16pt × 4 + headline + caption ≈ 52~56pt | ✅ 통과 |
| GameControlsView "메모" 버튼 | vertical padding 10pt × 2 + icon 18pt = **38pt** | ❌ **미달** |
| GameControlsView "되돌리기" 버튼 | vertical padding 10pt × 2 + icon 18pt = **38pt** | ❌ **미달** |
| SudokuCellView (그리드 셀) | gridSize/9 ≈ 40pt (iPhone 15 Pro 기준) | ⚠️ **경계값** |

**GameControlsView 버튼**: `.padding(.vertical, 10)` + `.font(.system(size: 18))`로 계산 시 총 높이 약 38pt. HIG 최소 기준 44pt **미달**. `.frame(minHeight: 44)` 또는 `.contentShape(Rectangle())` + hit testing 확장 필요.

**SudokuCellView**: iPhone SE(375pt 기준) gridSize ≈ 343pt → cellSize ≈ 38pt. 소형 기기에서 **미달** 가능성 있음. 그리드 특성상 물리 크기 확장이 어려우므로 `.contentShape` 활용 또는 HIG 예외 인정(게임 그리드) 검토 필요.

### 4-2. 색상 대비 4.5:1 검증 (WCAG 2.1 AA)

| 텍스트 / 배경 조합 | 추정 대비율 | 판정 |
|-----------------|-----------|------|
| `.primary` on `.secondarySystemBackground` (Light) | ~7:1 | ✅ |
| `.primary` on `.secondarySystemBackground` (Dark) | ~7:1 | ✅ |
| `.blue` (사용자 숫자) on `Color.clear` (흰 배경) | ~3.7:1 | ⚠️ **미달** |
| `.gray` (메모 숫자) on `Color.clear` | ~3.2:1 | ❌ **미달** |
| `.secondary` (caption) on `.secondarySystemBackground` | ~3.1:1 | ⚠️ 미달 (단, 비활성 UI는 WCAG 예외 허용) |
| `.red` (충돌 숫자) on `Color.red.opacity(0.15)` (Light) | ~3.5:1 | ⚠️ **미달** |

**심각도 순위**:
1. `.gray` 메모 숫자 — 게임 핵심 정보가 저대비. Dark mode에서 더 악화.
2. `.blue` 사용자 입력 숫자 — 기준 미달이나 `.blue`의 명도로 실사용 영향 제한적.
3. `.red` 충돌 숫자 — 빨간 배경 위 빨간 텍스트 조합이 저대비.

> 정확한 수치 지정은 UI Lead 영역. Feature Lead는 시맨틱 색상 토큰을 유지하고 UI Lead가 대비 보정 색상 지정.

### 4-3. VoiceOver (스크린 리더) 전략

**현재 상태**: 전체 화면에 명시적 `.accessibilityLabel`이 없음. SwiftUI 기본 동작에 의존.

| 컴포넌트 | VoiceOver 기본 읽기 | 문제점 | 권장 처리 |
|---------|------------------|--------|---------|
| DifficultyRowView | "쉬움, 0회 완료, 이미지, 기록 없음, 이미지, chevron.right, 이미지, 버튼" | 아이콘 이름이 그대로 읽힘 | `.accessibilityLabel("쉬움, 0회 완료, 기록 없음").accessibilityAddTraits(.isButton)` |
| SudokuCellView (빈 셀) | 아무 것도 없거나 좌표 없음 | 위치 파악 불가 | `.accessibilityLabel("행 \(row+1) 열 \(col+1), 빈 칸")` |
| SudokuCellView (고정 숫자) | 숫자 읽음 | 고정 여부 불명 | `.accessibilityLabel("\(value), 고정")` |
| SudokuCellView (충돌) | 숫자만 읽음 | 충돌 상태 미전달 | `.accessibilityLabel("\(value), 충돌")` |
| NumberPadView 지우기 버튼 | "delete.left, 버튼" (심볼 이름) | 기능 불명 | `.accessibilityLabel("지우기")` |
| GameControlsView 메모 버튼 | "pencil, 메모, 버튼" | 현재 상태(ON/OFF) 미전달 | `.accessibilityValue(isPencilMode ? "켜짐" : "꺼짐")` |
| GameControlsView 되돌리기 | "되돌리기, 버튼" | 비활성 시 이유 불명 | `.accessibilityHint("실행 취소할 작업이 없습니다")` (disabled 시) |

### 4-4. Dynamic Type

- 고정 폰트 크기 사용: `.system(size: 20)`, `.system(size: 24)`, `.system(size: 18)` 등
- Dynamic Type 미지원: 사용자 큰 텍스트 설정 반영 안 됨
- **그리드 셀**: 고정 크기 폰트가 불가피 (셀 크기 기반). 셀 크기 자체가 동적이므로 `cellSize * 0.5` 방식(메모 폰트)이 올바른 접근.
- **NumberPad, Controls**: `.body`, `.callout` 등 Dynamic Type 스타일 고려 가능하나, 레이아웃 깨짐 위험 있음. Accessibility Size에서 레이아웃 대응이 Feature Lead 구현 범위.

---

## 5. 주요 UX 시나리오 — 연동 시 설계 필요

### 시나리오 A: 게임 시작 전환
```
DifficultyRowView 탭
  └─ 로딩 상태 표시 (퍼즐 생성 중) — ProgressView overlay 또는 GameView 내 skeleton
       └─ GameView 표시 (난이도 타이틀 포함)
```
- PuzzleGenerator가 동기 호출이면 메인 스레드 블로킹 → UI 멈춤. Task {} 비동기 처리 필요.

### 시나리오 B: 게임 완료
```
마지막 셀 완성
  └─ 완료 감지 (board.isSolved)
       ├─ 햅틱 (.notificationOccurred(.success))
       ├─ 시각 피드백 (그리드 전체 highlight 또는 overlay)
       ├─ recordGame() 호출
       └─ "다시 하기" / "홈으로" 선택지 제공
```

### 시나리오 C: 게임 중 뒤로가기
```
navigationTitle의 뒤로가기 버튼 탭
  └─ 미완성 게임 감지 (undoStack.isEmpty == false OR 진행 중)
       └─ Alert: "게임을 종료하시겠어요? 진행 상황은 저장되지 않습니다."
            ├─ "종료" → pop (HomeView로 복귀, recordGame isCompleted: false)
            └─ "계속" → alert 닫기
```

### 시나리오 D: 셀 미선택 상태 숫자 입력 시도
```
NumberPad 숫자 탭 (셀 미선택)
  └─ 현재: 무반응
       └─ 권장: 경미한 햅틱 (.selectionChanged) + 그리드 흔들림(shake) 애니메이션 or 생략
```

---

## 6. UX Lead → 다른 Lead 전달 주의사항

### Feature Lead에게

1. **`GameViewModel.isCompleted` 추가 필수**: 퍼즐 완료 감지를 위해 `SudokuBoard.isSolved` 프로퍼티 (또는 동등 연산) 및 `GameViewModel`에 computed property 추가 필요. `onChange(of: viewModel.isCompleted)`로 완료 이벤트 처리.

2. **비동기 퍼즐 생성**: `PuzzleGenerator.generate(difficulty:)`는 백트래킹 알고리즘이므로 최악 케이스에서 수백ms 소요 가능. `Task { await ... }` 비동기 처리 + 로딩 UI 필수.

3. **`GameViewModel(difficulty:)` init**: `HomeView.navigationDestination`에서 `difficulty`를 받아 `GameViewModel`에 주입 필요. 현재 `GameViewModel.init(board: .mock())`이므로 `init(difficulty: Difficulty)` 오버로드 또는 변환 필요.

4. **뒤로가기 가로채기**: SwiftUI NavigationStack에서 뒤로가기를 가로채려면 `.navigationBarBackButtonHidden(true)` + 커스텀 back 버튼 구현 필요. 또는 iOS 16+의 `.interactiveDismissDisabled()` 검토.

5. **`recordGame` 호출 시점**: 완료(isCompleted: true) 시 즉시 호출. 중도 포기(isCompleted: false) 시 홈 복귀 전 호출. `elapsedSeconds`는 Phase 1에서 타이머 미구현 시 `0`으로 임시 처리 가능.

6. **`NumberPadView.isDisabled` 확장**: 현재 고정 셀 기준. `selectedRow == nil` 조건 추가로 미선택 시 비활성화 처리 고려. (단, 패드가 항상 보이므로 opacity 변화는 혼란 유발 가능 — UI Lead와 협의)

### UI Lead에게

1. **GameControlsView 버튼 탭 영역**: 현재 vertical padding 10pt로 총 38pt. 44pt 달성을 위한 패딩 조정 또는 `.contentShape(Rectangle().inset(by: -3))` 방식 검토 요청.

2. **메모/고정 숫자 색상 대비**: `.gray` 메모 숫자와 배경의 대비가 기준 미달. Dark mode 포함 검증 및 보정 색상 지정 요청.

3. **게임 완료 UI**: 완료 overlay 또는 sheet의 디자인 필요. "다시 하기" / "홈으로" 버튼 포함.

4. **퍼즐 생성 로딩 UI**: 짧은 시간이지만 skeleton or ProgressView 디자인 필요.

---

> 생성일: 2026-04-10 | UX Lead 역할 | 코드 기반 역방향 분석 + HIG/WCAG 2.1 적용
