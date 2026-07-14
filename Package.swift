// swift-tools-version:5.10
// Package.swift ≈ Maven 的 pom.xml:声明产物、依赖、平台、构建目标。
import PackageDescription

let package = Package(
    name: "DeskWidgets",
    // 目标平台:macOS 13+(SMAppService 开机自启需要 13+)
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // 一个可执行产物(GUI App)。类比 Maven 打出的可运行 jar。
        .executable(name: "DeskWidgets", targets: ["DeskWidgets"])
    ],
    dependencies: [
        // 暂无第三方依赖,全部使用系统框架(SwiftUI/AppKit/ServiceManagement)
    ],
    targets: [
        .executableTarget(
            name: "DeskWidgets",
            path: "Sources/DeskWidgets"
        )
    ]
)
