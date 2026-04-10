//
//  HomeViewModel.swift
//  Sdoku
//
//  Created by hyunjin on 4/9/26.
//

import Observation

/// 홈 화면 상태 관리 — 난이도별 통계 로드 및 게임 시작 트리거
@Observable
final class HomeViewModel {
    /// 난이도별 통계 캐시
    private(set) var stats: [Difficulty: GameRecordStats] = [:]
    /// 선택된 난이도 — NavigationStack destination 트리거
    var selectedDifficulty: Difficulty?

    private let repository: GameRecordRepository

    init(repository: GameRecordRepository) {
        self.repository = repository
    }

    /// 모든 난이도의 통계를 갱신
    func refresh() {
        var updated: [Difficulty: GameRecordStats] = [:]
        for difficulty in Difficulty.allCases {
            // 조회 실패 시 빈 통계로 대체
            let s = (try? repository.fetchStats(for: difficulty))
                ?? GameRecordStats(completedCount: 0, bestTime: nil)
            updated[difficulty] = s
        }
        stats = updated
    }

    /// 게임 기록 저장 후 통계 갱신
    func recordGame(difficulty: Difficulty, elapsedSeconds: Int64, isCompleted: Bool) {
        try? repository.save(difficulty: difficulty, elapsedSeconds: elapsedSeconds, isCompleted: isCompleted)
        refresh()
    }
}
