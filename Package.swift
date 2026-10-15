// swift-tools-version: 6.0
import PackageDescription

// MoldeContrato: o catálogo, o manifesto e a validação (Swift puro, iOS e Mac).
// Molde: a superfície sobre o A2UI-Swift. MoldeInspector: só em DEBUG.
// MoldeCLI: o executável `molde validar`, no Mac. O nome do alvo não pode ser
// `molde`: o disco do Mac não separa maiúscula e acharia `Sources/Molde`.
let package = Package(
    name: "molde",
    // Mac Catalyst 18: o renderer do A2UI-Swift usa API que só existe a partir dele.
    platforms: [.iOS(.v17), .macOS(.v14), .macCatalyst(.v18)],
    products: [
        .library(name: "MoldeContrato", targets: ["MoldeContrato"]),
        .library(name: "Molde", targets: ["Molde"]),
        .library(name: "MoldeInspector", targets: ["MoldeInspector"]),
        .executable(name: "molde", targets: ["MoldeCLI"]),
    ],
    dependencies: [
        // Fork do jrflga, numa versão exata: sem código vivo de outra pessoa.
        .package(url: "https://github.com/jrflga/a2ui-swift", exact: "0.3.5-jrflga.3"),
    ],
    targets: [
        .target(name: "MoldeContrato"),
        .target(name: "Molde", dependencies: [
            "MoldeContrato",
            .product(name: "A2UISwiftCore", package: "a2ui-swift"),
            .product(name: "A2UISwiftUI", package: "a2ui-swift"),
        ]),
        .target(name: "MoldeInspector", dependencies: ["Molde"]),
        .executableTarget(name: "MoldeCLI", dependencies: ["MoldeContrato"]),
        .testTarget(name: "MoldeContratoTests", dependencies: ["MoldeContrato"]),
        .testTarget(
            name: "MoldeTests",
            dependencies: ["Molde", "MoldeContrato", .product(name: "A2UISwiftCore", package: "a2ui-swift")],
            resources: [.copy("Exemplos")]
        ),
    ]
)
