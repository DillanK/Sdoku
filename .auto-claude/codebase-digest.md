---
generatedAt: 2026-04-10T07:51:10Z
gitHead: b17c88b
sourceModified: 2026-04-10T07:50:52Z
trigger: auto
---
# Codebase Digest

## Project Overview
Sdoku is an iOS Sudoku puzzle game built with SwiftUI. It features puzzle generation, validation, and game state management with multiple difficulty levels. The tech stack is Swift + SwiftUI with Core Data for persistence.

## Core Types & Roles
| Type | Kind | Role |
|------|------|------|
| SdokuApp | struct | App entry point |
| HomeView | struct | Main menu screen with difficulty selection |
| GameView | struct | Primary game screen, orchestrates gameplay |
| GameState | struct | Core game state: board, selection, moves, timer |
| SudokuBoard | struct | 9x9 board model with cell access and validation |
| SudokuCell | struct | Single cell model: value, notes, fixed flag |
| SudokuPuzzle | struct | Puzzle container with solution and metadata |
| SudokuGridView | struct | SwiftUI grid rendering of the board |
| SudokuCellView | struct | Individual cell view with highlight/selection states |
| NumberPadView | struct | Number input pad (Sudoku.com-style UI) |
| GameControlsView | struct | Game action buttons (undo, erase, notes, etc.) |
| PuzzleGenerator | struct | Generates valid Sudoku puzzles by difficulty |
| GridGenerator | struct | Low-level grid filling with backtracking |
| UniqueSolutionValidator | struct | Verifies puzzles have exactly one solution |
| Difficulty | enum | Easy/Medium/Hard/Expert difficulty levels |
| UndoEntry | struct | Snapshot for undo history |
| GameRecordStats | struct | Aggregated stats for completed games |
| PersistenceController | struct | Core Data stack setup and shared instance |
| ContentView | struct | Root navigation container |

## Service Dependencies
- `GameView` depends on `GameState` for all game logic and board state
- `GameState` depends on `SudokuBoard` and `SudokuPuzzle` for puzzle data
- `SudokuGridView` depends on `GameState` and renders `SudokuCellView` per cell
- `NumberPadView` and `GameControlsView` depend on `GameState` via binding/callback
- `GameView` depends on `PuzzleGenerator` to create new puzzles on start
- `PuzzleGenerator` depends on `GridGenerator` for board filling and `UniqueSolutionValidator` for solution verification
- `PersistenceController` provides Core Data context to views for `GameRecordStats` persistence

## File Roles
| Path Pattern | Role |
|-------------|------|
| `Sdoku/Sdoku/*.swift` | Main app source: models, views, view models, generators |
| `Sdoku/Sdoku/Views/` | SwiftUI view files (Grid, Cell, NumberPad, Controls, Game, Home) |
| `Sdoku/Sdoku/Models/` | Data models: SudokuBoard, SudokuCell, SudokuPuzzle, GameState |
| `Sdoku/Sdoku/Generators/` | Puzzle and grid generation logic |
| `Sdoku/SdokuTests/` | Unit tests for puzzle generation, validation, game records |
| `Sdoku/SdokuUITests/` | UI integration tests |
| `.auto-claude/` | AI-assisted dev metadata: features, specs, kanban, memory |
| `.autoai/` | Feature tracking and spark/conversation logs |

## Directory Structure
```
./Sdoku
./Sdoku/Sdoku
./Sdoku/Sdoku.xcodeproj
./Sdoku/SdokuUITests
./Sdoku/SdokuTests
./.autoai
./.autoai/features
./.autoai/sparks
./.auto-claude
./.auto-claude/memory
./.auto-claude/roadmap
./.auto-claude/specs
./.auto-claude/features
./.auto-claude/logs
./.auto-claude/kanban
./.auto-claude/skills
./.auto-claude/guidelines
./.auto-claude/stage-context
./.git
```

## Recent Commits
```
b17c88b Develop: 버그 수정 및 UI 변경 완료
7e1960a SubTask #3: NumberPadView: Sudoku.com 스타일 버튼 UI 개선
483ccce SubTask #2: SudokuGridView: isSameNumber 계산 로직 추가 및 SudokuCellView 호출부 업데이트
df57e28 SubTask #1: SudokuCellView: 빈 셀 탭 버그 수정 + isSameNumber 파라미터 추가 + 색상 개선
47f1a73 스도쿠 기능 연동
39778ee Merge branch 'develop-5ed14057': 퍼즐 생성/검증기
d657c10 Merge branch 'develop-42cd1342': 모델/뷰모델/컨트롤 뷰
d66540a chore: add PuzzleGenerator and tests
c3bbdbd chore: remove unused UIKit imports and add ContentView
57ff6c8 chore: update FEATURES_INDEX timestamp
```