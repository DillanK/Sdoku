//
//  GameRecordRepository.swift
//  Sdoku
//
//  Created by hyunjin on 4/9/26.
//

import CoreData

/// 난이도별 게임 통계 DTO
struct GameRecordStats {
    /// 완료 횟수
    let completedCount: Int
    /// 최단 소요 시간 (초). 완료 기록이 없으면 nil
    let bestTime: Int?
}

/// GameRecord CoreData CRUD 및 통계 조회 서비스
final class GameRecordRepository {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    /// 게임 기록 저장
    func save(difficulty: Difficulty, elapsedSeconds: Int64, isCompleted: Bool) throws {
        let record = GameRecord(context: context)
        record.difficulty = difficulty.rawValue
        record.elapsedSeconds = elapsedSeconds
        record.completedAt = Date()
        record.isCompleted = isCompleted
        try context.save()
    }

    /// 특정 난이도의 통계 조회
    func fetchStats(for difficulty: Difficulty) throws -> GameRecordStats {
        // 완료 횟수 조회
        let countRequest = GameRecord.fetchRequest()
        countRequest.predicate = NSPredicate(
            format: "difficulty == %@ AND isCompleted == YES",
            difficulty.rawValue
        )
        let completedCount = try context.count(for: countRequest)

        // 최단 기록 조회
        let bestRequest = GameRecord.fetchRequest()
        bestRequest.predicate = NSPredicate(
            format: "difficulty == %@ AND isCompleted == YES",
            difficulty.rawValue
        )
        bestRequest.sortDescriptors = [NSSortDescriptor(key: "elapsedSeconds", ascending: true)]
        bestRequest.fetchLimit = 1
        let results = try context.fetch(bestRequest)
        let bestTime = results.first.map { Int($0.elapsedSeconds) }

        return GameRecordStats(completedCount: completedCount, bestTime: bestTime)
    }
}
