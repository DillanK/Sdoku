---
generatedAt: 2026-04-09T07:47:19Z
gitHead: 
sourceModified: 2026-04-09T07:39:12Z
trigger: auto
---
# Codebase Digest

## Project Overview
Sdoku is an iOS Sudoku application built with Swift and SwiftUI, using CoreData for persistence. The project is in early/scaffold stage with minimal implementation and no git commits yet.

## Core Types & Roles
| Type | Kind | Role |
|------|------|------|
| SdokuApp | struct | SwiftUI app entry point |
| ContentView | struct | Root SwiftUI view |
| PersistenceController | struct | CoreData stack management |
| SdokuTests | struct | Unit test suite |

## Service Dependencies
- `ContentView` depends on `PersistenceController` for CoreData managed object context
- `SdokuApp` depends on `PersistenceController` for app-wide persistence setup
- `SdokuTests` depends on `PersistenceController` (in-memory store) for isolated test data

## File Roles
| Path Pattern | Role |
|-------------|------|
| `Sdoku/Sdoku/` | Main app source (SwiftUI views, app entry, CoreData model) |
| `Sdoku/SdokuTests/` | Unit tests |
| `Sdoku/SdokuUITests/` | UI tests |
| `Sdoku/Sdoku.xcodeproj/` | Xcode project configuration |
| `.auto-claude/` | AI-assisted dev metadata (specs, roadmap, kanban, memory) |
| `.autoai/` | AI feature planning and spark notes |
| `NewProject/` | Separate scaffolded project (unused/exploratory) |

## Directory Structure
```
./NewProject
./NewProject/.auto-claude
./NewProject/.git
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
./.auto-claude/stage-context
./.git
```

## Recent Commits
```

```