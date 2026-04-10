import Foundation
import Observation

/// 게임 플레이의 상태 관리 및 로직 처리
@Observable
final class GameViewModel {

    // MARK: - 내부 상태

    private var state: GameState

    // MARK: - 외부에 노출되는 읽기 전용 프로퍼티

    var board: SudokuBoard { state.board }
    var selectedRow: Int? { state.selectedRow }
    var selectedCol: Int? { state.selectedCol }
    var isPencilMode: Bool { state.isPencilMode }
    var canUndo: Bool { state.canUndo }

    // MARK: - 초기화

    init(board: SudokuBoard = .mock()) {
        self.state = GameState(board: board)
    }

    // MARK: - 셀 선택

    /// 셀을 선택한다. 이미 선택된 셀을 다시 탭하면 선택 해제
    func selectCell(row: Int, col: Int) {
        if state.selectedRow == row, state.selectedCol == col {
            state.selectedRow = nil
            state.selectedCol = nil
        } else {
            state.selectedRow = row
            state.selectedCol = col
        }
    }

    // MARK: - 숫자 입력

    /// 선택된 셀에 숫자를 입력한다.
    /// - 고정 셀(isFixed)은 무시
    /// - 펜슬 모드: notes 토글
    /// - 일반 모드: value 설정 (notes 초기화)
    func inputNumber(_ number: Int) {
        guard let row = state.selectedRow,
              let col = state.selectedCol else { return }

        let cell = state.board.cells[row][col]
        guard !cell.isFixed else { return }

        // Undo 스택에 현재 상태 저장
        state.pushUndo()

        if state.isPencilMode {
            // 메모 모드: 해당 숫자 토글
            if state.board.cells[row][col].notes.contains(number) {
                state.board.cells[row][col].notes.remove(number)
            } else {
                state.board.cells[row][col].notes.insert(number)
            }
        } else {
            // 일반 모드: 동일 숫자 재입력 시 지우기, 아니면 설정
            if state.board.cells[row][col].value == number {
                state.board.cells[row][col].value = 0
            } else {
                state.board.cells[row][col].value = number
            }
            // 값 변경 시 메모 초기화
            state.board.cells[row][col].notes = []
        }

        // 입력 후 전체 보드 충돌 재계산
        state.board = state.board.detectingConflicts()
    }

    // MARK: - 셀 지우기

    /// 선택된 셀의 값과 메모를 모두 지운다. 고정 셀은 무시
    func clearCell() {
        guard let row = state.selectedRow,
              let col = state.selectedCol else { return }

        let cell = state.board.cells[row][col]
        guard !cell.isFixed else { return }
        guard cell.value != 0 || !cell.notes.isEmpty else { return }

        state.pushUndo()

        state.board.cells[row][col].value = 0
        state.board.cells[row][col].notes = []

        state.board = state.board.detectingConflicts()
    }

    // MARK: - 펜슬 모드 토글

    /// 일반 입력 ↔ 메모(펜슬) 입력 모드 전환
    func togglePencilMode() {
        state.isPencilMode.toggle()
    }

    // MARK: - 실행 취소

    /// 마지막 변경을 취소한다. Undo 스택이 비어 있으면 무시
    func undo() {
        state.undo()
        // undo 후 충돌 상태는 이미 저장된 보드 기준이므로 별도 재계산 불필요
    }
}
