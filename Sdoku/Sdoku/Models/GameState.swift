import Foundation

/// Undo 스택에 저장되는 단일 액션 스냅샷
struct UndoEntry {
    /// 액션 이전의 보드 상태
    let board: SudokuBoard
    /// 액션 이전의 선택 셀 위치
    let selectedRow: Int?
    let selectedCol: Int?
}

/// 게임 플레이의 최상위 상태
struct GameState {
    /// 현재 보드
    var board: SudokuBoard
    /// 선택된 셀의 행 인덱스 (nil = 선택 없음)
    var selectedRow: Int?
    /// 선택된 셀의 열 인덱스 (nil = 선택 없음)
    var selectedCol: Int?
    /// 펜슬(메모) 모드 활성 여부
    var isPencilMode: Bool
    /// Undo 히스토리 스택
    var undoStack: [UndoEntry]

    init(
        board: SudokuBoard = .empty(),
        selectedRow: Int? = nil,
        selectedCol: Int? = nil,
        isPencilMode: Bool = false,
        undoStack: [UndoEntry] = []
    ) {
        self.board = board
        self.selectedRow = selectedRow
        self.selectedCol = selectedCol
        self.isPencilMode = isPencilMode
        self.undoStack = undoStack
    }

    // MARK: - Undo 지원

    /// 현재 상태를 Undo 스택에 저장
    mutating func pushUndo() {
        let entry = UndoEntry(board: board, selectedRow: selectedRow, selectedCol: selectedCol)
        undoStack.append(entry)
    }

    /// Undo 스택에서 이전 상태 복원. 스택이 비어 있으면 아무 동작 안 함
    mutating func undo() {
        guard let entry = undoStack.popLast() else { return }
        board = entry.board
        selectedRow = entry.selectedRow
        selectedCol = entry.selectedCol
    }

    var canUndo: Bool { !undoStack.isEmpty }
}
