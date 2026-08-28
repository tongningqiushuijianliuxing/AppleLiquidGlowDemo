import SwiftUI

struct LiquidGlowView: View {
    var time: Float
    var morph: Float
    var energy: Float
    var reveal: Float
    var pulse: Float

    var body: some View {
        Rectangle()
            .fill(.clear)
            .visualEffect { content, proxy in
                content.colorEffect(
                    ShaderLibrary.appleLiquid(
                        .float2(
                            .init(
                                x: proxy.size.width,
                                y: proxy.size.height
                            )
                        ),
                        .float(time),
                        .float(morph),
                        .float(energy),
                        .float(reveal),
                        .float(pulse)
                    )
                )
            }
            .allowsHitTesting(false)
    }
}
