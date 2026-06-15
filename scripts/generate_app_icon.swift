import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let masterURL = root.appendingPathComponent("docs/assets/app-icon-master.png")
let iconSetURL = root.appendingPathComponent("LightTranslator/Resources/Assets.xcassets/AppIcon.appiconset")

try FileManager.default.createDirectory(
    at: masterURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try FileManager.default.createDirectory(
    at: iconSetURL,
    withIntermediateDirectories: true
)

let size = 1024
let canvas = CGRect(x: 0, y: 0, width: size, height: size)
let image = NSImage(size: NSSize(width: size, height: size))

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    let red = CGFloat((hex >> 16) & 0xff) / 255
    let green = CGFloat((hex >> 8) & 0xff) / 255
    let blue = CGFloat(hex & 0xff) / 255
    return NSColor(red: red, green: green, blue: blue, alpha: alpha)
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawSymbol(
    name: String,
    in rect: CGRect,
    color: NSColor,
    pointSize: CGFloat,
    weight: NSFont.Weight = .regular,
    alpha: CGFloat = 1
) {
    guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
        fatalError("Missing SF Symbol: \(name)")
    }

    let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
    let configured = symbol.withSymbolConfiguration(configuration) ?? symbol

    let symbolImage = NSImage(size: rect.size)
    symbolImage.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    configured.draw(
        in: CGRect(origin: .zero, size: rect.size),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
    )
    color.withAlphaComponent(alpha).setFill()
    CGRect(origin: .zero, size: rect.size).fill(using: .sourceAtop)
    symbolImage.unlockFocus()

    symbolImage.draw(in: rect, from: .zero, operation: .sourceOver, fraction: alpha)
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Failed to encode \(url.lastPathComponent)")
    }

    try png.write(to: url)
}

func resample(_ url: URL, pixels: Int) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    process.arguments = [
        "-z",
        "\(pixels)",
        "\(pixels)",
        url.path,
        "--out",
        url.path
    ]
    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
        fatalError("Failed to resample \(url.lastPathComponent)")
    }
}

image.lockFocus()
NSGraphicsContext.current?.imageInterpolation = .high

let baseRect = canvas.insetBy(dx: 64, dy: 64)
let basePath = roundedRect(baseRect, radius: 218)
let baseGradient = NSGradient(colors: [
    color(0x06101f),
    color(0x082b61),
    color(0x0b4c9a)
])!
baseGradient.draw(in: basePath, angle: -42)

let innerPlate = roundedRect(baseRect.insetBy(dx: 48, dy: 48), radius: 170)
color(0x0d4d9d, alpha: 0.36).setFill()
innerPlate.fill()

let rim = roundedRect(baseRect.insetBy(dx: 18, dy: 18), radius: 196)
color(0x68aaf7, alpha: 0.16).setStroke()
rim.lineWidth = 10
rim.stroke()

let symbolRect = CGRect(x: 176, y: 238, width: 672, height: 520)

let shadow = NSShadow()
shadow.shadowColor = color(0x00122a, alpha: 0.36)
shadow.shadowBlurRadius = 26
shadow.shadowOffset = NSSize(width: 0, height: -14)
shadow.set()
drawSymbol(
    name: "character.bubble.fill",
    in: symbolRect.offsetBy(dx: 0, dy: -6),
    color: color(0x001d4a),
    pointSize: 500,
    weight: .regular,
    alpha: 0.38
)
NSShadow().set()

drawSymbol(
    name: "character.bubble.fill",
    in: symbolRect,
    color: color(0x2a91ff),
    pointSize: 500,
    weight: .regular
)

drawSymbol(
    name: "character.bubble.fill",
    in: symbolRect.insetBy(dx: 14, dy: 14),
    color: color(0x6bd8ff),
    pointSize: 500,
    weight: .regular,
    alpha: 0.18
)

let letterFont = NSFont.systemFont(ofSize: 250, weight: .heavy)
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let letterAttributes: [NSAttributedString.Key: Any] = [
    .font: letterFont,
    .foregroundColor: color(0xf4fbff),
    .paragraphStyle: paragraph,
    .kern: -8
]
let letter = NSAttributedString(string: "A", attributes: letterAttributes)
letter.draw(in: CGRect(x: 0, y: 410, width: size, height: 280))

let topHighlight = NSBezierPath()
topHighlight.move(to: CGPoint(x: 320, y: 674))
topHighlight.curve(
    to: CGPoint(x: 704, y: 684),
    controlPoint1: CGPoint(x: 416, y: 730),
    controlPoint2: CGPoint(x: 598, y: 730)
)
color(0xffffff, alpha: 0.14).setStroke()
topHighlight.lineWidth = 20
topHighlight.lineCapStyle = .round
topHighlight.stroke()

image.unlockFocus()

try writePNG(image, to: masterURL)
try resample(masterURL, pixels: size)

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

for (filename, pixelSize) in slots {
    let resized = NSImage(size: NSSize(width: pixelSize, height: pixelSize))
    resized.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(
        in: CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
        from: canvas,
        operation: .copy,
        fraction: 1
    )
    resized.unlockFocus()

    let iconURL = iconSetURL.appendingPathComponent(filename)
    try writePNG(resized, to: iconURL)
    try resample(iconURL, pixels: pixelSize)
}

print("Generated app icon at \(masterURL.path)")
