import Testing
@testable import Sdoku

struct PuzzleGeneratorTests {

    let sut = PuzzleGenerator()
    let validator = UniqueSolutionValidator()

    // MARK: - 기본 구조 검증

    @Test("생성된 퍼즐은 9×9 그리드를 가진다")
    func puzzleHas9x9Grid() {
        let puzzle = sut.generate(difficulty: .easy)

        #expect(puzzle.puzzle.count == 9)
        #expect(puzzle.puzzle.allSatisfy { $0.count == 9 })
    }

    @Test("생성된 정답은 9×9 그리드를 가진다")
    func solutionHas9x9Grid() {
        let puzzle = sut.generate(difficulty: .easy)

        #expect(puzzle.solution.count == 9)
        #expect(puzzle.solution.allSatisfy { $0.count == 9 })
    }

    @Test("반환된 난이도가 요청 난이도와 일치한다")
    func difficultyMatchesRequest() {
        for difficulty in Difficulty.allCases {
            let puzzle = sut.generate(difficulty: difficulty)
            #expect(puzzle.difficulty == difficulty)
        }
    }

    // MARK: - 정답 유효성 검증

    @Test("정답 그리드는 1~9만 포함한다")
    func solutionContainsOnlyValidNumbers() {
        let puzzle = sut.generate(difficulty: .easy)
        let allValues = puzzle.solution.flatMap { $0 }

        #expect(allValues.allSatisfy { (1...9).contains($0) })
    }

    @Test("정답 그리드에 빈 칸이 없다")
    func solutionHasNoEmptyCells() {
        let puzzle = sut.generate(difficulty: .easy)
        let allValues = puzzle.solution.flatMap { $0 }

        #expect(!allValues.contains(0))
    }

    @Test("정답 각 행은 1~9가 모두 포함된다")
    func solutionRowsContainAllDigits() {
        let puzzle = sut.generate(difficulty: .easy)

        for row in puzzle.solution {
            #expect(Set(row) == Set(1...9))
        }
    }

    @Test("정답 각 열은 1~9가 모두 포함된다")
    func solutionColumnsContainAllDigits() {
        let puzzle = sut.generate(difficulty: .easy)

        for col in 0..<9 {
            let column = (0..<9).map { puzzle.solution[$0][col] }
            #expect(Set(column) == Set(1...9))
        }
    }

    @Test("정답 각 3×3 박스는 1~9가 모두 포함된다")
    func solutionBoxesContainAllDigits() {
        let puzzle = sut.generate(difficulty: .easy)

        for boxRow in stride(from: 0, to: 9, by: 3) {
            for boxCol in stride(from: 0, to: 9, by: 3) {
                var values: [Int] = []
                for r in boxRow..<(boxRow + 3) {
                    for c in boxCol..<(boxCol + 3) {
                        values.append(puzzle.solution[r][c])
                    }
                }
                #expect(Set(values) == Set(1...9))
            }
        }
    }

    // MARK: - 퍼즐 그리드 검증

    @Test("퍼즐 그리드는 0과 1~9만 포함한다")
    func puzzleContainsOnlyValidValues() {
        let puzzle = sut.generate(difficulty: .easy)
        let allValues = puzzle.puzzle.flatMap { $0 }

        #expect(allValues.allSatisfy { (0...9).contains($0) })
    }

    @Test("퍼즐에 빈 칸(0)이 존재한다")
    func puzzleHasEmptyCells() {
        let puzzle = sut.generate(difficulty: .easy)
        let allValues = puzzle.puzzle.flatMap { $0 }

        #expect(allValues.contains(0))
    }

    @Test("퍼즐에 채워진 숫자는 정답과 일치한다")
    func puzzleGivensMatchSolution() {
        let puzzle = sut.generate(difficulty: .easy)

        for row in 0..<9 {
            for col in 0..<9 {
                let cell = puzzle.puzzle[row][col]
                if cell != 0 {
                    #expect(cell == puzzle.solution[row][col])
                }
            }
        }
    }

    // MARK: - givens 검증

    @Test("givens 값이 실제 채워진 셀 수와 일치한다")
    func givensCountMatchesActualFilledCells() {
        let puzzle = sut.generate(difficulty: .easy)
        let actualGivens = puzzle.puzzle.flatMap { $0 }.filter { $0 != 0 }.count

        #expect(puzzle.givens == actualGivens)
    }

    @Test("easy 난이도의 givens는 41~45 범위이다")
    func easyGivensInRange() {
        let puzzle = sut.generate(difficulty: .easy)
        // easy: 36~40개 제거 → givens = 81 - 제거수 = 41~45
        #expect((41...45).contains(puzzle.givens))
    }

    @Test("medium 난이도의 givens는 33~40 범위이다")
    func mediumGivensInRange() {
        let puzzle = sut.generate(difficulty: .medium)
        // medium: 41~48개 제거 → givens = 81 - 제거수 = 33~40
        #expect((33...40).contains(puzzle.givens))
    }

    @Test("hard 난이도의 givens는 27~32 범위이다")
    func hardGivensInRange() {
        let puzzle = sut.generate(difficulty: .hard)
        // hard: 49~54개 제거 → givens = 81 - 제거수 = 27~32
        #expect((27...32).contains(puzzle.givens))
    }

    @Test("extreme 난이도의 givens는 23~26 범위이다")
    func extremeGivensInRange() {
        let puzzle = sut.generate(difficulty: .extreme)
        // extreme: 55~58개 제거 → givens = 81 - 제거수 = 23~26
        #expect((23...26).contains(puzzle.givens))
    }

    // MARK: - 유일해 검증

    @Test("생성된 퍼즐은 유일해를 가진다")
    func puzzleHasUniqueSolution() {
        let puzzle = sut.generate(difficulty: .easy)

        #expect(validator.isUnique(puzzle.puzzle))
    }

    @Test("모든 난이도에서 유일해 퍼즐이 생성된다")
    func allDifficultiesProduceUniqueSolutionPuzzle() {
        for difficulty in Difficulty.allCases {
            let puzzle = sut.generate(difficulty: difficulty)
            #expect(validator.isUnique(puzzle.puzzle), "난이도 \(difficulty.rawValue)에서 유일해 실패")
        }
    }

    // MARK: - 랜덤성 검증

    @Test("같은 난이도로 두 번 생성한 퍼즐은 서로 다르다")
    func consecutivePuzzlesAreDifferent() {
        let first = sut.generate(difficulty: .easy)
        let second = sut.generate(difficulty: .easy)

        // 랜덤 생성이므로 두 퍼즐이 동일할 확률은 극히 낮음
        let firstFlat = first.puzzle.flatMap { $0 }
        let secondFlat = second.puzzle.flatMap { $0 }
        #expect(firstFlat != secondFlat)
    }
}
