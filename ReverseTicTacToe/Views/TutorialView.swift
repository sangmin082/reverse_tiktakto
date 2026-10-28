import SwiftUI

/// 배우기: 미션 목록. 각 미션은 엔진이 정답을 판정하는 한 수 퍼즐이다.
struct TutorialView: View {
    @AppStorage("tutorial.solved") private var solvedRaw = ""

    private var solved: Set<Int> {
        Set(solvedRaw.split(separator: ",").compactMap { Int($0) })
    }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("배우기")
                        .font(.system(size: 34, weight: .black, design: .serif))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 12)
                        .padding(.bottom, 24)

                    ForEach(Puzzles.all) { puzzle in
                        Rectangle().fill(Theme.hairline).frame(height: 1)
                        NavigationLink {
                            PuzzleScreen(puzzle: puzzle) { markSolved(puzzle.id) }
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 14) {
                                Text(verbatim: "\(puzzle.id)")
                                    .font(.system(.title3, design: .serif, weight: .bold))
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 22, alignment: .leading)
                                Text(LocalizedStringKey(puzzle.title))
                                    .font(.system(size: 22, weight: .semibold, design: .serif))
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                if solved.contains(puzzle.id) {
                                    Image(systemName: "checkmark")
                                        .font(.system(.body, weight: .bold))
                                        .foregroundStyle(Theme.sea)
                                        .accessibilityLabel(Text("완료"))
                                }
                            }
                            .padding(.vertical, 18)
                            .contentShape(Rectangle())
                        }
                    }
                    Rectangle().fill(Theme.hairline).frame(height: 1)
                }
                .padding(.horizontal, 28)
            }
        }
        .toolbarBackground(Theme.paper, for: .navigationBar)
    }

    private func markSolved(_ id: Int) {
        var set = solved
        set.insert(id)
        solvedRaw = set.sorted().map(String.init).joined(separator: ",")
    }
}

private struct PuzzleScreen: View {
    let puzzle: Puzzle
    let onSolved: () -> Void

    private enum Attempt: Equatable {
        case none
        case correct(Int)
        case wrong(Int)
    }

    @State private var attempt: Attempt = .none
    @Environment(\.dismiss) private var dismiss

    private var me: Player { puzzle.position.toMove }

    private var shownPosition: Position {
        switch attempt {
        case .none: puzzle.position
        case .correct(let cell), .wrong(let cell): puzzle.position.placing(cell)
        }
    }

    private var losingLine: [Int] {
        guard case .wrong(let cell) = attempt,
              let line = puzzle.position.completedLine(if: me, places: cell)
        else { return [] }
        return Position.cells(in: line)
    }

    private var lastMove: Int? {
        switch attempt {
        case .none: nil
        case .correct(let cell), .wrong(let cell): cell
        }
    }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Text(LocalizedStringKey(puzzle.title))
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Text(LocalizedStringKey(puzzle.prompt))
                    .font(.callout)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                BoardView(
                    position: shownPosition,
                    lastMove: lastMove,
                    losingLine: losingLine,
                    isInteractive: attempt == .none,
                    onTap: tap
                )
                .padding(.vertical, 8)

                feedback
                    .frame(minHeight: 44, alignment: .top)

                Spacer(minLength: 0)

                actions
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .toolbarBackground(Theme.paper, for: .navigationBar)
    }

    private func tap(_ cell: Int) {
        guard attempt == .none, puzzle.position.isEmpty(cell) else { return }
        if puzzle.accepts(cell) {
            attempt = .correct(cell)
            Haptics.success()
            onSolved()
        } else {
            attempt = .wrong(cell)
            Haptics.failure()
        }
    }

    @ViewBuilder
    private var feedback: some View {
        switch attempt {
        case .none:
            EmptyView()
        case .correct:
            message(correctText, color: Theme.sea)
        case .wrong(let cell):
            if puzzle.position.isPoison(cell, for: me) {
                message("그 칸에 두면 내 줄이 완성됩니다.", color: Theme.accent)
            } else {
                message(puzzle.goal == .forceWin
                        ? "상대에게 아직 안전한 칸이 남습니다. 다시 생각해 보세요."
                        : "지금은 안전하지만, 상대가 잘 두면 결국 몰리게 됩니다.",
                        color: Theme.accent)
            }
        }
    }

    private var correctText: LocalizedStringKey {
        switch puzzle.goal {
        case .avoidPoison: "좋아요! 줄을 피했습니다."
        case .avoidLoss: "정답! 이 칸이라면 끝까지 버틸 수 있습니다."
        case .forceWin: "정답! 이제 상대는 어디에 두든 줄이 완성됩니다."
        }
    }

    private func message(_ text: LocalizedStringKey, color: Color) -> some View {
        Text(text)
            .font(.system(.body, design: .serif, weight: .semibold))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var actions: some View {
        switch attempt {
        case .none:
            EmptyView()
        case .wrong:
            Button("다시 해보기") { attempt = .none }
                .buttonStyle(InkButtonStyle(filled: true))
        case .correct:
            HStack(spacing: 12) {
                Button("다시 해보기") { attempt = .none }
                    .buttonStyle(InkButtonStyle())
                Button("목록으로") { dismiss() }
                    .buttonStyle(InkButtonStyle(filled: true))
            }
        }
    }
}
