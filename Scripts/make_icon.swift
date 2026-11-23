// Renders the Strato app icon (1024×1024, opaque) with CoreGraphics.
//   swift Scripts/make_icon.swift <output.png>
// Run on macOS as part of the build, so no binary artwork needs to live in the repository.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
let size: CGFloat = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(
    data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { fatalError("no context") }

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        colorSpace: space,
        components: [CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255, alpha]
    )!
}

// CoreGraphics has its origin at the bottom left; flip so the drawing reads top-down.
ctx.translateBy(x: 0, y: size)
ctx.scaleBy(x: 1, y: -1)

// Sky: deep stratosphere blue at the top, brightening toward the horizon.
let sky = CGGradient(
    colorsSpace: space,
    colors: [color(0x050A1C), color(0x0E2350), color(0x1F5FB8), color(0x69C4FF)] as CFArray,
    locations: [0, 0.38, 0.74, 1]
)!
ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size), options: [])

// The curve of the Earth, with a thin glowing atmosphere.
let earth = CGRect(x: -520, y: 760, width: 2064, height: 2064)
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 90, color: color(0xA8E2FF, 0.9))
ctx.setFillColor(color(0x0B2A5E))
ctx.fillEllipse(in: earth)
ctx.restoreGState()
ctx.saveGState()
ctx.addEllipse(in: earth)
ctx.clip()
let ground = CGGradient(colorsSpace: space, colors: [color(0x2C7BD6), color(0x0A1F4A)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(ground, start: CGPoint(x: 0, y: 760), end: CGPoint(x: 0, y: 1024), options: [])
ctx.restoreGState()

// A few stars.
var seed: UInt64 = 42
func random() -> CGFloat {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return CGFloat((seed >> 33) % 10_000) / 10_000
}
for _ in 0..<46 {
    let x = random() * size, y = random() * 430, r = 1.2 + random() * 2.6
    ctx.setFillColor(color(0xFFFFFF, 0.25 + random() * 0.55))
    ctx.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
}

// The route: a great-circle arc from the lower left up to the aircraft.
let start = CGPoint(x: 150, y: 800)
let end = CGPoint(x: 640, y: 388)
let control = CGPoint(x: 270, y: 380)
ctx.saveGState()
ctx.setLineCap(.round)
ctx.setLineWidth(26)
ctx.setStrokeColor(color(0xFFFFFF, 0.92))
ctx.setShadow(offset: .zero, blur: 34, color: color(0x8AD8FF, 0.9))
ctx.move(to: start)
ctx.addQuadCurve(to: end, control: control)
ctx.strokePath()
ctx.restoreGState()
ctx.setFillColor(color(0xFFFFFF))
ctx.fillEllipse(in: CGRect(x: start.x - 30, y: start.y - 30, width: 60, height: 60))
ctx.setFillColor(color(0x1F5FB8))
ctx.fillEllipse(in: CGRect(x: start.x - 13, y: start.y - 13, width: 26, height: 26))

// The aircraft: a top-down airliner, the same silhouette the map uses, heading up and to the right.
func plane(scale k: CGFloat) -> CGPath {
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: (x - 50) * k, y: (y - 50) * k) }
    let path = CGMutablePath()
    path.move(to: p(50, 3))
    path.addCurve(to: p(55, 14), control1: p(53, 5), control2: p(55, 9))
    path.addLine(to: p(55, 38))
    path.addLine(to: p(97, 60))
    path.addLine(to: p(97, 66))
    path.addLine(to: p(55, 56))
    path.addLine(to: p(54.5, 80))
    path.addLine(to: p(70, 91))
    path.addLine(to: p(70, 95))
    path.addLine(to: p(52, 90))
    path.addLine(to: p(50, 97))
    path.addLine(to: p(48, 90))
    path.addLine(to: p(30, 95))
    path.addLine(to: p(30, 91))
    path.addLine(to: p(45.5, 80))
    path.addLine(to: p(45, 56))
    path.addLine(to: p(3, 66))
    path.addLine(to: p(3, 60))
    path.addLine(to: p(45, 38))
    path.addLine(to: p(45, 14))
    path.addCurve(to: p(50, 3), control1: p(45, 9), control2: p(47, 5))
    path.closeSubpath()
    return path
}
ctx.saveGState()
ctx.translateBy(x: 668, y: 356)
ctx.rotate(by: 50 * .pi / 180)
ctx.setShadow(offset: CGSize(width: 0, height: 0), blur: 46, color: color(0x031030, 0.75))
ctx.setFillColor(color(0xFFFFFF))
ctx.addPath(plane(scale: 4.5))
ctx.fillPath()
ctx.restoreGState()

guard let image = ctx.makeImage(),
      let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: output) as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("cannot write \(output)")
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("cannot finalize \(output)") }
print("wrote \(output)")
