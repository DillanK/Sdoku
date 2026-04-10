# UI Analysis — 기능 연동 (0F0BC055)

> **분석 방법**: 디자인 시안 없음. 기존 Swift 소스 코드 역방향 분석(Reverse Engineering)으로 수치 추출.
> **플랫폼**: iOS, SwiftUI, HIG 준수, Light/Dark 모드 자동 대응 (시스템 색상 사용)

---

## 1. 화면 레이아웃

### 1-1. 앱 진입점 뷰 계층

```
SdokuApp (@main)
└── WindowGroup
    └── ContentView                        ← 루트 래퍼 (로직 없음)
        └── HomeView                       ← NavigationStack 루트
            └── NavigationStack
                ├── VStack(spacing: 24)
                │   ├── Text("Sdoku")      ← 타이틀 (padding.top: 40pt)
                │   ├── VStack(spacing: 16)  padding(.horizontal: 24pt)
                │   │   └── DifficultyRowView × 4
                │   └── Spacer
                └── .navigationDestination(item: $selectedDifficulty)
                    └── [현재] Text placeholder  ← ❌ GameView 미연결
```

### 1-2. HomeView 레이아웃 수치

| 속성 | 값 |
|------|-----|
| 루트 컨테이너 | `NavigationStack` |
| 최상위 스택 | `VStack(spacing: 24pt)` |
| 타이틀 상단 패딩 | `padding(.top, 40pt)` |
| 카드 목록 스택 | `VStack(spacing: 16pt)` |
| 카드 목록 좌우 패딩 | `padding(.horizontal, 24pt)` |
| Safe Area | NavigationStack이 자동 처리 |

### 1-3. DifficultyRowView 레이아웃 수치

| 속성 | 값 |
|------|-----|
| 컨테이너 | `Button > HStack` |
| 내부 패딩 | `padding(16pt)` (4면 동일) |
| cornerRadius | **12pt** |
| 배경 | `Color(.secondarySystemBackground)` |
| 내부 좌측 | `VStack(alignment: .leading, spacing: 4pt)` |
| 통계 레이블 간격 | `HStack(spacing: 12pt)` |
| 우측 아이콘 | `chevron.right`, `.secondary` 색상 |

### 1-4. GameView 레이아웃 수치

```
GameView
└── VStack(spacing: 20pt)
    ├── Text("스도쿠")          ← .largeTitle.bold(), padding(.top)
    ├── SudokuGridView          ← padding(.horizontal) — 정사각형 비율 유지
    ├── GameControlsView
    └── NumberPadView           ← padding(.bottom)
```

| 속성 | 값 |
|------|-----|
| 루트 스택 | `VStack(spacing: 20pt)` |
| 그리드 좌우 패딩 | `padding(.horizontal)` (= 16pt, iOS 기본) |
| 그리드 비율 | `aspectRatio(1, contentMode: .fit)` — 정사각형 |

### 1-5. SudokuGridView 레이아웃 수치

| 속성 | 값 |
|------|-----|
| 크기 계산 | `min(geo.size.width, geo.size.height)` |
| 셀 크기 | `gridSize / 9` (동적) |
| 그리드 구조 | `VStack(spacing:0) > HStack(spacing:0)` — 9×9 |
| 경계선 오버레이 | `Canvas`, `allowsHitTesting(false)` |
| 얇은 선 굵기 | **0.5pt** |
| 굵은 선 굵기 (3×3 경계) | **2.5pt** |
| 경계선 색상 | `Color.primary.opacity(0.8)` |

### 1-6. NumberPadView 레이아웃 수치

| 속성 | 값 |
|------|-----|
| 그리드 구조 | `LazyVGrid`, 3열, `GridItem(.flexible(), spacing: 8pt)` |
| 행간 | `spacing: 8pt` |
| 버튼 높이 | **52pt** (고정) |
| 버튼 너비 | `maxWidth: .infinity` (열 균등 분할) |
| cornerRadius | **10pt** |
| 배경 | `Color(.secondarySystemBackground)` |
| 좌우 패딩 | `padding(.horizontal)` (= 16pt) |
| 비활성화 opacity | `0.4` |

### 1-7. GameControlsView 레이아웃 수치

| 속성 | 값 |
|------|-----|
| 컨테이너 | `HStack(spacing: 24pt)` |
| 버튼 좌우 패딩 | `padding(.horizontal, 16pt)` |
| 버튼 상하 패딩 | `padding(.vertical, 10pt)` |
| cornerRadius | **10pt** |
| 아이콘+텍스트 간격 | `HStack(spacing: 6pt)` |

---

## 2. 컴포넌트 상세

### 2-1. SudokuCellView 상태별 색상

| 상태 | 배경색 | 텍스트색 |
|------|--------|---------|
| 기본 | `Color.clear` | — |
| 선택됨 (isSelected) | `Color.blue.opacity(0.35)` | — |
| 연관됨 (isRelated, 동행/열/박스) | `Color.blue.opacity(0.10)` | — |
| 충돌 (isConflict) | `Color.red.opacity(0.15)` | `.red` |
| 고정 숫자 (isFixed) | — | `.primary` |
| 사용자 입력 숫자 | — | `.blue` |
| 메모 숫자 (notes) | — | `.gray` |

### 2-2. SudokuCellView 폰트

| 항목 | 폰트 |
|------|------|
| 고정 숫자 | `.system(size: 20pt, weight: .bold)` |
| 입력 숫자 | `.system(size: 20pt, weight: .regular)` |
| 메모 숫자 | `.system(size: cellSize * 0.5)` (동적, NoteGridView 내부) |
| 메모 그리드 패딩 | `2pt` |

### 2-3. DifficultyRowView 폰트

| 항목 | 폰트 | 색상 |
|------|------|------|
| 난이도 이름 | `.headline` | `.primary` |
| 완료 횟수 레이블 | `.caption` | `.secondary` |
| 최고 기록 레이블 | `.caption` | `.secondary` |
| 기록 없음 레이블 | `.caption` | `.tertiary` |

### 2-4. GameControlsView 버튼 상태별 색상

| 상태 | 배경 | 전경 | 테두리 |
|------|------|------|--------|
| 메모 OFF | `Color(.secondarySystemBackground)` | `.primary` | 없음 |
| 메모 ON (isPencilMode) | `Color.accentColor.opacity(0.15)` | `.accentColor` | `Color.accentColor`, lineWidth: **1.5pt** |
| 되돌리기 가능 | `Color(.secondarySystemBackground)` | `.primary` | 없음 |
| 되돌리기 불가 | `Color(.secondarySystemBackground)` | `.secondary` | 없음 (disabled) |

### 2-5. GameControlsView 아이콘

| 버튼 | SF Symbol | 폰트 크기 |
|------|-----------|---------|
| 메모 토글 | `pencil` | `.system(size: 18pt)` |
| 되돌리기 | `arrow.uturn.backward` | `.system(size: 18pt)` |

### 2-6. NumberPadView 아이콘

| 버튼 | SF Symbol | 폰트 크기 |
|------|-----------|---------|
| 지우기 | `delete.left` | `.system(size: 22pt)` |

---

## 3. 디자인 시스템

### 3-1. 색상 팔레트 (시맨틱 색상)

| 시맨틱 이름 | SwiftUI 표현 | 용도 | 모드 |
|------------|-------------|------|------|
| `cellSelected` | `Color.blue.opacity(0.35)` | 선택된 셀 배경 | Light/Dark 자동 |
| `cellRelated` | `Color.blue.opacity(0.10)` | 연관 셀 배경 | Light/Dark 자동 |
| `cellConflictBg` | `Color.red.opacity(0.15)` | 충돌 셀 배경 | Light/Dark 자동 |
| `numberConflict` | `.red` | 충돌 숫자 | Light/Dark 자동 |
| `numberFixed` | `.primary` | 고정 숫자 | Light/Dark 자동 |
| `numberUser` | `.blue` | 사용자 입력 숫자 | Light/Dark 자동 |
| `numberNote` | `.gray` | 메모 숫자 | Light/Dark 자동 |
| `buttonBackground` | `Color(.secondarySystemBackground)` | 버튼/카드 배경 | Light: ~#F2F2F7, Dark: ~#2C2C2E |
| `pencilActive` | `Color.accentColor.opacity(0.15)` | 메모 활성화 배경 | Light/Dark 자동 |
| `gridLineThin` | `Color.primary.opacity(0.8)` | 셀 경계선 (0.5pt) | Light/Dark 자동 |
| `gridLineBold` | `Color.primary.opacity(0.8)` | 3×3 경계선 (2.5pt) | Light/Dark 자동 |

> **주의**: 하드코딩된 HEX 없음. 모든 색상이 시스템 시맨틱 색상 또는 `.primary`/`.secondary`/.`accentColor` 사용 → Dark Mode 자동 대응됨.

### 3-2. 타이포그래피

| 레벨 | SwiftUI 표현 | 용도 |
|------|-------------|------|
| Display | `.largeTitle.bold()` | 앱 타이틀 "Sdoku", 게임 화면 타이틀 |
| Headline | `.headline` | 난이도 이름 (DifficultyRowView) |
| Body-Semibold | `.system(size: 24pt, weight: .semibold)` | 숫자 패드 숫자 |
| Body-Medium | `.system(size: 15pt, weight: .medium)` | 컨트롤 버튼 텍스트 |
| Body | `.system(size: 20pt, weight: .regular/.bold)` | 그리드 숫자 |
| Caption | `.caption` | 통계 레이블 |
| Icon-L | `.system(size: 22pt)` | delete.left 아이콘 |
| Icon-M | `.system(size: 18pt)` | 컨트롤 버튼 아이콘 |

### 3-3. 간격 시스템

| 토큰 | 값 | 사용처 |
|------|-----|-------|
| `spacing-xs` | 4pt | DifficultyRowView 내부 VStack |
| `spacing-sm` | 6pt | 컨트롤 버튼 아이콘+텍스트 간격 |
| `spacing-md` | 8pt | NumberPad 그리드 간격 |
| `spacing-lg` | 12pt | 통계 레이블 간격 |
| `spacing-xl` | 16pt | DifficultyRowView 내부 패딩, 좌우 패딩 기본값 |
| `spacing-2xl` | 20pt | GameView VStack |
| `spacing-3xl` | 24pt | HomeView VStack, 컨트롤 HStack |
| `inset-card` | 16pt (4면) | DifficultyRowView 카드 패딩 |
| `inset-top-title` | 40pt | 홈 타이틀 상단 여백 |

### 3-4. cornerRadius 시스템

| 값 | 사용처 |
|----|-------|
| **10pt** | NumberPad 버튼, GameControls 버튼 |
| **12pt** | DifficultyRowView 카드 |

### 3-5. 아이콘 목록 (SF Symbols)

| 심볼 | 사용처 |
|------|-------|
| `checkmark.circle` | 완료 횟수 레이블 |
| `clock` | 최고 기록 레이블 |
| `chevron.right` | DifficultyRowView 우측 화살표 |
| `pencil` | 메모 모드 토글 버튼 |
| `arrow.uturn.backward` | 되돌리기 버튼 |
| `delete.left` | 숫자 지우기 버튼 |

---

## 4. UI Lead → 다른 Lead 전달 주의사항

### Feature Lead에게

1. **DifficultySelectView 부재**: 현재 코드에 `DifficultySelectView`가 없다. Spark 대화에서 언급된 `DifficultySelectView`는 실제로는 `HomeView` 내부의 `DifficultyRowView`이다. 별도 뷰 파일 없이 `HomeView.navigationDestination`에서 직접 `GameView`로 연결하는 구조가 맞다.

2. **GameView 진입점**: `GameView`는 현재 `@State private var viewModel = GameViewModel()`로 내부 생성. `difficulty` 파라미터를 받을 수 있도록 init을 수정하거나, `GameViewModel(difficulty:)` 형태로 주입 경로 설계 필요.

3. **NavigationTitle 처리**: `HomeView`의 `navigationDestination` placeholder에 `.navigationTitle(difficulty.displayName)` 설정 코드가 있다. `GameView` 연결 시 동일한 타이틀 설정이 필요하다.

4. **`recordGame()` 시그니처**: `HomeViewModel.recordGame(difficulty:elapsedSeconds:isCompleted:)` — `elapsedSeconds`가 `Int64` 타입. `GameViewModel`에서 타이머 없이 연동 시 `elapsedSeconds: 0`으로 임시 처리 가능. Phase 2 타이머 연동 시 실제 값 전달 필요.

5. **`@Observable` 패턴**: 전체 프로젝트가 iOS 17+ `@Observable` 매크로 사용 중. `@ObservableObject`/`@StateObject` 패턴 혼용 금지.

### UX Lead에게

1. **게임 화면 내비게이션 바**: `GameView`에 현재 `NavigationStack`이 없음. `HomeView`의 `NavigationStack` 안에서 push되므로 `navigationTitle`을 `GameView` 내부에서 `.navigationTitle(...)` modifier로 설정해야 뒤로가기 버튼이 자동 생성된다.

2. **연관 셀 하이라이트**: 선택 시 같은 행/열/박스 전체가 `Color.blue.opacity(0.10)` 배경으로 하이라이트됨. 게임 완료 상태에서도 이 상호작용이 유지되므로, 완료 감지 후 입력 비활성화 시 하이라이트 해제 여부 결정 필요.

3. **고정 셀 입력 비활성화**: `NumberPadView`는 고정 셀 선택 시 `opacity(0.4)` + `.disabled(true)` 처리됨. 게임 완료 후에도 전체 패드 비활성화 고려 필요.

---

> 생성일: 2026-04-10 | UI Lead 역할 | 코드 기반 역방향 분석
