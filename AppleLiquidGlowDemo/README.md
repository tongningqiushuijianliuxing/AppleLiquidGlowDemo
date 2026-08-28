# AppleLiquidGlowDemo

SwiftUI + Metal Shader demo: blurred color cloud -> liquid blob -> rounded-square flowing light.

## Run
Open `AppleLiquidGlowDemo.xcodeproj` in Xcode 26+, choose an iOS 17+ target, and Run.
Tap Trigger / Reset.

## Main files
- `ContentView.swift`: state + TimelineView animation
- `LiquidGlowView.swift`: SwiftUI -> ShaderLibrary bridge
- `Shaders.metal`: color fields, noise, domain warp, SDF morph, halo/glow

No GIF or video asset is used; the effect is rendered in real time on the GPU.
