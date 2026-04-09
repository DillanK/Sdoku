import Foundation

/// 9x9 스도쿠 보드 및 충돌 감지
struct SudokuBoard {
    /// 9x9 셀 배열 [행][열]
    var cells: [[SudokuCell]]

    init(cells: [[SudokuCell]]) {
        self.cells = cells
    }

    // MARK: - 충돌 감지

    /// 보드 전체 충돌 상태를 재계산하여 반환
    func detectingConflicts() -> SudokuBoard {
        var updated = self
        for row in 0..<9 {
            for col in 0..<9 {
                updated.cells[row][col].isConflict = isConflicting(row: row, col: col)
            }
        }
        return updated
    }

    /// 특정 셀이 충돌 상태인지 확인 (행/열/3x3 박스 내 중복)
    private func isConflicting(row: Int, col: Int) -> Bool {
        let value = cells[row][col].value
        guard value != 0 else { return false }

        // 행 검사
        for c in 0..<9 where c != col {
            if cells[row][c].value == value { return true }
        }

        // 열 검사
        for r in 0..<9 where r != row {
            if cells[r][col].value == value { return true }
        }

        // 3x3 박스 검사
        let boxRowStart = (row / 3) * 3
        let boxColStart = (col / 3) * 3
        for r in boxRowStart..<(boxRowStart + 3) {
            for c in boxColStart..<(boxColStart + 3) where !(r == row && c == col) {
                if cells[r][c].value == value { return true }
            }
        }

        return false
    }

    // MARK: - Mock 데이터

    /// 개발/프리뷰용 빈 보드
    static func empty() -> SudokuBoard {
        let emptyRow = Array(repeating: SudokuCell(), count: 9)
        return SudokuBoard(cells: Array(repeating: emptyRow, count: 9))
    }

    /// 개발/프리뷰용 샘플 보드 (유효한 스도쿠 퍼즐 일부 채움)
    static func mock() -> SudokuBoard {
        // 잘 알려진 스도쿠 퍼즐 (0 = 빈 셀)
        let grid: [[Int]] = [
            [5, 3, 0, 0, 7, 0, 0, 0, 0],
            [6, 0, 0, 1, 9, 5, 0, 0, 0],
            [0, 9, 8, 0, 0, 0, 0, 6, 0],
            [8, 0, 0, 0, 6, 0, 0, 0, 3],
            [4, 0, 0, 8, 0, 3, 0, 0, 1],
            [7, 0, 0, 0, 2, 0, 0, 0, 6],
            [0, 6, 0, 0, 0, 0, 2, 8, 0],
            [0, 0, 0, 4, 1, 9, 0, 0, 5],
            [0, 0, 0, 0, 8, 0, 0, 7, 9],
        ]

        let cells = grid.map { row in
            row.map { value in
                SudokuCell(value: value, isFixed: value != 0)
            }
        }
        return SudokuBoard(cells: cells)
    }
}
