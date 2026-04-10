# Feature Context: 버그 수정 및 UI 변경
> ID: BECE9135-DD0C-4D5E-AB3C-D630156522D2 | 단계: QA | 갱신: 2026-04-10T07:50:51Z

## Spark 요약
- 핵심 아이디어: ## 아이디어 요약

빈 셀 탭 불가 버그를 수정하고, 게임 플레이 화면 UI를 Sudoku.com 스타일로 개선하는 품질 향상 작업

**목적**: 빈 셀 선택 불가 버그(SwiftUI hit-testing 이슈)를 해결하고, 셀 하이라이트·동일 숫자 강조·숫자 패드 스타일 개선으로 게임 플레이 사용성과 시각적 완성도를 높인다

**대상 사용자**: 로컬...
- 우선순위: Medium

## Analysis 요약
- 종합: # Analysis Summary — 버그 수정 및 UI 변경

> **작성일**: 2026-04-10
> **기반 문서**: ui-analysis.md, ux-analysis.md, feature-analysis.md, cross-review.md, code-mapping.md
> **플랫폼**: iOS 17+, SwiftUI

---

## 1. 핵심 구현 포인트 (우선순위 순)

### P0 — 버그 수정 (블로커)
| # | 구현 포인트 | 파일 | 변경 규모 |
|---|------------|------|---------...
- 코드 매핑: # Code Mapping — 버그 수정 및 게임 화면 UI 개선

> **작성일**: 2026-04-10
> **기준 브랜치**: master (47f1a73)
> **분석 소스**: ui-analysis.md, ux-analysis.md, feature-analysis.md, cross-review.md + 소스코드 직접 역공학

---

## 분류 기...
- 분석 범위: UI + UX + 기능

## Spec 핵심 결정
- 요약: 빈 셀 탭 불가 버그 수정 및 게임 플레이 화면 UI를 Sudoku.com 스타일로 개선하는 품질 향상 작업. SudokuCellView·SudokuGridView·NumberPadView의 순수 뷰 레이어만 변경하며, 게임 로직(GameViewModel)은 무변경.
- 핵심 요구사항:
  - [필수] SudokuCellView ZStack에 .contentShape(Rectangle()) 수정자를 추가하여 value=0이고 notes가 비어있는 투명 배경 빈 셀도 탭 ...
  - [필수] SudokuCellView의 선택 셀 배경색을 현재 Color.blue.opacity(0.35)에서 Sudoku.com 스타일(더 선명한 파란색 계열)로 개선
  - [필수] SudokuCellView에 isSameNumber: Bool 파라미터를 추가하고, 선택 셀과 동일한 숫자를 가진 셀에 별도 배경색(단순 배경색)으로 하이라이트 표시
  - [필수] SudokuGridView에서 선택 셀의 value를 읽어 각 셀의 isSameNumber 여부를 계산한 뒤 SudokuCellView에 전달 (value=0인 빈 셀은 ...
  - [필수] NumberPadView의 버튼 스타일을 시각적으로 정돈 (배경색, 모서리, 폰트 등 Sudoku.com 스타일에 맞게 조정)
- 수용 기준:
  - 빈 셀(value=0, notes 없음)을 탭했을 때 selectedRow·selectedCol이 해당 셀로 설정됨
  - 이미 선택된 빈 셀을 다시 탭하면 선택이 해제됨 (기존 toggles 동작 유지)
  - 숫자가 입력된 셀을 선택했을 때, 보드 내 동일한 숫자를 가진 다른 셀들이 별도 배경색으로 표시됨
- 제외 범위: 홈 화면(HomeView) UI 리디자인, 게임 완료 화면 변경, 게임 기록/통계 화면 변경, 셀 선택·입력 애니메이션 추가, 힌트 기능 추가, 타이머 UI 변경, SudokuCell·SudokuBoard 모델 변경, GameViewModel 내 로직 변경
- 영향 범위: Sdoku/Views/Components/SudokuCellView.swift — isSameNumber 파라미터 추가, .contentShape(Rectangle()) 수정자 추가, backgroundColor 우선순위 조정, 색상 값 변경, Sdoku/Views/Components/SudokuGridView.swift — isSameNumber 계산 로직 추가, SudokuCellView 호출부에 파라미터 전달, Sdoku/Views/Components/NumberPadView.swift — 버튼 스타일(배경색·폰트·레이아웃) 조정

## Plan 핵심 결정
- 아키텍처 설계:
  - 데이터 모델: SudokuCellView 파라미터에 isSameNumber: Bool 추가 — 뷰 레이어에만 영향, SudokuCell 모델 구조체 무변경, isSameNumber는 SudokuGridView에서 선택 셀 value와 각 셀 value 비교로 파생 계산 — 별도 저장 상태(State/Published) 없음
  - 상태 관리: GameViewModel.selectedRow / selectedCol / board.cells를 SudokuGridView에서 기존과 동일하게 읽어 isSameNumber 파생 ...
  - 데이터 흐름: GameViewModel.board.cells[selectedRow][selectedCol].value → SudokuGridView.isSameNumber(row:col:) 에서...
  - 영향 파일: Sdoku/Sdoku/Views/Components/SudokuCellView.swift, Sdoku/Sdoku/Views/Components/SudokuGridView.swift, Sdoku/Sdoku/Views/Components/NumberPadView.swift
- 구현 요약: 빈 셀 탭 불가 버그 수정 및 게임 플레이 화면 UI를 Sudoku.com 스타일로 개선. SudokuCellView에 .contentShape(Rectangle()) 추가 및 isSameNumber 파라미터 도입, SudokuGridView에 동일 숫자 계산 로직 추가, NumberPadView 버튼 스타일 정돈. 총 3개 뷰 파일만 수정하며 GameVi...
- SubTask: 3개
- SubTask 목록:
  - 1. SudokuCellView: 빈 셀 탭 버그 수정 + isSameNumber 파라미터 추가 + 색상 개선
  - 2. SudokuGridView: isSameNumber 계산 로직 추가 및 SudokuCellView 호출부 업데이트
  - 3. NumberPadView: Sudoku.com 스타일 버튼 UI 개선
- 리스크: SudokuCellView isSameNumber 파라미터 추가 전 SudokuGridView 빌드 시도 시 컴파일 에러 — SubTask 0 완료 후 SubTask 1 순서 준수 필수, backgroundColor 우선순위 재정렬 시 isConflict가 isSameNumber보다 낮은 우선순위가 되지 않도록 주의 (isSelected > isSameNumber > isConflict 유지해야 충돌 셀이 숨겨지지 않음)
- 예상 소요: 45m

## Develop 결과
- 구현 상태: done
- 완료된 작업:
  - [SubTask 1 완료]
  - `SudokuCellView`에 `isSameNumber` 파라미터가 이미 추가되어 있음을 확인했습니다. 이제 `SudokuGridView`를 수정합니다.[SubTask 2 완료]
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