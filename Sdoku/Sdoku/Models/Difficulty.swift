import Foundation

/// 스도쿠 퍼즐 난이도
enum Difficulty: String, CaseIterable {
    case easy
    case medium
    case hard
    case extreme

    /// 난이도별 제거할 셀 수 범위
    var removalRange: ClosedRange<Int> {
        switch self {
        case .easy:    return 36...40
        case .medium:  return 41...48
        case .hard:    return 49...54
        case .extreme: return 55...58
        }
    }

    /// UI 표시용 이름
    var displayName: String {
        switch self {
        case .easy:    return "쉬움"
        case .medium:  return "보통"
        case .hard:    return "어려움"
        case .extreme: return "극악"
        }
    }
}
