# UX Analysis — Sdoku 화면 기능 연결

**Feature ID**: E0BE83F0-C14E-465B-808E-F8056C36965A
**Stage**: Analysis
**Role**: UX Lead
**Date**: 2026-04-10

---

## 1. 사용자 흐름 (User Flows)

### 1.1 Happy Path — 게임 시작부터 완료까지

```
[앱 실행]
  → HomeView 로드 (통계 fetch via onAppear)
  → 4개 난이도 선택지 표시 (쉬움 / 보통 / 어려움 / 극악)
  → 사용자가 난이도 탭
  → [현재: placeholder "게임 화면: easy"] ← 연결 필요
  → [목표: GameView 전환 with selected Difficulty]
  → 퍼즐 그리드 표시 + 숫자패드 + 컨트롤 버튼
  → 셀 탭 → 선택 하이라이트 + 연관 셀 하이라이트
  → NumberPad 탭 → 값 입력 또는 메모 추가
  → 퍼즐 완성
  → [완료 처리 미구현] — 완료 감지 + 기록 저장 + 홈 복귀 흐름 필요
```

**현재 상태**: HomeView → GameView 연결이 `placeholder` 텍스트로 막혀있어 실제 플레이 불가. 이번 기능 구현의 핵심 목적이 이 연결.

### 1.2 Error Recovery Flow — 충돌 발생 시

```
[잘못된 숫자 입력]
  → 실시간 충돌 감지 (detectingConflicts() 즉시 실행)
  → 충돌 셀: 빨간 배경(0.15 opacity) + 빨간 텍스트
  → 사용자 선택지:
    A. Undo 탭 → 이전 상태 복원 (보드 전체 스냅샷)
    B. 충돌 셀 재선택 → 다른 숫자 입력 또는 Clear
    C. Clear 탭 → 값 삭제 후 재입력
```

**UX 주의사항**: 충돌 해소 후에도 사용자가 "어떻게 고쳤는지" 피드백이 없음. 충돌 해소 시 빨간색이 사라지는 것만으로 피드백 끝 — 이는 충분하지만 색약 사용자에게는 불충분.

### 1.3 Empty State — 첫 실행 / 기록 없음

```
[최초 실행 or 특정 난이도 미플레이]
  → HomeView에서 해당 난이도의 completedCount = 0
  → bestTime = nil → "기록 없음" 표시
  → 사용자에게 "아직 플레이하지 않은 난이도" 시각적 구분 방법 없음
```

**Gap**: 0회 완료 상태와 1회+ 완료 상태의 시각적 차이가 숫자로만 표현됨. "도전하지 않은" 난이도에 대한 동기 부여 UI 없음.

### 1.4 게임 중 중단 Flow

```
[게임 진행 중 홈으로 이동 시]
  → 현재: 게임 상태 저장 메커니즘 없음
  → NavigationStack back gesture / back button으로 이탈 시 진행 데이터 소실
```

**Gap**: 게임 중간 저장(Resume) 기능 또는 이탈 경고 다이얼로그 없음. 퍼즐 난이도가 높을수록 진행 손실에 대한 사용자 좌절감 증가.

---

## 2. 인터랙션 패턴

### 2.1 셀 선택 인터랙션

- **현재 동작**: 탭으로 선택, 같은 셀 재탭으로 해제 (토글)
- **연관 하이라이트**: 선택된 셀의 같은 행/열/3×3 박스 자동 강조 (blue 0.10 opacity)
- **UX 검토**: 토글 해제 동작이 직관적이나, **숫자 입력 후 자동으로 다음 셀로 이동하는 흐름이 없음** — 스도쿠 앱에서 흔한 편의 기능. 이번 범위 외이지만 UI Lead에게 전달 필요.

### 2.2 숫자 입력 인터랙션

- **Normal Mode**: 탭 → 셀에 값 설정 (기존 값 덮어쓰기)
- **Pencil Mode**: 탭 → 해당 번호 notes 토글 (있으면 제거, 없으면 추가)
- **Delete**: clearCell() — 값과 메모 모두 삭제

**인터랙션 명확성**: 메모 모드에서 이미 확정된 값이 있는 셀에 진입 시 동작이 코드상 명확하지 않음 — `GameViewModel.inputNumber()`에서 `cell.value != 0 && !cell.isFixed` 경우에 값을 0으로 리셋 후 notes 추가 로직인지 검증 필요.

### 2.3 피드백 패턴

| 액션 | 즉각 피드백 | 지연 피드백 |
|------|------------|------------|
| 셀 선택 | 색상 변경 (즉시) | — |
| 숫자 입력 | 값 표시 + 충돌 감지 | — |
| 충돌 발생 | 빨간 하이라이트 | — |
| Undo | 이전 상태 복원 | — |
| 퍼즐 완료 | **미구현** | — |

**Gap**: 퍼즐 완료 시 피드백 없음 — 완료 감지 로직 자체가 없음. GameViewModel에 `isCompleted: Bool` 또는 완료 이벤트가 없음.

### 2.4 마이크로인터랙션

- **현재 구현**: 상태 전환이 즉각적 (애니메이션 없음)
- **Pencil Mode 토글**: 버튼 스타일만 변경 (색상/테두리), 전환 애니메이션 없음
- **Undo**: 즉각 상태 복원, 시각적 전환 없음

**권고**: 이번 구현 범위(화면 연결)에서는 애니메이션 추가보다 기능 연결 우선. 단, 퍼즐 완료 피드백에는 최소한의 시각적 응답 필요.

---

## 3. 정보 구조

### 3.1 네비게이션 계층

```
Level 0: SdokuApp
Level 1: HomeView (NavigationStack)
  └─ Level 2: GameView (navigationDestination)
```

- **깊이**: 2-depth, 적절함
- **뒤로가기**: NavigationStack의 기본 back button 사용
- **현재 문제**: GameView로의 destination이 연결되지 않아 사실상 1-screen 앱 상태

### 3.2 콘텐츠 그룹핑

**HomeView**:
- 앱 타이틀 → 4개 난이도 버튼 (리스트 형태)
- 각 버튼: 난이도명 + 완료 횟수 + 최고 시간 → 3개 정보가 한 row에 집약

**GameView**:
- 상단: 타이틀 ("스도쿠")
- 중앙: 9×9 그리드 (주 콘텐츠 영역)
- 하단: 컨트롤 버튼 (메모/Undo) → 숫자패드 순서

**인지 부하 평가**:
- 홈 화면: 낮음 — 4개 선택지, 단순 정보
- 게임 화면: 중간 — 81개 셀 + 9개 숫자 + 2개 컨트롤. 스도쿠 특성상 불가피한 복잡도
- **잠재적 과부하 지점**: 메모 모드 진입 여부가 버튼 상태로만 표시됨 — 현재 모드를 더 명확히 표시하는 전략 고려 필요 (UI Lead 검토 사항)

### 3.3 타이틀 불일치

- `HomeView` 타이틀: "Sdoku"
- `GameView` 타이틀: "스도쿠"

**권고**: 앱명과 게임 화면 타이틀을 통일하거나 GameView에서는 선택한 난이도명을 타이틀로 표시하는 것이 정보 구조상 더 명확함. (예: "스도쿠 — 보통")

---

## 4. 접근성

### 4.1 탭 영역 (44pt+ 요구사항)

| 컴포넌트 | 현재 구현 | 44pt 충족 여부 |
|---------|---------|--------------|
| HomeView 난이도 버튼 | `frame(maxWidth: .infinity)` + padding | ✅ 충족 (전체 너비, 세로 충분) |
| 숫자패드 버튼 | `frame(height: 52)` + LazyVGrid | ✅ 충족 (52pt 명시) |
| 메모/Undo 버튼 | padding + HStack | ⚠️ 명시적 크기 없음 — 검증 필요 |
| 스도쿠 그리드 셀 | `gridSize / 9` (GeometryReader 기반) | ⚠️ 기기 크기에 따라 44pt 미달 가능 |
| 셀 크기 계산 | `min(geo.size.width, geo.size.height) / 9` | iPhone SE: ~36pt, iPhone 15 Pro: ~41pt |

**중요 이슈**: 그리드 셀은 기기 최소 크기(iPhone SE, 375pt 기준)에서 약 `375/9 ≈ 41pt`로 44pt에 미달할 수 있음. 그리드 셀은 스도쿠 게임의 핵심 입력 요소이므로:
- 셀 자체를 크게 할 수는 없음 (9×9 고정)
- `.contentShape(Rectangle())` 또는 `.padding`으로 hitbox 확장은 그리드 특성상 어려움
- **권고**: VoiceOver 사용 시 행/열 단위 또는 그룹 탐색 전략 채택 → 개별 셀 탭 크기 이슈 우회

### 4.2 색상 대비 (4.5:1 요구사항)

**현재 색상 사용 분석**:

| 요소 | 전경 | 배경 | 구현 | 검증 필요 |
|------|------|------|------|---------|
| 그리드 일반 셀 숫자 | `.primary` | `.clear`/시스템 배경 | 시스템 기본 | ✅ 시스템이 보장 |
| Fixed 셀 숫자 | `.primary` (bold) | 시스템 배경 | 시스템 기본 | ✅ |
| 입력 셀 숫자 | `.blue` | 시스템 배경 | 커스텀 | ⚠️ 라이트/다크모드 검증 필요 |
| 충돌 셀 숫자 | `.red` | `.red 0.15` 배경 | 커스텀 | ⚠️ 낮은 대비 우려 |
| 메모 숫자 | `.gray` | 시스템 배경 | 커스텀 | ⚠️ gray는 4.5:1 미달 가능 |
| 선택 셀 배경 | — | `.blue 0.35` | — | — |
| 연관 셀 배경 | — | `.blue 0.10` | — | — |
| 충돌 셀 배경 | — | `.red 0.15` | — | — |

**주요 접근성 이슈**:
1. **충돌 표시가 색상에만 의존** — `.red` 배경 + `.red` 텍스트 조합은 색약 사용자에게 인식 불가. 텍스트 볼드 처리, 아이콘 오버레이, 또는 패턴 배경 등 비색상 단서 추가 필요
2. **메모 텍스트 `.gray`** — 소형 폰트 크기(cellSize × 0.5 / 9)에서 gray가 4.5:1 대비 미달 가능성 높음
3. **blue 입력값** — 다크모드에서 `.blue`의 정확한 색상 확인 필요 (시스템 `.accentColor`를 사용하는 것이 더 안전)

### 4.3 스크린 리더 (VoiceOver) 전략

**현재 구현**: 명시적 accessibility modifier 없음 — SwiftUI 기본 동작에만 의존

**권고 전략**:

**HomeView**:
```
난이도 버튼 → accessibilityLabel: "{난이도명}, {완료횟수}회 완료, 최고기록 {시간} / 기록없음"
예: "쉬움, 3회 완료, 최고기록 5분 23초"
```

**SudokuCellView**:
```
각 셀 → accessibilityLabel: "{행},{열}: {값 또는 '빈 칸'} {충돌 여부}"
예: "3행 5열: 7, 충돌" / "3행 5열: 빈 칸"
```

**메모 셀**:
```
accessibilityLabel: "{행},{열}: 메모 {숫자 목록}"
예: "3행 5열: 메모 1, 4, 7"
```

**그리드 탐색 전략**:
- 개별 81개 셀을 하나씩 탐색하면 VoiceOver 사용성 극히 저하
- `.accessibilityElement(children: .contain)` 로 행 그룹화 고려
- 또는 행별로 `.accessibilityElement(children: .combine)` 처리
- **권고**: 그리드 전체를 커스텀 VoiceOver 컴포넌트로 처리하는 것이 최선 (Feature Lead와 구현 범위 조율 필요)

**NumberPadView**:
```
숫자 버튼 → accessibilityLabel: "숫자 {n} 입력"
삭제 버튼 → accessibilityLabel: "셀 지우기"
```

**GameControlsView**:
```
메모 버튼 → accessibilityLabel: "메모 모드 {on/off}", accessibilityHint: "탭하여 메모 모드 전환"
Undo 버튼 → accessibilityLabel: "되돌리기", accessibilityHint: "이전 상태로 되돌립니다"
```

### 4.4 Dynamic Type 지원

- **현재**: `.font(.system(size: X))` 절대 크기 사용 다수 → Dynamic Type 미지원
  - 그리드 셀 값: `cellSize * 0.5` (상대적이라 OK)
  - 메모 셀: `cellSize / 9 * 0.5` (상대적이라 OK)
  - NumberPad: `.font(.system(size: 24, weight: .semibold))` → **절대값**
  - 타이틀: `.font(.largeTitle)` → ✅ Dynamic Type 지원
- **권고**: NumberPad 숫자는 `.font(.title2)` 등 semantic size로 변경 권고

---

## 5. 다른 Lead들에게 전달할 UX 주의사항

### → Feature Lead

1. **퍼즐 완료 감지 필수**: `GameViewModel`에 `isCompleted: Bool` 추가 필요. 모든 셀이 채워지고 충돌이 없을 때 완료 상태 진입. 완료 시 `HomeViewModel.recordGame()` 호출 연결 필요.

2. **홈→게임 데이터 전달**: `HomeView`에서 선택한 `Difficulty`를 `GameViewModel` 초기화에 전달해야 함. 현재 `GameViewModel`이 mock board를 사용 중 → `PuzzleGenerator.generate(difficulty:)`를 연결해야 실제 게임 가능.

3. **게임 중단 처리**: NavigationStack back 제스처 시 진행 데이터 소실. 최소한 alert 경고 구현 권고 (이번 범위 내에 포함 여부 결정 필요).

4. **완료 후 흐름**: 퍼즐 완료 → 결과 표시 → 홈 복귀 or 재시작 흐름이 정의되어야 함. Feature Lead가 구현 범위 결정 필요.

5. **VoiceOver 그리드 탐색**: 81개 셀 개별 탐색은 사용 불가 수준. 기술적 구현 방안 (커스텀 accessibility container) Feature Lead 검토 필요.

### → UI Lead

1. **메모 모드 현재 상태 표시 강화**: 메모 모드 진입 시 그리드 또는 타이틀 영역에 추가 시각적 표시 고려 — 버튼만으로는 현재 모드 인지가 어려울 수 있음.

2. **충돌 비색상 단서**: 색상만으로 충돌을 표시하는 현재 방식은 색약 접근성 미충족. 충돌 셀에 대한 추가 시각적 단서 (테두리, 아이콘, 패턴 등) 디자인 필요.

3. **그리드 셀 최소 크기**: iPhone SE (375pt) 기준 셀이 ~41pt. 44pt 미달. 그리드 패딩 최소화 또는 화면 가득 채우는 방식으로 보완 검토.

4. **홈 화면 Empty State 디자인**: 완료 기록이 없는 난이도의 통계 표시 방식 — 현재 단순 "기록 없음" 텍스트보다 동기부여적 디자인 고려.

5. **타이틀 일관성**: HomeView "Sdoku" vs GameView "스도쿠" 불일치. 통일 방향 결정 필요.

6. **메모 텍스트 가독성**: 메모 숫자가 매우 작음 (cellSize/9 × 0.5). `.gray` 색상은 소형 텍스트에서 4.5:1 대비 미충족 가능 — 더 어두운 secondary color 사용 검토.

---

## 요약

| 영역 | 현재 상태 | 우선순위 이슈 |
|------|---------|-------------|
| 화면 연결 | HomeView → GameView 미연결 (placeholder) | 🔴 Critical |
| 완료 흐름 | 퍼즐 완료 감지/처리 없음 | 🔴 Critical |
| 충돌 접근성 | 색상 단서만 존재 | 🟠 High |
| VoiceOver | 구현 전무 | 🟠 High |
| 중단 처리 | 데이터 소실 위험 | 🟡 Medium |
| 메모 대비 | `.gray` 소형 텍스트 | 🟡 Medium |
| Dynamic Type | NumberPad 절대 크기 | 🟡 Medium |
| 셀 탭 크기 | ~41pt (SE 기준) | 🟡 Medium |
