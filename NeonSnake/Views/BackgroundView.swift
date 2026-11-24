import SwiftUI

/// Deep gradient with slowly drifting aurora blobs and twinkling stars.
struct BackgroundView: View {
    let theme: Theme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let rect = CGRect(origin: .zero, size: size)

                ctx.fill(Path(rect), with: .linearGradient(
                    Gradient(colors: [theme.backgroundTop.color(), theme.backgroundBottom.color()]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width * 0.3, y: size.height)
                ))

                let blobs: [(RGB, Double, Double, Double)] = [
                    (theme.glowA, 0.15, 0.12, 0.0),
                    (theme.glowB, 0.90, 0.50, 2.0),
                    (theme.glowA, 0.30, 0.92, 4.0),
                ]
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: 80))
                    for (color, bx, by, phase) in blobs {
                        let x = (bx + 0.12 * sin(t * 0.21 + phase)) * Double(size.width)
                        let y = (by + 0.08 * cos(t * 0.17 + phase * 1.3)) * Double(size.height)
                        layer.fill(circlePath(CGPoint(x: x, y: y), size.width * 0.45),
                                   with: .color(color.color(0.32)))
                    }
                }

                // Deterministic pseudo-random star field.
                for i in 0..<70 {
                    let fx = fract(sin(Double(i) * 12.9898) * 43758.5453)
                    let fy = fract(sin(Double(i) * 78.233) * 12543.123)
                    let speed = 0.8 + fract(Double(i) * 0.618) * 2
                    let twinkle = 0.25 + 0.75 * (0.5 + 0.5 * sin(t * speed + Double(i)))
                    let radius = 0.6 + fract(Double(i) * 0.371) * 1.2
                    ctx.fill(circlePath(CGPoint(x: fx * Double(size.width), y: fy * Double(size.height)), radius),
                             with: .color(.white.opacity(0.55 * twinkle)))
                }
            }
        }
        .ignoresSafeArea()
    }

    private func fract(_ x: Double) -> Double { x - floor(x) }
}
