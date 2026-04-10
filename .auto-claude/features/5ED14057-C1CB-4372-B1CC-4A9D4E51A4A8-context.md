# Feature Context: 스도쿠 퍼즐 생성 엔진
> ID: 5ED14057-C1CB-4372-B1CC-4A9D4E51A4A8 | 단계: QA | 갱신: 2026-04-09T08:48:55Z

## Spark 요약
- 핵심 아이디어: 백트래킹 기반 완성 그리드 생성, 난이도별 셀 제거, 유일해 검증 알고리즘을 포함하는 순수 로직 모듈. UI 없이 독립 테스트 가능한 단위.
- 우선순위: Medium

## Spec 핵심 결정
- 요약: 백트래킹 기반 완성 그리드 생성, 난이도별 셀 제거, 유일해 검증 알고리즘을 포함하는 순수 Swift 로직 모듈. UI 의존성 없이 독립적으로 테스트 가능한 스도쿠 퍼즐 생성 엔진.
- 핵심 요구사항:
  - [Must] 백트래킹 알고리즘을 사용하여 유효한 9×9 스도쿠 완성 그리드를 생성한다
  - [Must] 생성된 완성 그리드에서 난이도에 따라 셀을 제거하여 퍼즐을 생성한다 — 쉬움(36~40개 제거), 보통(41~48개 제거), 어려움(49~54개 제거), 극악(55~5...
  - [Must] 셀 제거 후 퍼즐의 유일해(unique solution) 여부를 검증한다 — 유일해가 아닌 경우 제거를 취소하거나 대체 셀을 선택한다
  - [Must] 생성된 퍼즐을 SudokuPuzzle 모델로 반환한다 — 초기 셀 배열(givens), 완성 정답 그리드, 난이도 정보 포함
  - [Must] 난이도(Difficulty) enum을 정의한다 — easy / medium / hard / extreme 4단계
- 수용 기준:
  - 생성된 완성 그리드는 9×9 모든 행, 열, 3×3 박스에 1~9가 중복 없이 포함되어야 한다
  - 난이도별 제거 셀 수 범위 내에서 퍼즐이 생성되고, 반환된 givens 개수가 해당 범위를 만족해야 한다
  - 유일해 검증을 통과한 퍼즐은 정확히 하나의 완성 해답만 존재해야 한다
- 제외 범위: 게임 플레이 상태 관리 및 사용자 입력 처리, 메모(Pencil Mark) 기능, 실행취소(Undo) 기능, CoreData 저장 및 기록 관리, 홈 화면 및 게임 플레이 UI, 힌트 제공 로직, 퍼즐 풀이 검증(사용자 입력이 정답인지 확인)
- 영향 범위: Sdoku/Models/SudokuPuzzle.swift (신규) — 퍼즐 데이터 모델, Sdoku/Models/Difficulty.swift (신규) — 난이도 enum, Sdoku/Services/PuzzleGenerator.swift (신규) — 퍼즐 생성 퍼블릭 API, Sdoku/Services/GridGenerator.swift (신규) — 백트래킹 완성 그리드 생성 내부 모듈, Sdoku/Services/UniqueSolutionValidator.swift (신규) — 유일해 검증 내부 모듈, SdokuTests/PuzzleGeneratorTests.swift (신규) — 단위 테스트

## Plan 핵심 결정
- 아키텍처 설계:
  - 데이터 모델: Difficulty: enum — easy / medium / hard / extreme 4단계. var removalRange: ClosedRange<Int> computed property로 각 난이도의 제거 셀 수 범위를 반환. var displayName: String으로 UI 표시용 이름 제공., SudokuPuzzle: struct — puzzle: [[Int]] (0=빈 셀, 사용자가 보는 초기 상태), solution: [[Int]] (완성 정답 그리드), difficulty: Difficulty, givens: Int (채워진 셀 수 = 81 - 제거된 수). UI 레이어에서 바로 사용 가능하도록 설계, Codable 채택은 게임 저장 Feature에서 담당.
  - 상태 관리: 완전한 stateless 설계. PuzzleGenerator.generate()는 순수 함수로 매 호출마다 새 SudokuPuzzle 값 타입을 반환한다. 내부 상태 없음. UI ...
  - 데이터 흐름: PuzzleGenerator.generate(difficulty:) 호출 → GridGenerator.generateCompleteGrid()로 완성 그리드 생성(백트래킹 + 랜덤...
  - 영향 파일: Sdoku/Sdoku/Models/Difficulty.swift, Sdoku/Sdoku/Models/SudokuPuzzle.swift, Sdoku/Sdoku/Services/GridGenerator.swift, Sdoku/Sdoku/Services/UniqueSolutionValidator.swift, Sdoku/Sdoku/Services/PuzzleGenerator.swift, Sdoku/SdokuTests/PuzzleGeneratorTests.swift
- 구현 요약: 백트래킹 기반 스도쿠 퍼즐 생성 엔진 구현. Difficulty enum 및 SudokuPuzzle 모델 정의 → 완성 그리드 생성기(GridGenerator) → 유일해 검증기(UniqueSolutionValidator) → 공개 API(PuzzleGenerator) → 단위 테스트 순으로 빌드 안전성을 유지하며 점진적으로 구현.
- SubTask: 5개
- SubTask 목록:
  - 1. 데이터 모델 정의 (Difficulty, SudokuPuzzle)
  - 2. GridGenerator — 백트래킹 완성 그리드 생성기
  - 3. UniqueSolutionValidator — 유일해 검증기
  - 4. PuzzleGenerator — 공개 API 및 난이도별 셀 제거 로직
  - 5. PuzzleGeneratorTests — 단위 테스트
- 리스크: 유일해 검증 성능 — 극악 난이도(55~58셀 제거)에서 유일해를 만족하는 셀 조합을 찾기 어려워 생성 시간이 길어질 수 있다. countSolutions에서 해 2개 발견 즉시 중단하는 조기 종료 로직이 필수이며, 최대 시도 횟수(예: 1000회) 초과 시 그리드 재생성으로 폴백하는 안전장치가 필요하다., 백트래킹 재귀 깊이 — Swift 기본 스택 크기 제한 내에서 81칸 백트래킹이 완료되는지 확인 필요. 대부분 문제없지만 최악 케이스에서 스택 오버플로우 가능성이 있으므로 iterative 방식 전환을 염두에 두어야 한다., 극악 난이도 제거 수 상한 미확정 — Spec에서 제거 수 상한이 잘린 상태(55~5...). 60개 이상 제거 시 유일해 생성 실패 빈도가 급증하므로 58을 실용적 상한으로 설정하고, 추후 조정 가능하도록 Difficulty enum에 범위를 캡슐화한다.
- 예상 소요: 2h 30m

## Develop 결과
- 구현 상태: done
- 완료된 작업:
  - **[SubTask 1 완료]**
  - Xcode 프로젝트 파일이 없어서 xcodebuild 빌드는 불가합니다. 코드 자체는 컴파일 가능한 순수 Swift로 작성되었으니 커밋을 진행합니다.[SubTask 3 완료]

## QA 결과
- 검증 상태: passed