//
//  GameRecordRepositoryTests.swift
//  SdokuTests
//
//  Created by hyunjin on 4/9/26.
//

import Testing
import CoreData
@testable import Sdoku

@Suite("GameRecordRepository Tests", .serialized)
struct GameRecordRepositoryTests {

    /// 인메모리 컨텍스트로 초기화된 Repository 반환
    private func makeRepository() -> (GameRecordRepository, NSManagedObjectContext) {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let repo = GameRecordRepository(context: context)
        return (repo, context)
    }

    // MARK: - save

    @Test func save_완료기록_저장후_completedCount_증가() throws {
        let (repo, _) = makeRepository()

        try repo.save(difficulty: .easy, elapsedSeconds: 120, isCompleted: true)
        let stats = try repo.fetchStats(for: .easy)

        #expect(stats.completedCount == 1)
    }

    @Test func save_미완료기록_completedCount에_포함안됨() throws {
        let (repo, _) = makeRepository()

        try repo.save(difficulty: .easy, elapsedSeconds: 300, isCompleted: false)
        let stats = try repo.fetchStats(for: .easy)

        #expect(stats.completedCount == 0)
    }

    @Test func save_여러_완료기록_completedCount_정확히_집계() throws {
        let (repo, _) = makeRepository()

        try repo.save(difficulty: .normal, elapsedSeconds: 200, isCompleted: true)
        try repo.save(difficulty: .normal, elapsedSeconds: 180, isCompleted: true)
        try repo.save(difficulty: .normal, elapsedSeconds: 250, isCompleted: false)
        let stats = try repo.fetchStats(for: .normal)

        #expect(stats.completedCount == 2)
    }

    // MARK: - fetchStats bestTime

    @Test func fetchStats_완료기록없으면_bestTime이_nil() throws {
        let (repo, _) = makeRepository()

        let stats = try repo.fetchStats(for: .hard)

        #expect(stats.bestTime == nil)
    }

    @Test func fetchStats_단일_완료기록_bestTime_반환() throws {
        let (repo, _) = makeRepository()

        try repo.save(difficulty: .hard, elapsedSeconds: 500, isCompleted: true)
        let stats = try repo.fetchStats(for: .hard)

        #expect(stats.bestTime == 500)
    }

    @Test func fetchStats_여러_완료기록중_최단시간_반환() throws {
        let (repo, _) = makeRepository()

        try repo.save(difficulty: .extreme, elapsedSeconds: 900, isCompleted: true)
        try repo.save(difficulty: .extreme, elapsedSeconds: 600, isCompleted: true)
        try repo.save(difficulty: .extreme, elapsedSeconds: 750, isCompleted: true)
        let stats = try repo.fetchStats(for: .extreme)

        #expect(stats.bestTime == 600)
    }

    @Test func fetchStats_미완료기록은_bestTime에_포함안됨() throws {
        let (repo, _) = makeRepository()

        try repo.save(difficulty: .easy, elapsedSeconds: 50, isCompleted: false)
        try repo.save(difficulty: .easy, elapsedSeconds: 200, isCompleted: true)
        let stats = try repo.fetchStats(for: .easy)

        // 미완료 50초는 무시, 완료 200초가 bestTime
        #expect(stats.bestTime == 200)
    }

    // MARK: - 난이도 격리

    @Test func fetchStats_다른난이도_기록은_영향없음() throws {
        let (repo, _) = makeRepository()

        try repo.save(difficulty: .easy, elapsedSeconds: 100, isCompleted: true)
        try repo.save(difficulty: .hard, elapsedSeconds: 800, isCompleted: true)
        let easyStats = try repo.fetchStats(for: .easy)
        let hardStats = try repo.fetchStats(for: .hard)

        #expect(easyStats.completedCount == 1)
        #expect(easyStats.bestTime == 100)
        #expect(hardStats.completedCount == 1)
        #expect(hardStats.bestTime == 800)
    }

    @Test func fetchStats_기록없는_난이도는_빈통계() throws {
        let (repo, _) = makeRepository()

        try repo.save(difficulty: .easy, elapsedSeconds: 100, isCompleted: true)
        let stats = try repo.fetchStats(for: .normal)

        #expect(stats.completedCount == 0)
        #expect(stats.bestTime == nil)
    }
}
