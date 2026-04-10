import SwiftUI

/// 게임 메인 화면: 그리드 + 컨트롤 + 숫자 패드
struct GameView: View {

    @State private var viewModel = GameViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("스도쿠")
                .font(.largeTitle.bold())
                .padding(.top)

            SudokuGridView(viewModel: viewModel)
                .padding(.horizontal)

            GameControlsView(viewModel: viewModel)

            NumberPadView(viewModel: viewModel)
                .padding(.bottom)
        }
    }
}

// MARK: - Preview

#Preview {
    GameView()
}
