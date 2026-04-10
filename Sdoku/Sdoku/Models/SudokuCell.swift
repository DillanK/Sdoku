import Foundation

/// 스도쿠 그리드의 단일 셀 데이터
struct SudokuCell {
    /// 셀에 입력된 숫자 (0 = 빈 셀)
    var value: Int
    /// 초기 퍼즐에서 제공된 고정 셀 여부
    let isFixed: Bool
    /// 펜슬 모드에서 입력한 메모 숫자 집합 (1~9)
    var notes: Set<Int>
    /// 같은 행/열/박스에 동일 숫자가 존재하는 충돌 상태
    var isConflict: Bool

    init(value: Int = 0, isFixed: Bool = false, notes: Set<Int> = [], isConflict: Bool = false) {
        self.value = value
        self.isFixed = isFixed
        self.notes = notes
        self.isConflict = isConflict
    }
}
