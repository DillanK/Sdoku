---
generatedAt: 2026-04-10T06:26:56Z
gitHead: 39778ee
sourceModified: 2026-04-10T05:37:39Z
trigger: auto
---
# Codebase Digest

## Project Overview
Sdoku is a native iOS Sudoku puzzle game built with SwiftUI. It provides puzzle generation with difficulty levels, unique-solution validation, and a full game-play UI with undo and number pad controls. The tech stack is Swift + SwiftUI, targeting iOS/macOS via Xcode.

## Core Types & Roles
| Type | Kind | Role |
|------|------|------|
| `SdokuApp` | struct | App entry point |
| `HomeView` | struct | Main menu / difficulty selection screen |
| `GameView` | struct | Primary game-play screen coordinating all sub-views |
| `SudokuGridView` | struct | Renders the 9×9 Sudoku board grid |
| `SudokuCellView` | struct | Renders a single cell with selection/error highlighting |
| `NumberPadView` | struct | Input pad for selecting digits 1–9 |
| `GameControlsView` | struct | Undo, erase, and other in-game action buttons |
| `ContentView` | struct | Root navigation container view |
| `GameState` | struct | Holds all mutable game state (board, selection, timer, etc.) |
| `SudokuBoard` | struct | Value-type model of the 9×9 board and cell values |
| `SudokuCell` | struct | Single cell model (value, isGiven, isError flags) |
| `SudokuPuzzle` | struct | Bundled puzzle: clues + solution |
| `UndoEntry` | struct | Snapshot for a single undoable move |
| `PuzzleGenerator` | struct | Orchestrates grid generation and clue removal to produce a puzzle |
| `GridGenerator` | struct | Backtracking algorithm that fills a complete valid grid |
| `UniqueSolutionValidator` | struct | Verifies a partially-filled board has exactly one solution |
| `Difficulty` | enum | Easy / Medium / Hard levels with clue-count parameters |
| `GameRecordStats` | struct | Aggregated statistics for completed games |
| `PersistenceController` | struct | Core Data stack setup and shared store access |
| `GameRecordRepositoryTests` | struct | Tests for game record persistence logic |

## Service Dependencies
- `GameView` depends on `GameState` for all live game state and move dispatch
- `GameState` depends on `SudokuBoard` and `SudokuPuzzle` to initialize and mutate the board
- `PuzzleGenerator` depends on `GridGenerator` to produce a solved grid, then on `UniqueSolutionValidator` to ensure clue removal keeps a unique solution
- `SudokuGridView` depends on `SudokuBoard` / `SudokuCell` for display data, and on `GameState` for selection state
- `NumberPadView` and `GameControlsView` dispatch user actions back to `GameState`
- `PersistenceController` provides the Core Data context consumed by game record repository logic
- `HomeView` depends on `Difficulty` to pass the chosen level into `GameView`

## File Roles
| Path Pattern | Role |
|-------------|------|
| `Sdoku/Sdoku/SdokuApp.swift` | App entry point and scene setup |
| `Sdoku/Sdoku/Views/` | All SwiftUI view structs (GameView, HomeView, GridView, CellView, Pads) |
| `Sdoku/Sdoku/Models/` | Pure value-type models: SudokuBoard, SudokuCell, SudokuPuzzle, UndoEntry |
| `Sdoku/Sdoku/Difficulty.swift` | Difficulty enum (merged out of Models/ into root source dir) |
| `Sdoku/Sdoku/PuzzleGenerator.swift` | Puzzle generation pipeline (GridGenerator + validator) |
| `Sdoku/Sdoku/Persistence.swift` | Core Data stack (PersistenceController) |
| `Sdoku/SdokuTests/` | Unit tests for puzzle generation and game record repository |
| `Sdoku/SdokuUITests/` | UI/integration test targets |
| `Sdoku/Sdoku.xcodeproj/` | Xcode project and workspace configuration |
| `.auto-claude/` | AI-assisted development metadata: specs, kanban, memory, feature tracking |

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
39778ee Merge branch 'develop-5ed14057': 퍼즐 생성/검증기
d657c10 Merge branch 'develop-42cd1342': 모델/뷰모델/컨트롤 뷰
d66540a chore: add PuzzleGenerator and tests
c3bbdbd chore: remove unused UIKit imports and add ContentView
57ff6c8 chore: update FEATURES_INDEX timestamp
85d9d66 게임 플레이 화면 & 상태 관리 화면
54e6f59 SubTask #4: 컨트롤 컴포넌트: NumberPadView, GameControlsView
fda4899 SubTask #3: UniqueSolutionValidator — 유일해 검증기
384e298 SubTask #2: GridGenerator — 백트래킹 완성 그리드 생성기
e135da7 SubTask #2: GameViewModel: 게임 로직 및 상태 관리
```