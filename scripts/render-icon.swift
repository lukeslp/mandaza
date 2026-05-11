#!/usr/bin/env swift

// Standalone macOS Swift script: renders a 1024x1024 PNG app icon for Mandaza
// using pure CoreGraphics + ImageIO (no UIKit, no asset catalog, no Xcode).
//
//   swift scripts/render-icon.swift
//
// Output: Mandaza/Assets.xcassets/AppIcon.appiconset/icon-1024.png

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let size: CGFloat = 1024
let center = CGPoint(x: size / 2, y: size / 2)

// Bioluminescent palette — phylum cyan + green over void
let void  = CGColor(srgbRed: 0.004, green: 0.016, blue: 0.031, alpha: 1)   // #010408
let deep  = CGColor(srgbRed: 0.024, green: 0.039, blue: 0.063, alpha: 1)   // #060a10
let cyan  = CGColor(srgbRed: 0.0,   green: 1.0,   blue: 1.0,   alpha: 1)   // #00ffff
let green = CGColor(srgbRed: 0.0,   green: 1.0,   blue: 0.533, alpha: 1)   // #00ff88
let violet = CGColor(srgbRed: 0.8,  green: 0.267, blue: 1.0,   alpha: 1)   // #cc44ff

// MARK: - Build a tiny hex grid + walk loops (simplified port of the engine)

let cs = CoreGraphics.CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil,
    width: Int(size),
    height: Int(size),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("ctx") }

// Fill void background
ctx.setFillColor(void)
ctx.fill(CGRect(origin: .zero, size: CGSize(width: size, height: size)))

// Subtle radial gradient bloom from center to simulate deep-ocean glow
if let grad = CGGradient(
    colorsSpace: cs,
    colors: [deep, void] as CFArray,
    locations: [0, 1]
) {
    ctx.drawRadialGradient(
        grad,
        startCenter: center, startRadius: 0,
        endCenter: center, endRadius: size * 0.7,
        options: []
    )
}

// MARK: - Hexagonal trefoil — three interlocking hex loops at center

let r: CGFloat = size * 0.28        // major radius
let lineW: CGFloat = size * 0.018   // stroke width

func hexPath(center c: CGPoint, radius rr: CGFloat, rotation: CGFloat = 0) -> CGPath {
    let p = CGMutablePath()
    for i in 0..<6 {
        let a = rotation + CGFloat(i) * .pi / 3.0
        let pt = CGPoint(x: c.x + rr * cos(a), y: c.y + rr * sin(a))
        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
    }
    p.closeSubpath()
    return p
}

func roundedLoopPath(center c: CGPoint, radius rr: CGFloat, rotation: CGFloat = 0) -> CGPath {
    // A smoother, flower-like loop derived from a hex but with bezier corners.
    let p = CGMutablePath()
    var pts: [CGPoint] = []
    for i in 0..<6 {
        let a = rotation + CGFloat(i) * .pi / 3.0
        pts.append(CGPoint(x: c.x + rr * cos(a), y: c.y + rr * sin(a)))
    }
    var mids: [CGPoint] = []
    for i in 0..<6 {
        let a = pts[i]
        let b = pts[(i + 1) % 6]
        mids.append(CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2))
    }
    p.move(to: mids[0])
    for i in 0..<6 {
        let cp = pts[(i+1) % 6]
        let nx = mids[(i+1) % 6]
        p.addQuadCurve(to: nx, control: cp)
    }
    p.closeSubpath()
    return p
}

func stroke(_ path: CGPath, color: CGColor, width: CGFloat, glow: CGFloat) {
    ctx.saveGState()
    ctx.setLineWidth(width)
    ctx.setLineJoin(.round)
    ctx.setLineCap(.round)
    ctx.setStrokeColor(color)
    if glow > 0 {
        ctx.setShadow(offset: .zero, blur: glow, color: color)
    }
    ctx.addPath(path)
    ctx.strokePath()
    ctx.restoreGState()
}

// Outer halo ring (very subtle, far back)
stroke(roundedLoopPath(center: center, radius: r * 1.45, rotation: .pi / 6),
       color: violet, width: lineW * 0.7, glow: size * 0.045)

// Three rotated hex loops — the bioluminescent trefoil
let baseRotation: CGFloat = -.pi / 2     // point-up
for i in 0..<3 {
    let angle = baseRotation + CGFloat(i) * (2 * .pi / 3)
    let offset: CGFloat = r * 0.42
    let c = CGPoint(x: center.x + offset * cos(angle),
                    y: center.y + offset * sin(angle))
    let color: CGColor = [cyan, green, violet][i]
    stroke(roundedLoopPath(center: c, radius: r * 0.72, rotation: .pi / 6),
           color: color,
           width: lineW,
           glow: size * 0.06)
}

// Inner hex outline — anchors the composition
stroke(hexPath(center: center, radius: r * 0.46),
       color: cyan, width: lineW * 0.85, glow: size * 0.05)

// Tiny center dot — the bioluminescent "core"
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: size * 0.05, color: cyan)
ctx.setFillColor(cyan)
ctx.fillEllipse(in: CGRect(x: center.x - lineW * 1.2,
                            y: center.y - lineW * 1.2,
                            width:  lineW * 2.4,
                            height: lineW * 2.4))
ctx.restoreGState()

// MARK: - Write PNG

guard let img = ctx.makeImage() else { fatalError("makeImage") }

// Default output path — relative to the script's directory.
let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardized
let repoRoot  = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let outURL    = repoRoot
    .appendingPathComponent("Mandaza")
    .appendingPathComponent("Assets.xcassets")
    .appendingPathComponent("AppIcon.appiconset")
    .appendingPathComponent("icon-1024.png")

guard let dest = CGImageDestinationCreateWithURL(
    outURL as CFURL,
    UTType.png.identifier as CFString,
    1, nil
) else { fatalError("CGImageDestination") }

CGImageDestinationAddImage(dest, img, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("finalize") }

print("✓ wrote \(outURL.path) (\(Int(size))×\(Int(size)))")
