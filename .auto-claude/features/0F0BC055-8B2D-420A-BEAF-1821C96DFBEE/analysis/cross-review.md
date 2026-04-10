# Cross-Review — 기능 연동 (0F0BC055)

> **역할**: Coordinator
> **분석 기반**: UI Lead (ui-analysis.md) + UX Lead (ux-analysis.md) + Feature Lead (feature-analysis.md) 크로스 리뷰
> **충돌 해결 우선순위**: 사용성(UX) > 정확성(Feature) > 심미성(UI)

---

## 1. 식별된 충돌 및 결정

### C1. 미선택 셀 상태에서 NumberPad 처리
**충돌 지점**
- UX Lead: 미선택 시 패드가 활성화 상태로 표시되지만 입력 무반응 → 피드백 공백. `selectedRow == nil` 조건으로 opacity 변화 방법은 "혼란 유발 가능"이라고 명시적으로 경고.
- Feature Lead: `selectedRow == nil` 조건을 추가해 패드 비활성화(opacity 0.4 + disabled)를 고려하되 "UI Lead와 협의" 언급.

**트레이드오프**
- 비활성화(opacity 0.4): 시각적으로 명확하지만, 이미 고정 셀 선택 시에도 같은 처리를 하므로 "왜 안 눌리는가"의 이유가 불분명해짐.
- 무반응 유지: 사용자 혼란은 있으나 기존 패턴 유지.
- 경미한 햅틱: UX Lead 권장. 구현 공수 낮음.

**결정**: **패드를 항상 표시 유지(disabled 처리 없음) + 미선택 상태에서 숫자 탭 시 경미한 햅틱(`.selectionChanged`)만 추가**.
- 이유: 패드 비활성화는 "고정 셀 선택"과 시각적으로 구분이 안 되어 혼란을 더 가중시킴. 햅틱만으로 충분한 피드백 제공. UI 변경 없으므로 UI Lead 협의 불필요.

---

### C2. COMPLETED 상태에서 Undo 허용 여부
**충돌 지점**
- Feature Lead: COMPLETED 진입 후 Undo를 허용하면 완료 기록 저장 후 `isCompleted`가 `false`로 되돌아가는 데이터 불일치 발생. Undo 비활성화 또는 스택 초기화 중 UX Lead에게 정책 결정 요청.
- UX Lead: 시나리오 B에서 완료 overlay → "다시하기"/"홈으로"만 언급. COMPLETED 상태에서 Undo 정책에 대한 명시적 결론 없음.

**트레이드오프**
- Undo 허용: 사용자 자유도 높음. 그러나 이미 저장된 완료 기록과 실제 게임 상태 불일치 → 정확성 위반.
- Undo 비활성화: 데이터 일관성 보장. 완료 overlay가 전체 화면을 덮으면 Undo 버튼 자체가 접근 불가하므로 사실상 자연스럽게 차단됨.

**결정**: **COMPLETED 진입 즉시 전체 NumberPad + GameControlsView 비활성화 (undo 포함). Undo 스택은 초기화하지 않고 보존**.
- 이유: 정확성(Feature) > 사용성(UX). 완료 overlay가 표시되면 사용자는 이미 "게임 끝"임을 인지하므로 UX 충격 없음. 스택 초기화 대신 비활성화만 적용해 "다시하기" 시 새 퍼즐 생성으로 자연스럽게 리셋.

---

### C3. LOADING 중 뒤로가기 허용 여부
**충돌 지점**
- Feature Lead: 허용 시 Task 취소 + 기록 미저장(이건 정상). 미허용 시 `.interactiveDismissDisabled(true)` + 커스텀 취소 버튼 필요. **위험도 높음**으로 분류.
- UX Lead: 게임 중 뒤로가기 시 확인 dialog 필요 언급. LOADING 특정 처리 결정을 Feature에게 위임.

**트레이드오프**
- 차단: LOADING 중 사용자 탈출 불가 → 극악(extreme) 난이도에서 1초 이상 블로킹 가능. 극단적 경우 앱이 멈춘 것처럼 느껴짐.
- 허용 + Task 취소: 사용자가 언제든 뒤로 갈 수 있음. Task 취소 로직 구현 필요.

**결정**: **LOADING 중 뒤로가기 허용. 단, GameView onDisappear 또는 task cancellation으로 Task를 반드시 취소**.
- 이유: 사용성(UX) > 기술적 편의(Feature). 1초 이상 UI 응답 불가 상태는 iOS 앱에서 치명적 UX 결함. 구현 공수(Task 취소)는 높지 않음. LOADING 중 기록 저장은 필요 없으므로 기록 일관성 문제 없음.
- 구현 방식: `GameView.task { }` modifier 사용 시 뷰 소멸 시 자동 취소됨. `Task { }` 직접 생성 시 `.onDisappear { task.cancel() }` 명시 필요.

---

### C4. Phase 1에서 elapsedSeconds == 0 완료 기록의 UI 표시
**충돌 지점**
- Feature Lead: Phase 1 타이머 미구현으로 완료 기록의 `elapsedSeconds == 0` 저장 → `bestTime`이 "00:00" 표시 오염. UI Lead에게 억제 처리 요청.
- UI Lead: 이 문제에 대한 언급 없음.

**트레이드오프**
- 완료 기록 미저장: Phase 1에서 `completedCount` 카운팅도 안 됨 → 홈 통계 표시 불가. 사용자가 첫 번째 게임을 완료해도 아무것도 반영되지 않음.
- 완료 기록 저장 + UI 억제: `elapsedSeconds == 0`인 경우 bestTime을 "기록 없음"으로 표시. `completedCount`는 정상 집계. 가장 현실적 접근.
- 완료 기록 저장 + bestTime 쿼리에 `elapsedSeconds > 0` 조건: 쿼리 수정. Phase 2 타이머 연동 후 자연스럽게 해결됨.

**결정**: **완료 기록은 Phase 1에서도 저장. `bestTime` 표시 조건에 `elapsedSeconds > 0` 필터 적용. UI에서 조건 미충족 시 "기록 없음"으로 표시**.
- 이유: 정확성(Feature) 관점에서 완료 횟수(`completedCount`) 집계는 정확해야 함. bestTime 오염만 억제하면 되므로 최소 변경으로 해결 가능.
- 구현 위치: `GameRecordRepository.bestTime(for:)` 쿼리에서 `elapsedSeconds > 0` 조건 추가. UI 변경 불필요.

---

### C5. GameControlsView 버튼 탭 영역 44pt 미달
**충돌 지점**
- UX Lead: vertical padding 10pt × 2 + icon 18pt = **38pt** → HIG 최소 44pt **미달**. UI Lead에게 패딩 조정 또는 `.contentShape` 확장 요청.
- UI Lead: 현재 수치를 문서화만 했고, 문제 인식 또는 수정 방향 명시 없음.

**트레이드오프**
- 패딩 증가(`.padding(.vertical, 13pt)`): 44pt 달성. 버튼 시각적 크기 증가 → GameView 레이아웃 영향.
- `.contentShape` hit testing 확장: 시각적 크기 유지. 탭 영역만 넓힘.

**결정**: **`.contentShape(Rectangle())` 적용하되, 추가적으로 `.frame(minHeight: 44)` 설정**.
- 이유: 사용성(UX) 필수 요건. 시각적 레이아웃 파괴 없이 달성 가능한 최선책. 두 방법 병행으로 확실한 44pt 보장.
- 구현 위치: `GameControlsView` 내 각 버튼 modifier 추가.

---

### C6. SudokuCellView 탭 영역 HIG 예외 처리
**충돌 지점**
- UX Lead: iPhone SE(375pt 기준) cellSize ≈ 38pt → HIG 44pt **미달 가능**. contentShape 또는 HIG 예외 인정 검토 요청.
- Feature Lead: 언급 없음.

**트레이드오프**
- `.contentShape` 확장: 탭 영역을 cellSize 이상으로 설정 → 인접 셀과 탭 영역 겹침으로 오입력 유발 가능. 9×9 그리드 특성상 물리 제약.
- HIG 게임 그리드 예외 인정: Apple 자체 스도쿠/퍼즐 게임에서도 적용되는 예외. 현실적 해결책.

**결정**: **SudokuCellView 탭 영역은 HIG 게임 그리드 예외로 인정. 추가 처리 없음**.
- 이유: 9×9 그리드에서 44pt 탭 영역은 기하학적으로 불가능(화면 폭 375pt ÷ 9 = 41.7pt). contentShape 확장 시 인접 셀 오입력이 더 심각한 UX 문제 유발.

---

### C7. 접근성(VoiceOver) 구현 우선순위
**충돌 지점**
- UX Lead: 전체 화면에 accessibilityLabel 없음. DifficultyRowView 아이콘 이름 노출, SudokuCellView 위치 불명, NumberPadView 지우기 버튼 기능 불명 등 다수 지적.
- Feature Lead: 코드 매핑에서 접근성 관련 언급 없음. 구현 범위 외.

**트레이드오프**
- 전체 접근성 구현: 공수 높음. 게임 핵심 기능 연동과 병렬 진행 어려움.
- 우선순위 분류 적용: 고위험 항목(기능 오해 유발) 먼저 처리.

**결정**: **접근성은 두 tier로 분리. Tier 1(이번 연동에 포함) + Tier 2(후속 작업)**.

| Tier | 항목 | 이유 |
|------|------|------|
| **Tier 1** | `DifficultyRowView` accessibilityLabel (아이콘 이름 노출 방지) | 기능 탐색의 첫 진입점 |
| **Tier 1** | `NumberPadView` 지우기 버튼 `.accessibilityLabel("지우기")` | 심볼명 직접 노출 방지 |
| **Tier 1** | `GameControlsView` 메모 버튼 `.accessibilityValue(isPencilMode ? "켜짐" : "꺼짐")` | 상태 미전달 |
| **Tier 2** | `SudokuCellView` 행/열 좌표, 충돌 상태, 고정 여부 | 게임 핵심이나 구현 복잡도 높음 |
| **Tier 2** | Dynamic Type 대응 | 레이아웃 개편 필요 |

---

## 2. 충돌 없이 확정된 사항 (Lead 간 합의)

| 항목 | 결정 | 근거 |
|------|------|------|
| PuzzleGenerator 비동기화 | `Task { }` + `@MainActor` UI 업데이트. `onDisappear` Task 취소 | UX + Feature 동의 |
| `SudokuBoard.isSolved` 구현 | `모든 value != 0 AND 모든 isConflict == false` | Feature 분석 (solution 비교 불필요) |
| `GameViewModel(difficulty:)` init 추가 | difficulty → PuzzleGenerator → SudokuBoard 변환 | UI + UX + Feature 동의 |
| recordGame 호출 방식 | 클로저 주입: `GameView(onGameEnd: (Difficulty, Int64, Bool) -> Void)` | Feature 추천, 의존성 최소화 |
| `elapsedSeconds` Phase 1 임시값 | `0`으로 저장, bestTime 쿼리에서 필터링 | C4 결정에 포함 |
| CoreData viewContext 스레드 | recordGame 호출은 반드시 MainActor에서 | Feature 주의사항 |
| NavigationStack 뒤로가기 가드 | `.navigationBarBackButtonHidden(true)` + 커스텀 back 버튼. 진행 중 상태에서 Alert | UX 시나리오 C |
| 완료 overlay UI | NEW 컴포넌트. "다시하기" + "홈으로" | UX 시나리오 B + Feature 코드 매핑 |
| 로딩 overlay UI | NEW 컴포넌트. ProgressView 계열 | UX + Feature |
| extreme 난이도 무한루프 대책 | 최대 시도 횟수(100회) 제한 + hard fallback | Feature 위험도 높음 분류 |

---

## 3. 코드 매핑 최종 확정 (Feature 분석 보완)

| 파일/컴포넌트 | 분류 | 변경 내용 (크로스리뷰 보완 포함) |
|-------------|------|-------------------------------|
| `SudokuBoard` | **MODIFY** | `isSolved: Bool` computed property 추가 |
| `GameViewModel` | **MODIFY** | `init(difficulty:)`, `isCompleted`, `isLoading`, async 퍼즐 생성, Task 취소 처리 |
| `GameView` | **MODIFY** | `difficulty` 파라미터, `onGameEnd` 클로저, 완료 감지, 커스텀 뒤로가기 guard |
| `HomeView` | **MODIFY** | `navigationDestination` → `GameView(difficulty:onGameEnd:)` 연결 |
| `GameControlsView` | **MODIFY** | 버튼 `.frame(minHeight: 44)` + `.contentShape(Rectangle())` 추가 (C5) |
| `GameRecordRepository` | **MODIFY** | `bestTime(for:)` 쿼리에 `elapsedSeconds > 0` 조건 추가 (C4) |
| `PuzzleGenerator` | **MODIFY** | 최대 시도 횟수 제한 추가 (extreme 무한루프 대책) |
| `DifficultyRowView` | **MODIFY** | accessibilityLabel 추가 (Tier 1 접근성) |
| `NumberPadView` | **MODIFY** | 지우기 버튼 accessibilityLabel 추가 (Tier 1 접근성). 미선택 햅틱 추가 (C1) |
| `HomeViewModel` | **REUSE** | 변경 없음 |
| `SudokuPuzzle` | **REUSE** | 변경 없음 |
| `Difficulty` | **REUSE** | 변경 없음 |
| `GameRecordRepository` | **REUSE** (쿼리 수정만) | 위 MODIFY 참조 |
| 완료 overlay 뷰 | **NEW** | `GameCompletionView` — "다시하기" + "홈으로" |
| 로딩 overlay 뷰 | **NEW** | `PuzzleLoadingView` — ProgressView 계열 |

---

## 4. 미결 항목 (구현 단계에서 결정)

| 항목 | 관련 Lead | 결정 필요 시점 |
|------|---------|-------------|
| 완료 overlay 디자인 (sheet vs fullscreenCover vs overlay) | UI Lead | 구현 착수 전 |
| 퍼즐 생성 실패 시 사용자 알림 방식 (Alert vs 자동 재시도 후 통보) | UX Lead | GameView 구현 시 |
| COMPLETED 상태에서 연관 셀 하이라이트 유지 여부 | UI Lead | GameView 완료 처리 구현 시 |
| extreme 난이도 fallback 시 사용자 알림 여부 | UX Lead | PuzzleGenerator 수정 시 |

---

> 생성일: 2026-04-10 | Coordinator 역할 | UI/UX/Feature Lead 크로스 리뷰 종합
