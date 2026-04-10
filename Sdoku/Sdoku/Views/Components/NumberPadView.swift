import SwiftUI

/// 숫자 입력 패드: 1~9 숫자 버튼 + 지우기(X) 버튼 (3열 그리드)
struct NumberPadView: View {

    @Bindable var viewModel: GameViewModel

    /// 고정 셀 선택 시 전체 패드 비활성화 여부
    private var isDisabled: Bool {
        guard let row = viewModel.selectedRow,
              let col = viewModel.selectedCol else { return false }
        return viewModel.board.cells[row][col].isFixed
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

        LazyVGrid(columns: columns, spacing: 8) {
            // 1~9 숫자 버튼
            ForEach(1...9, id: \.self) { number in
                Button {
                    viewModel.inputNumber(number)
                } label: {
                    Text("\(number)")
                        .font(.system(size: 26, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.separator), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }

            // 지우기(X) 버튼
            Button {
                viewModel.clearCell()
            } label: {
                Image(systemName: "delete.left")
                    .font(.system(size: 22))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
        }
        .opacity(isDisabled ? 0.4 : 1.0)
        .disabled(isDisabled)
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview {
    NumberPadView(viewModel: GameViewModel())
}
