import SwiftUI

/// N×N 판. 격자·말·마지막 수·위험 칸·패배한 줄을 그린다.
struct BoardView: View {
    let position: Position
    var lastMove: Int?
    var losingLine: [Int] = []
    /// 위험 칸 표시 (둘 차례인 사람이 두면 지는 칸)
    var dangerMask: UInt32 = 0
    var isInteractive: Bool = true
    var onTap: (Int) -> Void = { _ in }

    private var size: Int { position.variant.size }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cell = side / CGFloat(size)

            ZStack(alignment: .topLeading) {
                ForEach(0..<position.variant.cellCount, id: \.self) { index in
                    cellView(index, cellSize: cell)
                        .frame(width: cell, height: cell)
                        .offset(x: CGFloat(index % size) * cell, y: CGFloat(index / size) * cell)
                }

                GridLines(count: size)
                    .stroke(Theme.ink, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .allowsHitTesting(false)

                if let first = losingLine.first, let last = losingLine.last {
                    LosingLine(from: center(of: first, cell: cell), to: center(of: last, cell: cell))
                        .allowsHitTesting(false)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func center(of index: Int, cell: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(index % size) + 0.5) * cell, y: (CGFloat(index / size) + 0.5) * cell)
    }

    @ViewBuilder
    private func cellView(_ index: Int, cellSize: CGFloat) -> some View {
        let player = position.player(at: index)
        let isDanger = player == nil && dangerMask & (1 << UInt32(index)) != 0

        Button {
            onTap(index)
        } label: {
            ZStack {
                Rectangle()
                    .fill(index == lastMove ? Theme.cellLastMove : Color.clear)

                if let player {
                    MarkView(player: player)
                        .padding(cellSize * 0.2)
                        .id("\(index)-\(player.rawValue)")
                } else if isDanger {
                    Circle()
                        .fill(Theme.accent.opacity(0.55))
                        .frame(width: cellSize * 0.12, height: cellSize * 0.12)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isInteractive || player != nil)
        .accessibilityLabel(accessibilityLabel(index, player: player, isDanger: isDanger))
    }

    private func accessibilityLabel(_ index: Int, player: Player?, isDanger: Bool) -> Text {
        var label = "\(index / size + 1)-\(index % size + 1)"
        if let player {
            label += ", \(player.symbol)"
        } else if isDanger {
            label += ", " + String(localized: "위험")
        }
        return Text(verbatim: label)
    }
}

/// 안쪽 격자선만 그린다 (바깥 테두리 없음 — 전통 틱택토 모양)
private struct GridLines: Shape {
    let count: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step = rect.width / CGFloat(count)
        let inset = step * 0.08
        for i in 1..<count {
            let offset = CGFloat(i) * step
            path.move(to: CGPoint(x: offset, y: inset))
            path.addLine(to: CGPoint(x: offset, y: rect.height - inset))
            path.move(to: CGPoint(x: inset, y: offset))
            path.addLine(to: CGPoint(x: rect.width - inset, y: offset))
        }
        return path
    }
}

/// 손으로 긋는 듯한 X / O
struct MarkView: View {
    let player: Player
    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let width = max(3, proxy.size.width * 0.12)
            Group {
                if player == .x {
                    XShape().trim(from: 0, to: progress)
                        .stroke(Theme.color(for: .x), style: StrokeStyle(lineWidth: width, lineCap: .round))
                } else {
                    Circle().inset(by: width / 2).trim(from: 0, to: progress)
                        .rotation(.degrees(-90))
                        .stroke(Theme.color(for: .o), style: StrokeStyle(lineWidth: width, lineCap: .round))
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.22)) { progress = 1 }
        }
    }
}

private struct XShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}

/// 패배한 줄을 버밀리언으로 긋는다
private struct LosingLine: View {
    let from: CGPoint
    let to: CGPoint
    @State private var progress: CGFloat = 0

    var body: some View {
        Path { path in
            // 양 끝을 조금 늘려 칸 밖까지 긋는다
            let dx = (to.x - from.x) * 0.12, dy = (to.y - from.y) * 0.12
            path.move(to: CGPoint(x: from.x - dx, y: from.y - dy))
            path.addLine(to: CGPoint(x: to.x + dx, y: to.y + dy))
        }
        .trim(from: 0, to: progress)
        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.45).delay(0.15)) { progress = 1 }
        }
    }
}
