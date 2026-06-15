import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let masterURL = root.appendingPathComponent("docs/assets/app-icon-master.png")
let iconSetURL = root.appendingPathComponent("LightTranslator/Resources/Assets.xcassets/AppIcon.appiconset")

guard FileManager.default.fileExists(atPath: masterURL.path) else {
    fatalError("Missing master icon at \(masterURL.path)")
}

try FileManager.default.createDirectory(
    at: iconSetURL,
    withIntermediateDirectories: true
)

let slots: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func resample(source: URL, destination: URL, pixels: Int) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    process.arguments = [
        "-z",
        "\(pixels)",
        "\(pixels)",
        source.path,
        "--out",
        destination.path
    ]
    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
        fatalError("Failed to generate \(destination.lastPathComponent)")
    }
}

for (filename, pixelSize) in slots {
    try resample(
        source: masterURL,
        destination: iconSetURL.appendingPathComponent(filename),
        pixels: pixelSize
    )
}

print("Generated app icons from \(masterURL.path)")
