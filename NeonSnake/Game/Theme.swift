import SwiftUI

/// Simple RGB color that can be interpolated (SwiftUI `Color` can't on iOS 17).
struct RGB: Equatable {
    var r: Double
    var g: Double
    var b: Double

    init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    func color(_ opacity: Double = 1) -> Color {
        Color(red: r, green: g, blue: b, opacity: opacity)
    }

    func mix(_ other: RGB, _ t: Double) -> RGB {
        RGB(r + (other.r - r) * t, g + (other.g - g) * t, b + (other.b - b) * t)
    }

    func lighter(_ amount: Double) -> RGB { mix(RGB(1, 1, 1), amount) }
    func darker(_ amount: Double) -> RGB { mix(RGB(0, 0, 0), amount) }
}

struct Theme: Identifiable {
    let id: Int
    let name: String
    let head: RGB
    let tail: RGB
    let food: RGB
    let backgroundTop: RGB
    let backgroundBottom: RGB
    let glowA: RGB
    let glowB: RGB

    static let bonus = RGB(1.0, 0.84, 0.28)

    func segmentColor(_ index: Int, of count: Int) -> RGB {
        guard count > 1 else { return head }
        return head.mix(tail, Double(index) / Double(count - 1))
    }

    static let all: [Theme] = [
        Theme(
            id: 0, name: "Неон",
            head: RGB(0.35, 1.0, 0.62), tail: RGB(0.10, 0.55, 1.0), food: RGB(1.0, 0.25, 0.55),
            backgroundTop: RGB(0.04, 0.03, 0.12), backgroundBottom: RGB(0.10, 0.02, 0.19),
            glowA: RGB(0.55, 0.20, 1.0), glowB: RGB(0.0, 0.65, 0.95)
        ),
        Theme(
            id: 1, name: "Закат",
            head: RGB(1.0, 0.86, 0.32), tail: RGB(1.0, 0.28, 0.45), food: RGB(0.35, 0.92, 1.0),
            backgroundTop: RGB(0.13, 0.03, 0.08), backgroundBottom: RGB(0.20, 0.05, 0.12),
            glowA: RGB(1.0, 0.45, 0.20), glowB: RGB(0.90, 0.20, 0.60)
        ),
        Theme(
            id: 2, name: "Океан",
            head: RGB(0.55, 0.95, 1.0), tail: RGB(0.22, 0.32, 1.0), food: RGB(1.0, 0.70, 0.28),
            backgroundTop: RGB(0.01, 0.05, 0.12), backgroundBottom: RGB(0.0, 0.11, 0.19),
            glowA: RGB(0.0, 0.70, 0.70), glowB: RGB(0.20, 0.30, 1.0)
        ),
    ]
}
