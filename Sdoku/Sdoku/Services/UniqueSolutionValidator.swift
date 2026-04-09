import Foundation

/// 스도쿠 퍼즐에 정확히 하나의 해답만 존재하는지 검증하는 내부 모듈
struct UniqueSolutionValidator {

    /// 퍼즐이 유일해를 가지는지 확인
    /// - Parameter grid: 0이 빈 칸인 9×9 그리드
    /// - Returns: 해답이 정확히 1개면 true
    func isUnique(_ grid: [[Int]]) -> Bool {
        countSolutions(grid, limit: 2) == 1
    }

    /// 최대 limit개까지 해의 수를 세고, limit개 발견 즉시 조기 종료
    /// - Parameters:
    ///   - grid: 0이 빈 칸인 9×9 그리드
    ///   - limit: 탐색 중단 기준 (이 수에 도달하면 즉시 반환)
    /// - Returns: 발견된 해의 수 (최대 limit)
    func countSolutions(_ grid: [[Int]], limit: Int) -> Int {
        var grid = grid
        var count = 0
        solve(&grid, count: &count, limit: limit)
        return count
    }

    // MARK: - Private

    /// 백트래킹으로 해의 수를 셈 (count가 limit에 도달하면 즉시 중단)
    @discardableResult
    private func solve(_ grid: inout [[Int]], count: inout Int, limit: Int) -> Bool {
        // 빈 칸 탐색
        guard let (row, col) = findEmpty(grid) else {
            // 빈 칸 없음 = 해 하나 발견
            count += 1
            return count >= limit
        }

        for num in 1...9 {
            if isValid(grid, row: row, col: col, num: num) {
                grid[row][col] = num
                if solve(&grid, count: &count, limit: limit) {
                    // limit에 도달 → 조기 종료
                    grid[row][col] = 0
                    return true
                }
                grid[row][col] = 0
            }
        }

        return false
    }

    /// 첫 번째 빈 칸(0인 셀) 위치 반환
    private func findEmpty(_ grid: [[Int]]) -> (Int, Int)? {
        for row in 0..<9 {
            for col in 0..<9 {
                if grid[row][col] == 0 { return (row, col) }
            }
        }
        return nil
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
