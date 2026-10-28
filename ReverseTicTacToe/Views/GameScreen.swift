import SwiftUI
import Observation

enum GameMode: Hashable {
    case vsBot(BotLevel)
    case twoPlayer
}

/// 한 판의 진행을 관리한다: 사람 입력, 봇 차례, 무르기, 전적 기록.
@MainActor
@Observable
final class GameModel {
    let mode: GameMode
    let variant: Variant
    private(set) var game: Game
    /// 컴퓨터 대전에서 사람이 잡은 쪽 (판마다 선·후공을 번갈아 맡는다)
    private(set) var humanSide: Player = .x
    private(set) var isThinking = false
    @ObservationIgnored private var botTask: Task<Void, Never>?

    init(mode: GameMode, variant: Variant) {
        self.mode = mode
        self.variant = variant
        game = Game(variant: variant)
    }

    var botLevel: BotLevel? {
        if case .vsBot(let level) = mode { return level }
        return nil
    }

    var isBotTurn: Bool { botLevel != nil && game.toMove != humanSide && !game.isOver }
    var canTap: Bool { !game.isOver && !isBotTurn && !isThinking }

    var canUndo: Bool {
        guard !isThinking else { return false }
        // 컴퓨터 대전: 사람이 둔 수가 하나라도 있어야 무를 수 있다
        if botLevel != nil { return game.moves.count >= (humanSide == .x ? 1 : 2) }
        return !game.moves.isEmpty
    }

    func start() {
        if isBotTurn { runBot() }
    }

    func tap(_ cell: Int) {
        guard canTap, game.canPlay(cell) else { return }
        game.play(cell)
        Haptics.move()
        afterMove()
    }

    func undo() {
        guard canUndo else { return }
        botTask?.cancel()
        isThinking = false
        game.undo()
        // 컴퓨터 대전에서는 사람 차례가 될 때까지 한 수 더 무른다
        if botLevel != nil, game.toMove != humanSide { game.undo() }
        Haptics.tap()
    }

    /// 새 판. 컴퓨터 대전이면 선·후공을 바꾼다.
    func rematch() {
        botTask?.cancel()
        isThinking = false
        if botLevel != nil { humanSide = humanSide.opponent }
        game = Game(variant: variant)
        start()
    }

    private func afterMove() {
        if let result = game.result {
            if let level = botLevel {
                Stats.add(result, human: humanSide, variant: variant, level: level)
                result.winner == humanSide ? Haptics.success() : Haptics.failure()
            } else {
                Haptics.failure()
            }
            return
        }
        if isBotTurn { runBot() }
    }

    private func runBot() {
        guard let level = botLevel else { return }
        let position = game.position
        isThinking = true
        botTask = Task { [weak self] in
            let started = Date()
            let move = await Task.detached(priority: .userInitiated) {
                Bot.chooseMove(in: position, level: level)
            }.value
            // 너무 빨리 두면 어색하므로 최소한의 '생각 시간'을 둔다
            let minimum = 0.45 - Date().timeIntervalSince(started)
            if minimum > 0 { try? await Task.sleep(for: .seconds(minimum)) }

            guard let self, !Task.isCancelled, self.game.position == position, let move else { return }
            self.isThinking = false
            self.game.play(move)
            Haptics.move()
            self.afterMove()
        }
    }
}

struct GameScreen: View {
    @State private var model: GameModel
    @AppStorage("showDangerHints") private var showDangerHints = true

    init(mode: GameMode, variant: Variant) {
        _model = State(initialValue: GameModel(mode: mode, variant: variant))
    }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, 8)

                Spacer(minLength: 16)

                BoardView(
                    position: model.game.position,
                    lastMove: model.game.lastMove,
                    losingLine: model.game.result?.losingLine ?? [],
                    dangerMask: dangerMask,
                    isInteractive: model.canTap,
                    onTap: { model.tap($0) }
                )
                .padding(.horizontal, 8)

                Spacer(minLength: 16)

                footer
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 0) {
                    Text(verbatim: "\(model.variant.sizeLabel) · ")
                    Text(model.variant.ruleLabel)
                }
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .foregroundStyle(Theme.ink)
            }
        }
        .toolbarBackground(Theme.paper, for: .navigationBar)
        .onAppear { model.start() }
    }

    /// 사람 차례일 때만 위험 칸을 보여 준다
    private var dangerMask: UInt32 {
        guard showDangerHints, model.canTap else { return 0 }
        return model.game.position.poisonMask(for: model.game.toMove)
    }

    // MARK: - 상단: 차례 / 결과

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                sideBadge(.x)
                Text("vs")
                    .font(.system(.footnote, design: .serif))
                    .italic()
                    .foregroundStyle(Theme.inkSoft)
                sideBadge(.o)
            }

            statusText
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(model.game.result == nil ? Theme.ink : Theme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(height: 28)
                .animation(.default, value: model.game.result)
        }
    }

    private func sideBadge(_ player: Player) -> some View {
        let isTurn = model.game.toMove == player && !model.game.isOver
        return HStack(spacing: 8) {
            MarkView(player: player)
                .frame(width: 18, height: 18)
            Text(sideName(player))
                .font(.system(.subheadline, weight: isTurn ? .bold : .regular))
                .foregroundStyle(isTurn ? Theme.ink : Theme.inkSoft)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isTurn ? Theme.color(for: player) : .clear)
                .frame(height: 2)
        }
    }

    private func sideName(_ player: Player) -> LocalizedStringKey {
        guard model.botLevel != nil else { return player == .x ? "X 선공" : "O 후공" }
        return player == model.humanSide ? "나" : "컴퓨터"
    }

    @ViewBuilder
    private var statusText: some View {
        if let result = model.game.result {
            switch (result.winner, model.botLevel) {
            case (nil, _):
                Text("무승부 — 아무도 줄을 만들지 않았습니다")
            case (let winner?, nil):
                winner == .x ? Text("X 승리! O가 줄을 완성했습니다") : Text("O 승리! X가 줄을 완성했습니다")
            case (let winner?, _):
                winner == model.humanSide ? Text("승리! 컴퓨터가 줄을 완성했습니다") : Text("패배… 줄을 완성하고 말았습니다")
            }
        } else if model.isThinking {
            Text("컴퓨터가 생각 중…")
        } else if model.botLevel != nil {
            Text("당신 차례입니다")
        } else {
            model.game.toMove == .x ? Text("X 차례") : Text("O 차례")
        }
    }

    // MARK: - 하단: 무르기 / 새 판 / 힌트

    private var footer: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Button("무르기") { model.undo() }
                    .buttonStyle(InkButtonStyle())
                    .disabled(!model.canUndo || model.game.isOver)
                    .opacity(model.canUndo && !model.game.isOver ? 1 : 0.35)

                Button { model.rematch() } label: { model.game.isOver ? Text("한 판 더") : Text("새로 시작") }
                    .buttonStyle(InkButtonStyle(filled: model.game.isOver))
            }

            HStack {
                Toggle(isOn: $showDangerHints) {
                    Text("위험한 칸 표시")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                }
                .tint(Theme.accent)
            }

            if let level = model.botLevel {
                let record = Stats.record(for: model.variant, level: level)
                if record.total > 0 {
                    HStack(spacing: 6) {
                        Text(level.label)
                        Text("전적 \(record.wins)승 \(record.losses)패 \(record.draws)무")
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.inkSoft)
                }
            }
        }
    }
}
