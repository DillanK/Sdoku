//
//  Difficulty.swift
//  Sdoku
//
//  Created by hyunjin on 4/9/26.
//

import Foundation

/// 스도쿠 난이도 단계
enum Difficulty: String, CaseIterable, Codable {
    case easy = "easy"
    case normal = "normal"
    case hard = "hard"
    case extreme = "extreme"

    /// 화면에 표시할 이름
    var displayName: String {
        switch self {
        case .easy: return "쉬움"
        case .normal: return "보통"
        case .hard: return "어려움"
        case .extreme: return "극악"
        }
    }

    /// 정렬 순서 (낮을수록 쉬움)
    var sortOrder: Int {
        switch self {
        case .easy: return 0
        case .normal: return 1
        case .hard: return 2
        case .extreme: return 3
        }
    }

    /// 난이도별 제거할 셀 수 범위 (퍼즐 생성 시 사용)
    var removalRange: ClosedRange<Int> {
        switch self {
        case .easy:    return 36...40
        case .normal:  return 41...48
        case .hard:    return 49...54
        case .extreme: return 55...58
        }
    }
}
