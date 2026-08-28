import SwiftUI

/// Base color haze. Only carries the very first beat of the loop — once the
/// droplet condenses the Metal layer takes over.
struct SoftGlowBackdrop: View {
    var time: Double

    var body: some View {
        ZStack {
            blob(Color(red: 0.95, green: 0.28, blue: 0.60),
                 x: -70 + 14 * sin(time * 0.52), y: -42 + 10 * cos(time * 0.44), size: 250)
            blob(Color(red: 1.00, green: 0.55, blue: 0.20),
                 x:  14 + 12 * cos(time * 0.40), y: -66 +  9 * sin(time * 0.48), size: 235)
            blob(Color(red: 0.28, green: 0.50, blue: 0.98),
                 x:  80 + 10 * sin(time * 0.36), y:  18 + 11 * cos(time * 0.42), size: 245)
            blob(Color(red: 0.60, green: 0.26, blue: 0.92),
                 x: -18 + 11 * cos(time * 0.45), y:  70 +  9 * sin(time * 0.38), size: 225)
        }
        .blur(radius: 56)
        .allowsHitTesting(false)
    }

    private func blob(_ color: Color, x: Double, y: Double, size: Double) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(0.70), color.opacity(0.32), color.opacity(0.0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.52
                )
            )
            .frame(width: size, height: size)
            .offset(x: x, y: y)
    }
}

/// Metal stage: haze → living droplet → rounded square with streaming rim light.
struct PlaygroundFlowView: View {
    var time: Float
    var phase: Float
    var theme: Float

    var body: some View {
        Rectangle()
            .fill(.white)
            .visualEffect { content, proxy in
                content.colorEffect(
                    ShaderLibrary.applePlaygroundFlow(
                        .float2(.init(x: proxy.size.width, y: proxy.size.height)),
                        .float(time),
                        .float(phase),
                        .float(theme)
                    )
                )
            }
            .allowsHitTesting(false)
    }
}

struct GradientPromptText: View {
    var time: Float

    var body: some View {
        let shift = Double(sin(Double(time) * 0.55)) * 0.06

        Text("Describe an image or\nadd a suggestion\nfrom the list.")
            .font(.system(size: 22, weight: .medium))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .foregroundStyle(
                // Sampled off the reference: the copy is near-white with pastel
                // tints, not the saturated rainbow it looks like at a glance.
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.97, green: 0.78, blue: 0.92), location: 0.0 + shift),
                        .init(color: Color(red: 0.95, green: 0.94, blue: 0.97), location: 0.38),
                        .init(color: Color(red: 0.84, green: 0.70, blue: 0.91), location: 0.68),
                        .init(color: Color(red: 0.76, green: 0.85, blue: 0.92), location: 1.0 - shift)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

private struct Suggestion: Identifiable {
    let id: String
    let name: String
    let glyph: String
    let tint: Color
    let isPhoto: Bool
    /// Index handed to the shader. 0 is the GIF's Starry Night default.
    let theme: Float

    static let row: [Suggestion] = [
        .init(id: "starry", name: "Starry Night", glyph: "🌙", tint: Color(red: 0.40, green: 0.42, blue: 0.82), isPhoto: false, theme: 0),
        .init(id: "brian", name: "Brian Tong", glyph: "person.fill", tint: Color(red: 0.35, green: 0.38, blue: 0.42), isPhoto: true, theme: 1),
        .init(id: "mage", name: "Mage", glyph: "🧙", tint: Color(red: 0.42, green: 0.28, blue: 0.62), isPhoto: false, theme: 2),
        .init(id: "artist", name: "Artist", glyph: "🎨", tint: Color(red: 0.95, green: 0.55, blue: 0.22), isPhoto: false, theme: 3),
        .init(id: "cap", name: "Baseball Cap", glyph: "🧢", tint: Color(red: 0.28, green: 0.48, blue: 0.88), isPhoto: false, theme: 4),
        .init(id: "helmet", name: "Helmet", glyph: "⛑️", tint: Color(red: 0.88, green: 0.32, blue: 0.28), isPhoto: false, theme: 5)
    ]
}

private struct SuggestionChip: View {
    let item: Suggestion
    var selected: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [item.tint.opacity(0.95), item.tint.opacity(0.50)],
                            center: .center,
                            startRadius: 2,
                            endRadius: 34
                        )
                    )
                if item.isPhoto {
                    Image(systemName: item.glyph)
                        .font(.system(size: 26))
                        .foregroundStyle(.white.opacity(0.85))
                } else {
                    Text(item.glyph).font(.system(size: 28))
                }
            }
            .frame(width: 64, height: 64)
            .overlay {
                Circle()
                    .strokeBorder(Color.white, lineWidth: selected ? 2.5 : 0)
            }
            .shadow(color: item.tint.opacity(selected ? 0.55 : 0), radius: 8)

            Text(item.name)
                .font(.system(size: 12, weight: selected ? .semibold : .medium))
                .foregroundStyle(.white.opacity(selected ? 1.0 : 0.88))
                .lineLimit(1)
        }
        .frame(width: 78)
        .opacity(selected ? 1 : 0.78)
    }
}

/// Screenshot harness only — steps the stage machine so the stages can be
/// captured without a human tapping. Off unless ALGD_AUTOSTEP is set.
enum DebugAutoStep {
    static let enabled = ProcessInfo.processInfo.environment["ALGD_AUTOSTEP"] != nil
}

/// The steps the reference walks through. Each one parks the shader at a fixed
/// phase; the button eases between them.
enum PlaygroundStage: Int, CaseIterable {
    case idle       // breathing colour haze + prompt
    case droplet    // haze collapses into the liquid blob
    case textured   // artwork fills the blob
    case card       // blob squares off into the result card

    var phase: Float {
        switch self {
        case .idle:     return 0.00
        case .droplet:  return 0.45
        case .textured: return 0.62
        case .card:     return 1.00
        }
    }

    var label: String {
        switch self {
        case .idle:     return "Idle"
        case .droplet:  return "Droplet"
        case .textured: return "Texture"
        case .card:     return "Card"
        }
    }

    var next: PlaygroundStage {
        PlaygroundStage(rawValue: rawValue + 1) ?? .idle
    }

    /// Timed off the reference GIF at 10fps: the haze takes ~0.8s to fade out
    /// and let the bubble in [35-42], the artwork ~0.4s [56-59], and the
    /// inflate into the card is a fast ~0.35s snap [70-73].
    func duration(to other: PlaygroundStage) -> Double {
        switch (self, other) {
        case (.idle, .droplet):  return 0.80
        case (.droplet, .textured): return 0.45
        case (.textured, .card): return 0.35
        case (.card, .idle):     return 0.55
        default:                 return 0.60
        }
    }
}

struct PlaygroundIdleScreen: View {
    @State private var stage: PlaygroundStage = .idle
    @State private var fromPhase: Float = PlaygroundStage.idle.phase
    @State private var transitionStart = Date.distantPast
    @State private var transitionDuration: Double = 1.0
    @State private var selectedTheme: Float = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let now = timeline.date
            // Wrapped: the raw interval is ~7.8e8, which destroys float32
            // precision inside the shader and freezes every time-based term.
            let time = Float(now.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 600))
            let phase = currentPhase(at: now)
            let textFade = smoothstep(0.02, 0.22, phase)

            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer().frame(height: 48)

                    // The shader layer has to be wider than the art it draws —
                    // the idle haze reaches ~190pt and would clip on its own
                    // bounds. Hanging it off an overlay keeps that extra width
                    // from driving the layout of everything below.
                    Color.clear
                        .frame(height: 430)
                        .overlay {
                            PlaygroundFlowView(time: time, phase: phase, theme: selectedTheme)
                                .frame(width: 480, height: 480)
                        }
                        .overlay {
                            GradientPromptText(time: time)
                                .padding(.horizontal, 36)
                                .opacity(Double(1.0 - textFade))
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { advance() }

                    stageControls
                        .padding(.top, 4)

                    suggestionsSection
                        .padding(.top, 16)

                    Spacer(minLength: 16)

                    inputSection
                }
            }
            .task {
                guard DebugAutoStep.enabled else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(2.5))
                    advance()
                }
            }
        }
    }

    private func advance() { go(to: stage.next) }

    private func go(to target: PlaygroundStage) {
        guard target != stage else { return }
        fromPhase = currentPhase(at: Date())
        transitionDuration = stage.duration(to: target)
        transitionStart = Date()
        stage = target
    }

    /// Eased interpolation from wherever the phase was when the button was hit
    /// to the new stage, so repeated taps never snap.
    private func currentPhase(at now: Date) -> Float {
        let elapsed = now.timeIntervalSince(transitionStart)
        guard elapsed < transitionDuration else { return stage.phase }
        let u = Float(max(elapsed, 0) / transitionDuration)
        let eased = u * u * (3 - 2 * u)
        return fromPhase + (stage.phase - fromPhase) * eased
    }

    private func smoothstep(_ a: Float, _ b: Float, _ x: Float) -> Float {
        let t = min(max((x - a) / (b - a), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// Jump straight to any stage. Stepping forward one at a time makes it
    /// tedious to look at a single transition over and over.
    private var stageControls: some View {
        HStack(spacing: 6) {
            ForEach(PlaygroundStage.allCases, id: \.self) { item in
                let active = item == stage
                Button { go(to: item) } label: {
                    Text(item.label)
                        .font(.system(size: 12, weight: active ? .semibold : .medium))
                        .foregroundStyle(active ? Color.black : .white.opacity(0.72))
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background(active ? Color.white : Color(white: 0.17), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 22)
        .animation(.easeOut(duration: 0.18), value: stage)
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("SUGGESTIONS")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.42))
                Spacer()
                Text("SHOW MORE")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Color(red: 0.92, green: 0.78, blue: 0.28))
            }
            .padding(.horizontal, 22)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(Suggestion.row) { item in
                        Button {
                            withAnimation(.easeOut(duration: 0.22)) {
                                selectedTheme = item.theme
                            }
                        } label: {
                            SuggestionChip(item: item, selected: item.theme == selectedTheme)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 22)
            }
        }
    }

    private var inputSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    IntelligenceMark()
                    Text("Describe an image")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.32))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(Color(white: 0.14), in: Capsule())

                circleButton("person.crop.circle")
                stageButton
            }
            .padding(.horizontal, 16)

            HStack(alignment: .top, spacing: 6) {
                Text("BETA")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(white: 0.18), in: Capsule())
                Text("Images may vary based on description, personalization, or photo selected.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.32))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
        }
    }

    /// Steps idle → droplet → texture → card → idle. Tapping the orb does the
    /// same thing.
    private var stageButton: some View {
        Button(action: advance) {
            VStack(spacing: 1) {
                Image(systemName: stage == .card ? "arrow.counterclockwise" : "arrow.right")
                    .font(.system(size: 15, weight: .semibold))
                Text(stage.next.label)
                    .font(.system(size: 8, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.9))
            .frame(width: 52, height: 44)
            .background(Color(white: 0.18), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func circleButton(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(.white.opacity(0.88))
            .frame(width: 44, height: 44)
            .background(Color(white: 0.14), in: Circle())
    }
}

#Preview {
    PlaygroundIdleScreen()
}
