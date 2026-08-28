import SwiftUI

/// Painterly placeholder scene closer to Image Playground's result card.
struct GeneratedArtwork: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let mid = CGPoint(x: size.width * 0.5, y: size.height * 0.54)
                drawSky(ctx, size: size)
                drawStars(ctx, size: size, time: t)
                drawNebula(ctx, size: size, time: t)
                drawBeam(ctx, mid: mid, size: size, time: t)
                drawLandscape(ctx, size: size, time: t)
                drawFloatingIsland(ctx, size: size, time: t)
                drawVignette(ctx, size: size)
            }
        }
        .allowsHitTesting(false)
    }

    private func drawSky(_ ctx: GraphicsContext, size: CGSize) {
        let sky = Gradient(colors: [
            Color(red: 0.08, green: 0.04, blue: 0.20),
            Color(red: 0.16, green: 0.08, blue: 0.34),
            Color(red: 0.07, green: 0.13, blue: 0.30),
            Color(red: 0.03, green: 0.03, blue: 0.10)
        ])
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .linearGradient(sky, startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: size.height)))
    }

    private func drawStars(_ ctx: GraphicsContext, size: CGSize, time: Double) {
        var rng = SeededRandom(seed: 7)
        for i in 0..<52 {
            let x = rng.next() * size.width
            let y = rng.next() * size.height * 0.64
            let r = 0.35 + rng.next() * 1.25
            let twinkle = 0.38 + 0.62 * abs(sin(time * (1.15 + rng.next()) + Double(i)))
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                     with: .color(.white.opacity(twinkle)))
        }
    }

    private func drawNebula(_ ctx: GraphicsContext, size: CGSize, time: Double) {
        let p1 = CGPoint(x: size.width * (0.26 + 0.03 * sin(time * 0.32)),
                         y: size.height * (0.36 + 0.02 * cos(time * 0.45)))
        let p2 = CGPoint(x: size.width * (0.74 + 0.02 * cos(time * 0.28)),
                         y: size.height * (0.34 + 0.02 * sin(time * 0.51)))
        let p3 = CGPoint(x: size.width * 0.50, y: size.height * (0.26 + 0.01 * sin(time * 0.64)))

        var copy = ctx
        copy.addFilter(.blur(radius: 44))
        copy.fill(Path(ellipseIn: CGRect(x: p1.x - 70, y: p1.y - 46, width: 140, height: 92)),
                  with: .color(Color(red: 0.95, green: 0.30, blue: 0.50).opacity(0.34)))
        copy.fill(Path(ellipseIn: CGRect(x: p2.x - 78, y: p2.y - 52, width: 156, height: 104)),
                  with: .color(Color(red: 0.26, green: 0.58, blue: 1.00).opacity(0.34)))
        copy.fill(Path(ellipseIn: CGRect(x: p3.x - 62, y: p3.y - 42, width: 124, height: 84)),
                  with: .color(Color(red: 1.00, green: 0.62, blue: 0.28).opacity(0.30)))
    }

    private func drawBeam(_ ctx: GraphicsContext, mid: CGPoint, size: CGSize, time: Double) {
        let pulse = 0.82 + 0.18 * sin(time * 1.85)
        var beam = Path()
        let top = CGPoint(x: mid.x, y: size.height * 0.06)
        beam.move(to: CGPoint(x: mid.x - 12, y: mid.y))
        beam.addLine(to: CGPoint(x: mid.x + 12, y: mid.y))
        beam.addLine(to: CGPoint(x: mid.x + 40, y: top.y))
        beam.addLine(to: CGPoint(x: mid.x - 40, y: top.y))
        beam.closeSubpath()
        var copy = ctx
        copy.addFilter(.blur(radius: 6))
        copy.fill(beam, with: .linearGradient(
            Gradient(colors: [
                Color(red: 1.00, green: 0.74, blue: 0.36).opacity(0.85 * pulse),
                Color(red: 1.00, green: 0.40, blue: 0.60).opacity(0.42 * pulse),
                .clear
            ]),
            startPoint: mid,
            endPoint: top
        ))
    }

    private func drawLandscape(_ ctx: GraphicsContext, size: CGSize, time: Double) {
        var back = Path()
        back.move(to: CGPoint(x: 0, y: size.height * 0.90))
        back.addCurve(to: CGPoint(x: size.width, y: size.height * 0.88),
                      control1: CGPoint(x: size.width * 0.22, y: size.height * (0.64 + 0.02 * sin(time * 0.3))),
                      control2: CGPoint(x: size.width * 0.78, y: size.height * (0.70 + 0.02 * cos(time * 0.25))))
        back.addLine(to: CGPoint(x: size.width, y: size.height))
        back.addLine(to: CGPoint(x: 0, y: size.height))
        back.closeSubpath()

        ctx.fill(back, with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.16, green: 0.34, blue: 0.25),
                Color(red: 0.06, green: 0.10, blue: 0.14)
            ]),
            startPoint: CGPoint(x: 0, y: size.height * 0.66),
            endPoint: CGPoint(x: 0, y: size.height)
        ))

        var front = Path()
        front.move(to: CGPoint(x: 0, y: size.height * 0.96))
        front.addCurve(to: CGPoint(x: size.width, y: size.height * 0.95),
                       control1: CGPoint(x: size.width * 0.24, y: size.height * 0.82),
                       control2: CGPoint(x: size.width * 0.78, y: size.height * 0.86))
        front.addLine(to: CGPoint(x: size.width, y: size.height))
        front.addLine(to: CGPoint(x: 0, y: size.height))
        front.closeSubpath()
        ctx.fill(front, with: .color(Color(red: 0.05, green: 0.07, blue: 0.11).opacity(0.88)))
    }

    private func drawFloatingIsland(_ ctx: GraphicsContext, size: CGSize, time: Double) {
        let cx = size.width * (0.52 + 0.012 * sin(time * 0.95))
        let cy = size.height * (0.56 + 0.01 * cos(time * 1.1))
        let island = CGRect(x: cx - size.width * 0.19, y: cy - size.height * 0.17,
                            width: size.width * 0.38, height: size.height * 0.27)
        let top = RoundedRectangle(cornerRadius: 18, style: .continuous).path(in: island)

        ctx.fill(top, with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.62, green: 0.50, blue: 0.84),
                Color(red: 0.46, green: 0.36, blue: 0.72)
            ]),
            startPoint: CGPoint(x: island.midX, y: island.minY),
            endPoint: CGPoint(x: island.midX, y: island.maxY)
        ))

        var underside = Path()
        underside.move(to: CGPoint(x: island.minX + 26, y: island.maxY - 6))
        underside.addCurve(to: CGPoint(x: island.maxX - 26, y: island.maxY - 6),
                           control1: CGPoint(x: island.minX + 68, y: island.maxY + 48),
                           control2: CGPoint(x: island.maxX - 68, y: island.maxY + 48))
        underside.addLine(to: CGPoint(x: island.maxX - 38, y: island.maxY + 18))
        underside.addLine(to: CGPoint(x: island.minX + 38, y: island.maxY + 18))
        underside.closeSubpath()
        ctx.fill(underside, with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.36, green: 0.24, blue: 0.50),
                Color(red: 0.22, green: 0.15, blue: 0.34)
            ]),
            startPoint: CGPoint(x: island.midX, y: island.maxY),
            endPoint: CGPoint(x: island.midX, y: island.maxY + 24)
        ))

        var tower = Path()
        tower.move(to: CGPoint(x: island.midX - 22, y: island.minY + 8))
        tower.addLine(to: CGPoint(x: island.midX + 22, y: island.minY + 8))
        tower.addLine(to: CGPoint(x: island.midX + 16, y: island.minY - 42))
        tower.addLine(to: CGPoint(x: island.midX - 16, y: island.minY - 42))
        tower.closeSubpath()
        ctx.fill(tower, with: .color(Color(red: 0.84, green: 0.70, blue: 0.96)))

        var roof = Path()
        roof.move(to: CGPoint(x: island.midX, y: island.minY - 66))
        roof.addLine(to: CGPoint(x: island.midX - 24, y: island.minY - 38))
        roof.addLine(to: CGPoint(x: island.midX + 24, y: island.minY - 38))
        roof.closeSubpath()
        ctx.fill(roof, with: .color(Color(red: 0.98, green: 0.52, blue: 0.56)))

        var glowCtx = ctx
        glowCtx.addFilter(.blur(radius: 10))
        glowCtx.fill(Path(ellipseIn: CGRect(x: island.midX - 34, y: island.minY - 26, width: 68, height: 40)),
                     with: .color(Color(red: 1.0, green: 0.8, blue: 0.52).opacity(0.42)))
    }

    private func drawVignette(_ ctx: GraphicsContext, size: CGSize) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                 with: .radialGradient(
                    Gradient(colors: [.clear, .black.opacity(0.52)]),
                    center: CGPoint(x: size.width * 0.5, y: size.height * 0.45),
                    startRadius: size.width * 0.25,
                    endRadius: size.width * 0.72
                 ))
    }
}

private struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 }
    mutating func next() -> CGFloat {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return CGFloat(Double(z >> 11) * (1.0 / 9_007_199_254_740_992.0))
    }
}
