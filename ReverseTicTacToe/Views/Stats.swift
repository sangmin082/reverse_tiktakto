import Foundation

/// 컴퓨터 대전 전적 — 난이도별로 UserDefaults에 저장
enum Stats {
    struct Record: Equatable {
        var wins = 0, losses = 0, draws = 0
        var total: Int { wins + losses + draws }
    }

    private static func key(_ level: BotLevel, _ kind: String) -> String {
        "stats.square4.\(level.rawValue).\(kind)"
    }

    static func record(for level: BotLevel) -> Record {
        let defaults = UserDefaults.standard
        return Record(
            wins: defaults.integer(forKey: key(level, "win")),
            losses: defaults.integer(forKey: key(level, "loss")),
            draws: defaults.integer(forKey: key(level, "draw"))
        )
    }

    static func add(_ result: GameResult, human: Player, level: BotLevel) {
        let kind: String
        switch result.winner {
        case human?: kind = "win"
        case nil: kind = "draw"
        default: kind = "loss"
        }
        let k = key(level, kind)
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: k) + 1, forKey: k)
    }
}
