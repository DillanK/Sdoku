import SwiftUI

/// 9x9 스도쿠 그리드 뷰
/// - 3x3 박스 경계: 굵은 선 (lineWidth 2.5)
/// - 셀 내부 경계: 얇은 선 (lineWidth 0.5)
struct SudokuGridView: View {

    @State var viewModel: GameViewModel

    var body: some View {
        GeometryReader { geo in
            let gridSize = min(geo.size.width, geo.size.height)
            let cellSize = gridSize / 9

            ZStack {
                // 셀 그리드
                VStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<9, id: \.self) { col in
                                SudokuCellView(
                                    cell: viewModel.board.cells[row][col],
                                    isSelected: viewModel.selectedRow == row && viewModel.selectedCol == col,
                                    isRelated: isRelated(row: row, col: col),
                                    isSameNumber: isSameNumber(row: row, col: col)
                                )
                                .frame(width: cellSize, height: cellSize)
                                .onTapGesture {
                                    viewModel.selectCell(row: row, col: col)
                                }
                            }
                        }
                    }
                }

                // 경계선 오버레이
                GridLinesView(gridSize: gridSize)
            }
            .frame(width: gridSize, height: gridSize)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - 동일 숫자 판별

    /// 선택된 셀과 동일한 숫자인지 확인 (선택 셀 자체는 false)
    private func isSameNumber(row: Int, col: Int) -> Bool {
        guard let selRow = viewModel.selectedRow,
              let selCol = viewModel.selectedCol else { return false }
        // 선택 셀 자체는 isSelected로 처리
        if row == selRow && col == selCol { return false }
        let selectedValue = viewModel.board.cells[selRow][selCol].value
        guard selectedValue != 0 else { return false }
        return viewModel.board.cells[row][col].value == selectedValue
    }

    // MARK: - 연관 셀 판별

    /// 선택된 셀과 같은 행/열/박스에 속하는지 확인
    private func isRelated(row: Int, col: Int) -> Bool {
        guard let selRow = viewModel.selectedRow,
              let selCol = viewModel.selectedCol else { return false }
        // 선택 셀 자체는 제외 (SudokuCellView에서 isSelected로 처리)
        if row == selRow && col == selCol { return false }

        if row == selRow || col == selCol { return true }

        // 같은 3x3 박스
        let sameBoxRow = (row / 3) == (selRow / 3)
        let sameBoxCol = (col / 3) == (selCol / 3)
        return sameBoxRow && sameBoxCol
    }
}

// MARK: - 경계선 오버레이

/// 스도쿠 그리드의 셀 경계선과 3x3 박스 경계선을 그린다
private struct GridLinesView: View {
    let gridSize: CGFloat

    var body: some View {
        Canvas { context, size in
            let cellSize = size.width / 9

            // 얇은 셀 경계선
            for i in 0...9 {
                let pos = CGFloat(i) * cellSize
                var path = Path()
                // 가로
                path.move(to: CGPoint(x: 0, y: pos))
                path.addLine(to: CGPoint(x: size.width, y: pos))
                // 세로
                path.move(to: CGPoint(x: pos, y: 0))
                path.addLine(to: CGPoint(x: pos, y: size.height))

                let isBold = i % 3 == 0
                context.stroke(
                    path,
                    with: .color(.primary.opacity(0.8)),
                    lineWidth: isBold ? 2.5 : 0.5
                )
            }
        }
        .frame(width: gridSize, height: gridSize)
        .allowsHitTesting(false)
    }
}

// MARK: - Preview

#Preview {
    SudokuGridView(viewModel: GameViewModel())
        .padding()
}
