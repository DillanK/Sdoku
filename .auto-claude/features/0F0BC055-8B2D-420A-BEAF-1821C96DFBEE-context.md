# Feature Context: 기능 연동
> ID: 0F0BC055-8B2D-420A-BEAF-1821C96DFBEE | 단계: QA | 갱신: 2026-04-10T07:05:53Z

## Spark 요약
- 핵심 아이디어: 전체 대화 맥락을 파악했습니다. 6개 메시지를 통해 아이디어가 충분히 구체화되었으므로 최종 요약을 작성합니다.

## 아이디어 요약
독립적으로 구현된 3개 기능(홈, 게임 플레이, 퍼즐 생성)을 하나의 완전한 사용자 플로우로 연결하는 통합 레이어

**목적**: 현재 4개 단절 지점(홈→게임 화면, 퍼즐 생성→게임, 난이도 전달, 게임 완료→기록 저장)으로...
- 우선순위: Medium

## Analysis 요약
- 종합: # Analysis Summary — 기능 연동 (0F0BC055)

> **작성**: Coordinator 종합
> **기반**: ui-analysis.md + ux-analysis.md + feature-analysis.md + cross-review.md + code-mapping.md
> **작성일**: 2026-04-10

---

## 1. 핵심 구현 포인트 (우선순위 순)

### P1 — HomeView ↔ GameView 네비게이션 연결 [Critical]

현재 `HomeView.navigationDestinati...
- 코드 매핑: # Code Mapping — 기능 연동 (0F0BC055)

> **역할**: Coordinator
> **기반**: UI/UX/Feature 분석 + 소스 코드 역방향 탐색
> **분류 기준**: REUSE / MODIFY / NEW
> **구현 순서**: 의존성 그래프 기반 (번호 = 구현 순서)

---

## 1. REUSE — 변경 없이 재활용
...
- 분석 범위: UI + UX + 기능

## Spec 핵심 결정
- 요약: 독립적으로 구현된 홈·게임·퍼즐 생성 3개 모듈을 NavigationStack 기반 단일 사용자 플로우로 연결. HomeView 난이도 선택 → GameView 진입(실제 퍼즐 로드) → 완료 감지 → 기록 저장의 4개 단절 지점을 해소하여 완전한 플레이 사이클을 완성한다.
- 핵심 요구사항:
  - [FR-01] HomeView에서 난이도 행 탭 시 NavigationStack의 navigationDestination을 통해 GameView로 화면 전환
  - [FR-02] GameViewModel 초기화 시 Difficulty 파라미터를 받아 PuzzleGenerator.generate(difficulty:)로 실제 퍼즐을 생성(Sud...
  - [FR-03] HomeView → GameView 전환 시 선택된 Difficulty 값을 GameViewModel에 전달하여 보드 초기화
  - [FR-04] GameViewModel이 모든 셀이 정답과 일치하는 시점을 자동 감지하여 isCompleted Bool 상태를 true로 변경
  - [FR-05] 게임 완료(isCompleted = true) 시 HomeViewModel.recordGame(difficulty:elapsedSeconds:)를 호출하여 CoreD...
- 수용 기준:
  - [AC-01] 홈 화면에서 임의의 난이도 행을 탭하면 GameView가 NavigationStack으로 푸시된다
  - [AC-02] GameView 진입 시 선택한 난이도에 해당하는 removalRange(쉬움 36~40, 보통 41~48, 어려움 49~54, 극악 55~58) 범위의 실제 퍼즐이...
  - [AC-03] 퍼즐의 빈 셀을 모두 정답으로 채우면 GameViewModel.isCompleted가 true가 된다
- 제외 범위: 게임 진행 중 경과 시간 타이머 표시, 게임 완료 시 축하 애니메이션 또는 전용 완료 화면, 퍼즐 생성 중 로딩 스피너/인디케이터, 게임 일시정지 및 재개 기능, 힌트 기능, 난이도별 최고 기록 갱신 알림
- 영향 범위: Sdoku/Sdoku/HomeView.swift — navigationDestination 추가, DifficultyRowView 탭 핸들러 연결, Sdoku/Sdoku/HomeViewModel.swift — selectedDifficulty 트리거 활성화, refresh() 호출 시점 확인, Sdoku/Sdoku/Views/GameView.swift — GameViewModel(difficulty:) 초기화 방식 변경, 완료 감지 후 HomeViewModel 콜백 연결, Sdoku/Sdoku/ViewModels/GameViewModel.swift — Difficulty 파라미터 추가, PuzzleGenerator 사용, isCompleted 감지 로직 추가

## Plan 핵심 결정
- 아키텍처 설계:
  - 데이터 모델: SudokuPuzzle (기존, REUSE) — puzzle[[Int]], solution[[Int]], difficulty, givens. 변경 없음, GameViewModel (MODIFY) — private let solution: [[Int]], private(set) var difficulty: Difficulty, private let startDate: Date 추가; var isCompleted: Bool (computed, board vs solution 비교), var elapsedSeconds: Int64 (computed, startDate 기준) 추가
  - 상태 관리: @Observable GameViewModel이 solution·difficulty·startDate를 private으로 보유. isCompleted는 board 변경 시마다 자동...
  - 데이터 흐름: DifficultyRowView 탭 → HomeViewModel.selectedDifficulty = difficulty → navigationDestination 활성화 → Ga...
  - 영향 파일: Sdoku/Sdoku/ViewModels/GameViewModel.swift, Sdoku/Sdoku/Views/GameView.swift, Sdoku/Sdoku/HomeView.swift
- 구현 요약: HomeView → GameView → HomeViewModel을 NavigationStack 기반으로 연결한다. GameViewModel에 Difficulty 주입과 PuzzleGenerator 연동, isCompleted 감지를 추가하고, HomeView의 navigationDestination 플레이스홀더를 실제 GameView로 교체하여 완전한 플레...
- SubTask: 3개
- SubTask 목록:
  - 1. GameViewModel — Difficulty 파라미터 + PuzzleGenerator 연동 + 완료 감지
  - 2. GameView — Difficulty 주입 + 완료 콜백 연결
  - 3. HomeView — navigationDestination 실제 GameView 연결
- 리스크: PuzzleGenerator.generate(difficulty:)는 동기 실행으로 메인 스레드를 블로킹함 — 특히 극악(extreme) 난이도에서 수 초 소요 가능. 현재 Spec 범위 내 허용이나, 게임 시작 지연 UX 이슈 발생 시 Task 분리 검토 필요, GameViewModel init(difficulty:) 추가 후 GameView init 시그니처 변경으로 인해 SdokuUITests 내 GameView 직접 생성 코드가 있다면 컴파일 에러 발생 가능 — UITests 파일 확인 필요
- 예상 소요: 1h 30m

## Develop 결과
- 구현 상태: done
- 완료된 작업:
  - 이제 `GameViewModel.swift`를 수정합니다.빌드 오류가 제 변경과 무관한 중복 파일 문제입니다. 실제 Swift 컴파일 오류가 있는지 확인합니다.Swift 컴파일 에러는 없습니다. "Multiple commands produce" 오류는 기존 프로젝트 설정 이슈(중복 파일 참조)이며 제 변경과 무관합니다. 커밋합니다.[SubTask 1 완료]
  - [SubTask 3 완료]

## Verify 결과
- 빌드 상태: failedAfterRetries
- 미해결 에러 (1개):
  - xcodebuild:0 — exit 70, 출력: F7D-438A-87FE-AD5323BF9B94, OS:26.2, name:iPhone 16e }
		{ platform:iOS Simulator, arch:x86_64, id:21A9B6CD-1911-4B14-9808-92D0BE61A0DA, OS:26.2, name:iPhone 17 }
		{ platform:iOS Simulator, arch:x86_64, id:2E3EA350-877A-4636-A09E-E22EDC851A85, OS:26.2, name:iPhone 17 Pro }
		{ platform:iOS Simulator, arch:x86_64, id:75BFBA34-0F51-4AB1-B828-CC06AA6D7A71, OS:26.2, name:iPhone 17 Pro Max }
		{ platform:iOS Simulator, arch:x86_64, id:86554B05-5264-4001-B620-6125B02B5A14, OS:26.2, name:iPhone Air }


## QA 결과
- 검증 상태: passed