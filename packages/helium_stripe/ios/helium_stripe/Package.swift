// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "helium_stripe",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "helium-stripe", targets: ["helium_stripe"])
    ],
    dependencies: [
        .package(url: "https://github.com/cloudcaptainai/helium-swift.git", exact: "4.1.8"),
        .package(url: "https://github.com/appmonetization/stripe-one-tap-purchase.git", exact: "1.0.6"),
    ],
    targets: [
        .target(
            name: "helium_stripe",
            dependencies: [
                .product(name: "Helium", package: "helium-swift"),
                .product(name: "StripeOneTapPurchase", package: "stripe-one-tap-purchase"),
            ]
        )
    ]
)
