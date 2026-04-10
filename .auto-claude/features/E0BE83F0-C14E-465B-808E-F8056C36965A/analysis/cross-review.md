# Cross Review — 화면 기능 연결 (E0BE83F0)

> **Role**: Coordinator
> **분석 일자**: 2026-04-10
> **참조 문서**: ui-analysis.md / ux-analysis.md / feature-analysis.md

---

## 1. 3개 Lead 합의 사항 (충돌 없음)

아래 항목은 3개 Lead가 동일한 결론을 도출했거나 상충이 없는 사항이다.

| 항목 | 합의 내용 |
|------|---------|
| **핵심 연결** | `HomeView.navigationDestination` → `GameView(difficulty:)` 교체가 1순위 |
| **완료 검증 방식** | Solution 비교 방식(방식 B) 채택 — `GameViewModel`이 `SudokuPuzzle.solution` 보관 |
| **타이머 위치** | `GameView` 레벨에서 `@State` + `Timer.publish` 관리 (ViewModel 분리) |
| **기록 저장 경로** | Closure Callback 패턴 — `onGameCompleted: (Int64) -> Void` |
| **Preview 역호환** | `GameView(difficulty: .easy, onGameCompleted: { _ in })` 형태 유지 |
| **REUSE 대상** | `PuzzleGenerator`, `SudokuBoard`, `HomeViewModel`, `GameRecordRepository`, 모든 Component 뷰 |

---

## 2. 충돌 목록 및 결정

### 충돌 A — 퍼즐 생성 비동기 처리 범위

**충돌 내용**
- Feature Lead: `while true` 동기 실행이 🔴 Critical. `.task {}` 비동기 필수.
- UI Lead: 비동기 시 로딩 인디케이터(`ProgressView`) 필요 언급.
- UX Lead: 별도 명시 없음.

**트레이드오프**
- 비동기 처리 없으면 극악 난이도에서 UI 블로킹 (수 초간 앱 응답 없음).
- 비동기 처리 시 로딩 상태 UI 추가 구현 비용 발생.

**결정**: 비동기 처리 + `ProgressView` 로딩 상태 **포함**.

> 기능 정확성 > 구현 비용. UI 블로킹은 앱 품질 기준 미달.

**구현 방향**:
```
GameView 초기화 시:
  @State var isLoading = true
  .task { viewModel = await Task { GameViewModel(difficulty:) }.value; isLoading = false }
  body: isLoading ? ProgressView("퍼즐 생성 중...") : GameContent
```

---

### 충돌 B — 게임 완료 피드백 형식

**충돌 내용**
- UI Lead: Alert 또는 Sheet 언급 (결정 보류).
- UX Lead: "최소한의 시각적 응답 필요", 자동 dismiss 언급 없음.
- Feature Lead: Alert → "홈으로" 버튼 dismiss 또는 자동 dismiss — UX 결정 요청.

**트레이드오프**
- Alert: 명확한 완료 인지, 사용자 능동적 dismiss → 더 안전.
- 자동 dismiss: 빠른 흐름이나 갑작스러운 화면 전환이 혼란 유발 가능.
- Sheet (결과 화면): 풍부한 완료 경험이나 이번 범위 초과.

**결정**: **Alert** 사용. "홈으로" 단일 버튼으로 dismiss.

> 사용성 > 구현 최소화. 자동 dismiss는 사용자가 완료를 인지하지 못할 위험. Sheet는 이번 범위 초과.

**구현 방향**:
```
.onChange(of: viewModel.isCompleted) { if $1 { showCompletionAlert = true } }
.alert("퍼즐 완료!", isPresented: $showCompletionAlert) {
    Button("홈으로") { dismiss() }
} message: {
    Text("소요 시간: \(formattedTime(elapsedSeconds))")
}
```

---

### 충돌 C — 게임 중단 처리 구현 범위

**충돌 내용**
- UX Lead: 진행 손실 문제 🟡 Medium. 이번 범위 포함 여부 결정 필요.
- Feature Lead: Alert 경고 권고, 이번 범위 포함 여부 결정 필요.
- UI Lead: 별도 언급 없음.

**트레이드오프**
- 포함 시: back 제스처 인터셉트 + Alert 구현 추가 (소규모).
- 제외 시: 극악 난이도 진행 중 스와이프 백으로 데이터 소실 → 사용자 좌절.

**결정**: **이번 구현에 포함**. 단순 Alert (Yes/No).

> 사용성 > 완전성. 극악 난이도에서 진행 손실은 재플레이 의욕 저하로 직결. 구현 비용 낮음.

**구현 방향**:
```
.navigationBarBackButtonHidden(true)
.toolbar {
    ToolbarItem(placement: .navigationBarLeading) {
        Button("< 홈") { showExitAlert = true }
    }
}
.alert("게임을 종료하시겠습니까?", isPresented: $showExitAlert) {
    Button("종료", role: .destructive) { dismiss() }
    Button("계속하기", role: .cancel) { }
}
```

---

### 충돌 D — 중단 시 기록 저장 여부

**충돌 내용**
- Feature Lead: `isCompleted: false`로 저장 또는 저장 안 함 — UX 정책 결정 요청.
- UX Lead: "기록 저장 없이 종료" 또는 `recordGame(isCompleted: false)` 중 선택.

**트레이드오프**
- 저장: `completedCount` 변화 없음 (predicate: isCompleted == YES). 기록 DB 누적.
- 미저장: 단순. HomeView 통계에 영향 없음.

**결정**: **중단 시 기록 저장 안 함**. `dismiss()` 만 호출.

> `GameRecordRepository.fetchStats()`가 `isCompleted == true` 조건으로 집계하므로 저장해도 통계 영향 없음. 그러나 DB 누적 방지 + 단순화를 위해 미저장 채택.

---

### 충돌 E — VoiceOver 구현 범위

**충돌 내용**
- UX Lead: 🟠 High. 커스텀 accessibility container 권고.
- Feature Lead: 구현 범위 조율 필요 언급.
- UI Lead: 별도 언급 없음.

**트레이드오프**
- 전체 구현: 커스텀 VoiceOver 컴포넌트는 별도 개발 공수. 이번 핵심 목적(화면 연결)과 별개.
- 최소 구현: HomeView 난이도 버튼 `accessibilityLabel` 추가 — 저비용 고효과.
- 미구현: SwiftUI 기본 동작에만 의존.

**결정**: **HomeView 난이도 버튼 accessibilityLabel만 적용**. 그리드 VoiceOver는 별도 기능으로 분리.

> 사용성 > 완전성. 80% 작업(화면 연결)이 완료되면 20%(VoiceOver) 없어도 됨. 그리드 접근성은 별도 Feature로 처리.

**구현 방향**:
```swift
// DifficultyRowView
.accessibilityLabel("\(difficulty.displayName), \(stats.completedCount)회 완료, \(bestTimeLabel)")
```

---

### 충돌 F — 펜슬 모드 + 값 있는 셀 동작

**충돌 내용**
- UX Lead: 코드상 명확하지 않음, 검증 필요.
- Feature Lead: 현재 notes에 추가됨 (value 유지). 차단 또는 허용 — UX 정책 확인 요청.

**트레이드오프**
- 허용(현재): 값이 있어도 메모 추가 가능. 일부 사용자는 "임시 판단 메모"로 활용.
- 차단: 명확하지만 사용 패턴 제한.

**결정**: **현재 동작 유지(허용)**. 정책 문서화.

> 기존 구현 동작이 실제 스도쿠 앱의 일반적 패턴과 유사. 변경 시 추가 테스트 필요. 이번 범위 외.

---

### 충돌 G — 타이틀 일관성

**충돌 내용**
- UX Lead: HomeView "Sdoku" vs GameView "스도쿠" 불일치. 통일 권고.
- UI Lead: GameView에서 `.navigationTitle(difficulty.displayName)` 추가 권고.

**결정**: **UI Lead 안 채택** — GameView `.navigationTitle(difficulty.displayName)`.

> 두 Lead 모두 변경이 필요하다는 데 동의. 난이도명을 타이틀로 사용하면 정보 구조상 더 명확. GameView "스도쿠" 고정 타이틀 제거.

---

## 3. 최종 코드 매핑 (Coordinator 통합)

### MODIFY

| 파일 | 변경 내용 | 근거 |
|------|---------|------|
| `HomeView.swift` L42-46 | `navigationDestination` → `GameView(difficulty:, onGameCompleted:)` | 모든 Lead 동의 |
| `GameView.swift` | `difficulty: Difficulty`, `onGameCompleted: (Int64) -> Void` 파라미터. 타이머 State. `.navigationTitle(difficulty.displayName)`. 완료 Alert. 중단 Alert. back 버튼 커스텀 | 충돌 B, C, G 결정 반영 |
| `GameViewModel.swift` | `init(difficulty: Difficulty)` 추가. `PuzzleGenerator` 연결. `puzzle: SudokuPuzzle` 보관 | 모든 Lead 동의 |
| `DifficultyRowView` (HomeView 내) | `.accessibilityLabel` 추가 | 충돌 E 결정 |

### NEW

| 대상 | 내용 | 근거 |
|------|------|------|
| `GameViewModel.isCompleted: Bool` | `@Observable`. 완료 시 true (단방향) | 모든 Lead 동의 |
| `GameViewModel.checkCompletion()` | solution 비교 방식 — `board.cells[r][c].value == puzzle.solution[r][c]` 전체 확인 | 충돌 A → Feature Lead 방식 B |
| `GameView` — 타이머 | `@State var elapsedSeconds: Int` + `Timer.publish` | 모든 Lead 동의 |
| `GameView` — 로딩 상태 | `@State var isLoading: Bool` + `ProgressView` | 충돌 A 결정 |
| `GameView` — 완료 Alert | `.onChange(of: viewModel.isCompleted)` → Alert → dismiss | 충돌 B 결정 |
| `GameView` — 중단 Alert | back 버튼 커스텀 + "종료/계속하기" Alert | 충돌 C 결정 |

### REUSE (변경 없음)

| 파일 | 이유 |
|------|------|
| `PuzzleGenerator.swift` | `generate(difficulty:)` API 완성 |
| `SudokuBoard.swift` | `detectingConflicts()`, `mock()` Preview 유지 |
| `SudokuCell.swift` | 변경 없음 |
| `GameState.swift` | solution은 GameViewModel 레벨에서 보관 |
| `HomeViewModel.swift` | `recordGame(difficulty:elapsedSeconds:isCompleted:)` 완성 |
| `GameRecordRepository.swift` | 변경 없음 |
| `Difficulty.swift` | 변경 없음 |
| `SudokuGridView`, `GameControlsView`, `NumberPadView` | 변경 없음 |
| `ContentView.swift`, `SdokuApp.swift` | 변경 없음 |

---

## 4. 구현 우선순위 (최종)

| 순위 | 항목 | 이유 |
|------|------|------|
| 1 | HomeView → GameView 네비게이션 연결 | 기능 전무 → 플레이 불가 |
| 2 | GameViewModel `init(difficulty:)` + PuzzleGenerator 연결 | 실제 퍼즐 없으면 연결 의미 없음 |
| 3 | `isCompleted` + `checkCompletion()` | 완료 감지 없으면 기록 저장 불가 |
| 4 | 타이머 + 완료 Alert + 기록 저장 콜백 | 완료 흐름 마무리 |
| 5 | 비동기 퍼즐 생성 + ProgressView | UI 블로킹 방지 |
| 6 | 중단 Alert (back 버튼 커스텀) | UX 품질 — 진행 손실 방지 |
| 7 | `accessibilityLabel` (HomeView) | 최소 접근성 |

---

## 5. 이번 범위 제외 항목

| 항목 | 이유 | 향후 처리 |
|------|------|---------|
| VoiceOver 그리드 커스텀 컴포넌트 | 구현 공수 高, 핵심 연결 목적과 분리 | 별도 접근성 Feature |
| 충돌 셀 비색상 단서 (테두리/패턴) | 기존 게임 플레이 화면 수정 — 이번 범위 외 | 별도 접근성 Feature |
| 셀 탭 44pt 미달 해결 | 9×9 그리드 특성상 구조 변경 필요 | 별도 UX 개선 Feature |
| NumberPad Dynamic Type | `.font(.title2)` 변경 — 레이아웃 검증 필요 | 별도 접근성 Feature |
| Empty State 동기부여 디자인 | 디자인 작업 필요 | 별도 UI Feature |
| Resume(이어하기) 기능 | CoreData GameState 저장 필요 — 대규모 | 별도 Feature |
