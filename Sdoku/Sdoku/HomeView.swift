//
//  HomeView.swift
//  Sdoku
//
//  Created by hyunjin on 4/9/26.
//

import SwiftUI
import CoreData

/// 홈 화면 — 난이도 선택 및 난이도별 통계 표시
struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var viewModel: HomeViewModel

    init(viewModel: HomeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Sdoku")
                    .font(.largeTitle)
                    .bold()
                    .padding(.top, 40)

                VStack(spacing: 16) {
                    ForEach(Difficulty.allCases.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.self) { difficulty in
                        DifficultyRowView(
                            difficulty: difficulty,
                            stats: viewModel.stats[difficulty]
                        ) {
                            viewModel.selectedDifficulty = difficulty
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .navigationDestination(item: $viewModel.selectedDifficulty) { difficulty in
                // 게임 플레이 화면 — 게임 플레이 Feature 완료 후 연결
                Text("게임 화면: \(difficulty.displayName)")
                    .navigationTitle(difficulty.displayName)
            }
            .onAppear {
                viewModel.refresh()
            }
        }
    }
}

/// 난이도 선택 행 — 버튼 + 통계 요약
private struct DifficultyRowView: View {
    let difficulty: Difficulty
    let stats: GameRecordStats?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(difficulty.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 12) {
                        // 완료 횟수
                        Label(
                            "\(stats?.completedCount ?? 0)회 완료",
                            systemImage: "checkmark.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        // 최고 기록
                        if let bestTime = stats?.bestTime {
                            Label(
                                formattedTime(bestTime),
                                systemImage: "clock"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        } else {
                            Label("기록 없음", systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    /// 초를 mm:ss 형식으로 변환
    private func formattedTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

#Preview {
    let controller = PersistenceController.preview
    let repo = GameRecordRepository(context: controller.container.viewContext)
    let vm = HomeViewModel(repository: repo)
    HomeView(viewModel: vm)
        .environment(\.managedObjectContext, controller.container.viewContext)
}
