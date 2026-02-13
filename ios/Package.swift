// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Apex",
    platforms: [
        .iOS(.v16)
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift", branch: "main")
    ],
    targets: [
        .target(
            name: "Apex",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift")
            ]
        )
    ]
)
