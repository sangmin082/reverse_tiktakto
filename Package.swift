// swift-tools-version:5.9
// 게임 엔진·AI만 묶은 패키지 — Mac 없이(리눅스/CI) `swift test`로 규칙과 AI를 검증한다.
// 앱 타깃은 ReverseTicTacToe.xcodeproj가 같은 소스를 직접 컴파일한다.
import PackageDescription

let package = Package(
    name: "TicTacCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TicTacCore", targets: ["TicTacCore"]),
    ],
    targets: [
        .target(
            name: "TicTacCore",
            path: "ReverseTicTacToe",
            exclude: ["App", "Views", "Assets.xcassets", "Info.plist", "PrivacyInfo.xcprivacy",
                      "InfoPlist.xcstrings", "Localizable.xcstrings"],
            sources: ["Engine", "AI"]
        ),
        .testTarget(
            name: "TicTacCoreTests",
            dependencies: ["TicTacCore"],
            path: "Tests/TicTacCoreTests"
        ),
    ]
)
