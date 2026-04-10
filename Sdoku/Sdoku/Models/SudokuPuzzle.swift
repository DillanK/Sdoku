import Foundation

/// 스도쿠 퍼즐 데이터 모델
/// - puzzle: 사용자에게 보여지는 초기 상태 (0 = 빈 셀)
/// - solution: 완성된 정답 그리드
/// - difficulty: 퍼즐 난이도
/// - givens: 초기에 채워진 셀 수
struct SudokuPuzzle {
    let puzzle: [[Int]]
    let solution: [[Int]]
    let difficulty: Difficulty
    let givens: Int
}
