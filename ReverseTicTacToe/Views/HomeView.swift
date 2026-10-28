import SwiftUI

struct HomeView: View {
    @AppStorage("botLevel") private var botLevel: BotLevel = .normal
    @AppStorage("variant") private var variant: Variant = .classic
    @State private var showRules = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.paper.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    wordmark
                        .padding(.top, 48)

                    Spacer()

                    menu

                    Spacer()

                    Button {
                        showRules = true
                    } label: {
                        Text("규칙 한 장 보기")
                            .font(.footnote)
                            .foregroundStyle(Theme.inkSoft)
                            .underline()
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 28)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showRules) { rulesSheet }
        }
        .tint(Theme.ink)
    }

    // MARK: - 워드마크

    private var wordmark: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 미니 판: 가운데 줄 세 개의 X에 버밀리언 줄 — 줄을 만든 쪽이 진다
            BoardView(
                position: Position(variant: .classic, layout: ".O./XXX/..O"),
                losingLine: [3, 4, 5],
                isInteractive: false
            )
            .frame(width: 64, height: 64)
            .accessibilityHidden(true)

            Text("리버스 틱택토")
                .font(.system(size: 40, weight: .black, design: .serif))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text("먼저 줄을 만드는 쪽이 집니다")
                .font(.system(.body, design: .serif))
                .italic()
                .foregroundStyle(Theme.inkSoft)
        }
    }

    // MARK: - 메뉴

    private var menu: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 판 크기
            textToggle(Variant.allCases, selection: $variant) { option in
                Text(verbatim: option.sizeLabel)
            }
            .padding(.bottom, 6)
            Text(variant.ruleLabel)
                .font(.caption)
                .foregroundStyle(Theme.inkSoft)
                .padding(.bottom, 18)

            menuRow(title: "배우기", detail: "네 개의 미션으로 감 잡기") {
                TutorialView()
            }
            menuRow(title: "컴퓨터 대전", detail: "선·후공을 번갈아 한 판씩") {
                GameScreen(mode: .vsBot(botLevel), variant: variant)
            }

            textToggle(BotLevel.allCases, selection: $botLevel) { level in
                Text(level.label)
            }
            .padding(.top, 2)
            .padding(.bottom, 18)

            menuRow(title: "함께 하기", detail: "한 기기로 번갈아 두기") {
                GameScreen(mode: .twoPlayer, variant: variant)
            }
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
    }

    /// 밑줄로 선택을 표시하는 텍스트 토글
    private func textToggle<Option: Hashable, Label: View>(
        _ options: [Option], selection: Binding<Option>,
        @ViewBuilder label: @escaping (Option) -> Label
    ) -> some View {
        HStack(spacing: 20) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection.wrappedValue == option
                Button {
                    selection.wrappedValue = option
                    Haptics.tap()
                } label: {
                    label(option)
                        .font(.system(.subheadline, weight: isSelected ? .bold : .regular))
                        .foregroundStyle(isSelected ? Theme.accent : Theme.inkSoft)
                        .overlay(alignment: .bottom) {
                            if isSelected {
                                Rectangle()
                                    .fill(Theme.accent)
                                    .frame(height: 2)
                                    .offset(y: 4)
                            }
                        }
                }
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            Spacer()
        }
        .padding(.leading, 2)
    }

    private func menuRow<Destination: View>(
        title: LocalizedStringKey, detail: LocalizedStringKey,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
            NavigationLink {
                destination()
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.system(size: 27, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Theme.inkSoft)
                }
                .padding(.vertical, 18)
                .contentShape(Rectangle())
            }
        }
    }

    // MARK: - 규칙 시트

    private var rulesSheet: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("규칙 한 장")
                        .font(.system(.title2, design: .serif, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 28)

                    VStack(alignment: .leading, spacing: 12) {
                        ruleLine("X가 먼저, 한 칸씩 번갈아 둡니다.")
                        ruleLine("자기 말이 가로·세로·대각선으로 한 줄이 되면 그 사람이 집니다.")
                        ruleLine("3×3과 4×4는 3개, 5×5는 4개가 한 줄이면 패배입니다.")
                        ruleLine("판이 다 찰 때까지 아무도 줄을 만들지 않으면 무승부입니다.")
                        ruleLine("둘 곳이 '지는 칸'뿐인 상대를 만드는 것이 이기는 방법입니다.")
                    }

                    Text("작전 노트")
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        ruleLine("판 한가운데를 기준으로 상대의 수를 뒤집어 따라 두면 웬만해선 지지 않습니다. 어느 판에서 누가 이 작전을 쓸 수 있을지 찾아보세요.")
                        ruleLine("'위험한 칸 표시'를 켜면 지금 두면 지는 칸에 빨간 점이 찍힙니다.")
                    }

                    Spacer()
                }
                .padding(.horizontal, 28)
            }
        }
        .presentationDetents([.large])
    }

    private func ruleLine(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("—")
                .foregroundStyle(Theme.accent)
                .font(.system(.body, weight: .bold))
            Text(text)
                .font(.system(.callout))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
