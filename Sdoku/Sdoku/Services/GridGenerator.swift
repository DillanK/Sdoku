import Foundation

/// 백트래킹 알고리즘으로 유효한 9×9 완성 스도쿠 그리드를 생성하는 내부 모듈
struct GridGenerator {

    /// 완성된 9×9 스도쿠 그리드 생성
    /// - Returns: 1~9로 채워진 유효한 스도쿠 그리드
    func generateCompleteGrid() -> [[Int]] {
        var grid = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        _ = fill(&grid, at: 0)
        return grid
    }

    // MARK: - Private

    /// 백트래킹으로 그리드를 채움
    /// - Parameters:
    ///   - grid: 채울 그리드 (in-out)
    ///   - pos: 현재 위치 (0~80)
    /// - Returns: 성공 여부
    private func fill(_ grid: inout [[Int]], at pos: Int) -> Bool {
        // 모든 셀을 채웠으면 완성
        if pos == 81 { return true }

        let row = pos / 9
        let col = pos % 9

        // 후보 숫자를 랜덤 셔플하여 매번 다른 퍼즐 생성
        let candidates = (1...9).shuffled()

        for num in candidates {
            if isValid(grid, row: row, col: col, num: num) {
                grid[row][col] = num
                if fill(&grid, at: pos + 1) {
                    return true
                }
                grid[row][col] = 0
            }
        }

        return false
    }

    /// 해당 위치에 숫자를 놓을 수 있는지 검사 (행·열·박스)
    private func isValid(_ grid: [[Int]], row: Int, col: Int, num: Int) -> Bool {
        // 행 검사
        if grid[row].contains(num) { return false }

        // 열 검사
        for r in 0..<9 {
            if grid[r][col] == num { return false }
        }

        // 3×3 박스 검사
        let boxRow = (row / 3) * 3
        let boxCol = (col / 3) * 3
        for r in boxRow..<(boxRow + 3) {
            for c in boxCol..<(boxCol + 3) {
                if grid[r][c] == num { return false }
            }
        }

        return true
    }
}
