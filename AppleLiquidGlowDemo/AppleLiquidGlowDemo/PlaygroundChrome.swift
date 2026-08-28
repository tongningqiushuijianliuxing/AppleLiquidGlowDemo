import SwiftUI

struct ThemeItem: Identifiable, Hashable {
    let id: String
    let name: String
    let glyph: String
    let tint: Color

    static func == (lhs: ThemeItem, rhs: ThemeItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static let all: [ThemeItem] = [
        .init(id: "adventure", name: "Adventure", glyph: "🚙", tint: Color(red: 0.98, green: 0.58, blue: 0.22)),
        .init(id: "birthday", name: "Birthday", glyph: "🎂", tint: Color(red: 1.0, green: 0.45, blue: 0.58)),
        .init(id: "disco", name: "Disco", glyph: "🪩", tint: Color(red: 0.55, green: 0.78, blue: 1.0)),
        .init(id: "fantasy", name: "Fantasy", glyph: "🏰", tint: Color(red: 0.45, green: 0.86, blue: 0.72)),
        .init(id: "fireworks", name: "Fireworks", glyph: "🎆", tint: Color(red: 1.0, green: 0.55, blue: 0.35)),
        .init(id: "love", name: "Love", glyph: "💗", tint: Color(red: 1.0, green: 0.32, blue: 0.48)),
        .init(id: "starry", name: "Starry Night", glyph: "🌙", tint: Color(red: 0.55, green: 0.62, blue: 1.0)),
        .init(id: "summer", name: "Summer", glyph: "🏖️", tint: Color(red: 1.0, green: 0.78, blue: 0.28)),
        .init(id: "party", name: "Party", glyph: "🎉", tint: Color(red: 0.95, green: 0.42, blue: 0.85)),
        .init(id: "winter", name: "Winter Holidays", glyph: "☃️", tint: Color(red: 0.65, green: 0.88, blue: 1.0)),
        .init(id: "stage", name: "Stage", glyph: "🎭", tint: Color(red: 0.78, green: 0.42, blue: 1.0)),
        .init(id: "scifi", name: "Sci-fi", glyph: "🛸", tint: Color(red: 0.62, green: 0.38, blue: 1.0))
    ]

    static func named(_ id: String) -> ThemeItem {
        all.first { $0.id == id } ?? all[0]
    }
}

struct ThemeGlyph: View {
    let item: ThemeItem
    var diameter: CGFloat = 64

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            item.tint.opacity(0.92),
                            item.tint.opacity(0.38),
                            Color(white: 0.06)
                        ],
                        center: .center,
                        startRadius: 1,
                        endRadius: diameter * 0.68
                    )
                )

            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.22), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(diameter * 0.05)
                .blendMode(.screen)

            Text(item.glyph)
                .font(.system(size: diameter * 0.40))
        }
        .frame(width: diameter, height: diameter)
        .overlay(Circle().stroke(.white.opacity(0.20), lineWidth: 0.8))
        .shadow(color: item.tint.opacity(0.35), radius: 8, y: 2)
    }
}

/// Bubbles stay at fixed compass points and get pulled inward — they do not orbit.
struct OrbitingBubble: View {
    let item: ThemeItem
    var merge: CGFloat
    var time: TimeInterval
    var index: Int
    var count: Int
    var onRemove: () -> Void

    private static let slots: [(x: Double, y: Double)] = [
        (-0.92, -0.05),  // Stage — left
        (0.78, -0.72),   // Fantasy — upper right
        (0.08, 0.92)     // Sci-fi — bottom
    ]

    var body: some View {
        let slot = Self.slots[min(index, Self.slots.count - 1)]
        let pull = pow(Double(merge), 1.65)
        let radius: Double = 118

        let bobX = sin(time * 1.05 + Double(index) * 1.7) * 3.5 * (1 - pull)
        let bobY = cos(time * 0.95 + Double(index) * 2.1) * 3.0 * (1 - pull)

        let x = slot.x * radius * (1 - pull) + bobX
        let y = slot.y * radius * (1 - pull) + bobY

        let scale = 1.0 - 0.48 * merge
        let opacity = 1.0 - smoothstep(0.72, 1.0, merge)

        VStack(spacing: 5) {
            ZStack(alignment: .topLeading) {
                ThemeGlyph(item: item, diameter: 66)
                    .scaleEffect(scale)

                Button(action: onRemove) {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(.black.opacity(0.58), in: Circle())
                }
                .offset(x: -3, y: -3)
                .opacity(Double(1 - merge))
            }

            Text(item.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.88))
                .opacity(Double(1 - merge))
        }
        .offset(x: x, y: y)
        .opacity(opacity)
        .allowsHitTesting(merge < 0.15)
    }

    private func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = max(0, min(1, (x - edge0) / max(edge1 - edge0, 0.0001)))
        return t * t * (3 - 2 * t)
    }
}

struct BokehField: View {
    var morph: CGFloat
    var time: TimeInterval

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.72, green: 0.28, blue: 0.95).opacity(0.28))
                .frame(width: 88, height: 88)
                .offset(x: 96, y: -18 + 6 * sin(time * 0.7))

            Circle()
                .fill(Color(red: 0.28, green: 0.58, blue: 1.0).opacity(0.30))
                .frame(width: 72, height: 72)
                .offset(x: -88, y: 42 + 5 * cos(time * 0.55))
        }
        .blur(radius: 28)
        .opacity(Double(morph * 0.85))
        .allowsHitTesting(false)
    }
}

struct IntelligenceMark: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            Color(red: 1.0, green: 0.45, blue: 0.55),
                            Color(red: 0.45, green: 0.55, blue: 1.0),
                            Color(red: 0.95, green: 0.55, blue: 0.2),
                            Color(red: 0.7, green: 0.35, blue: 1.0),
                            Color(red: 1.0, green: 0.45, blue: 0.55)
                        ],
                        center: .center
                    )
                )
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.95))
        }
        .frame(width: 26, height: 26)
    }
}
