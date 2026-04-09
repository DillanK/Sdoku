import SwiftUI
import UIKit

/// 게임 컨트롤 버튼 모음: Pencil Mark 토글 + Undo
struct GameControlsView: View {

    @Bindable var viewModel: GameViewModel

    var body: some View {
        HStack(spacing: 24) {
            // 펜슬 모드 토글 버튼
            Button {
                viewModel.togglePencilMode()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                        .font(.system(size: 18))
                    Text("메모")
                        .font(.system(size: 15, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    viewModel.isPencilMode
                        ? Color.accentColor.opacity(0.15)
                        : Color(.secondarySystemBackground)
                )
                .foregroundColor(viewModel.isPencilMode ? .accentColor : .primary)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            viewModel.isPencilMode ? Color.accentColor : Color.clear,
                            lineWidth: 1.5
                        )
                )
            }
            .buttonStyle(.plain)

            // 실행 취소 버튼
            Button {
                viewModel.undo()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 18))
                    Text("되돌리기")
                        .font(.system(size: 15, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .foregroundColor(viewModel.canUndo ? .primary : .secondary)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canUndo)
        }
    }
}

// MARK: - Preview

#Preview {
    GameControlsView(viewModel: GameViewModel())
}
