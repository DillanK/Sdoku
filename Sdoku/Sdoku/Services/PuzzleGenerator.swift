import Foundation

/// 난이도별 스도쿠 퍼즐을 생성하는 공개 API
struct PuzzleGenerator {

    private let gridGenerator = GridGenerator()
    private let validator = UniqueSolutionValidator()

    /// 주어진 난이도의 스도쿠 퍼즐 생성
    /// - Parameter difficulty: 원하는 난이도
    /// - Returns: 완성된 SudokuPuzzle (puzzle, solution, difficulty, givens 포함)
    func generate(difficulty: Difficulty) -> SudokuPuzzle {
        let removalCount = Int.random(in: difficulty.removalRange)

        // 유일해를 만족하는 퍼즐이 생성될 때까지 반복
        // 극악 난이도는 유일해 찾기가 어려워 그리드를 재생성하며 시도
        while true {
            let solution = gridGenerator.generateCompleteGrid()
            if let puzzle = removeCells(from: solution, count: removalCount) {
                let givens = puzzle.flatMap { $0 }.filter { $0 != 0 }.count
                return SudokuPuzzle(
                    puzzle: puzzle,
                    solution: solution,
                    difficulty: difficulty,
                    givens: givens
                )
            }
            // 유일해 만족 실패 → 새 그리드로 재시도
        }
    }

    // MARK: - Private

    /// 완성 그리드에서 목표 수만큼 셀을 제거하고 유일해를 만족하는 퍼즐 반환
    /// - Parameters:
    ///   - solution: 완성 그리드
    ///   - count: 제거할 셀 수
    /// - Returns: 유일해를 만족하는 퍼즐 그리드, 목표 달성 실패 시 nil
    private func removeCells(from solution: [[Int]], count: Int) -> [[Int]]? {
        var puzzle = solution
        // 81개 위치를 랜덤 셔플하여 제거 순서를 무작위로 설정
        var positions = (0..<81).map { ($0 / 9, $0 % 9) }.shuffled()
        var removed = 0

        while removed < count, !positions.isEmpty {
            let (row, col) = positions.removeFirst()

            // 이미 빈 칸이면 건너뜀
            guard puzzle[row][col] != 0 else { continue }

            let backup = puzzle[row][col]
            puzzle[row][col] = 0

            if validator.isUnique(puzzle) {
                // 유일해 유지 → 제거 확정
                removed += 1
            } else {
                // 유일해 깨짐 → 복원
                puzzle[row][col] = backup
            }
        }

        // 목표 제거 수에 도달하지 못했으면 nil 반환 (그리드 재생성 필요)
        return removed == count ? puzzle : nil
    }
}
