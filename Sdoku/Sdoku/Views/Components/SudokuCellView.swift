import SwiftUI

/// 스도쿠 단일 셀 렌더링 뷰
struct SudokuCellView: View {

    let cell: SudokuCell
    let isSelected: Bool
    let isRelated: Bool       // 선택 셀과 같은 행/열/박스
    let isSameNumber: Bool    // 선택 셀과 동일한 숫자

    var body: some View {
        ZStack {
            // 배경색
            backgroundColor

            if cell.value != 0 {
                // 일반 숫자 표시
                Text("\(cell.value)")
                    .font(.system(size: 20, weight: cell.isFixed ? .bold : .regular))
                    .foregroundColor(numberColor)
            } else if !cell.notes.isEmpty {
                // 메모 모드: 3x3 서브그리드로 숫자 1~9 표시
                NoteGridView(notes: cell.notes)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        // 빈 셀(Color.clear)도 hit-testing 영역 확보
        .contentShape(Rectangle())
    }

    // MARK: - 색상 계산

    private var backgroundColor: Color {
        if isSelected {
            // Sudoku.com 스타일 선명한 파란색
            return Color(red: 0.18, green: 0.45, blue: 0.85).opacity(0.50)
        } else if isSameNumber {
            // 선택 셀과 동일 숫자: 연한 파란색
            return Color.blue.opacity(0.18)
        } else if cell.isConflict {
            return Color.red.opacity(0.15)
        } else if isRelated {
            return Color.blue.opacity(0.10)
        } else {
            return Color.clear
        }
    }

    private var numberColor: Color {
        if cell.isConflict {
            return .red
        } else if cell.isFixed {
            return .primary
        } else {
            return .blue
        }
    }
}

// MARK: - 메모 서브그리드

/// 셀 내부에 1~9 메모 숫자를 3x3으로 표시
private struct NoteGridView: View {
    let notes: Set<Int>

    var body: some View {
        GeometryReader { geo in
            let cellSize = geo.size.width / 3

            VStack(spacing: 0) {
                ForEach(0..<3) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<3) { col in
                            let number = row * 3 + col + 1
                            Text(notes.contains(number) ? "\(number)" : "")
                                .font(.system(size: cellSize * 0.5))
                                .foregroundColor(.gray)
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
        .padding(2)
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 0) {
        // 고정 셀
        SudokuCellView(
            cell: SudokuCell(value: 5, isFixed: true),
            isSelected: false,
            isRelated: false,
            isSameNumber: false
        )
        // 선택된 셀
        SudokuCellView(
            cell: SudokuCell(value: 3, isFixed: false),
            isSelected: true,
            isRelated: false,
            isSameNumber: false
        )
        // 동일 숫자 셀
        SudokuCellView(
            cell: SudokuCell(value: 3, isFixed: true),
            isSelected: false,
            isRelated: false,
            isSameNumber: true
        )
        // 충돌 셀
        SudokuCellView(
            cell: SudokuCell(value: 3, isFixed: false, isConflict: true),
            isSelected: false,
            isRelated: false,
            isSameNumber: false
        )
        // 메모 셀
        SudokuCellView(
            cell: SudokuCell(value: 0, isFixed: false, notes: [1, 3, 5, 7, 9]),
            isSelected: false,
            isRelated: true,
            isSameNumber: false
        )
        // 빈 셀 (hit-test 버그 수정 확인용)
        SudokuCellView(
            cell: SudokuCell(value: 0, isFixed: false),
            isSelected: false,
            isRelated: false,
            isSameNumber: false
        )
    }
    .frame(width: 240, height: 50)
    .border(Color.gray)
}
