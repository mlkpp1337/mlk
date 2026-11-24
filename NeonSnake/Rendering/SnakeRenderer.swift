import SwiftUI

extension CGRect {
    init(center: CGPoint, radius: CGFloat) {
        self.init(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }
}

func circlePath(_ center: CGPoint, _ radius: CGFloat) -> Path {
    Path(ellipseIn: CGRect(center: center, radius: radius))
}

/// Drawing helpers shared by the game board and the animated menu.
enum SnakeRenderer {

    // MARK: - Snake

    static func drawSnake(
        _ ctx: GraphicsContext,
        points: [CGPoint],
        cell: CGFloat,
        theme: Theme,
        fallbackHeading: CGVector,
        deadAmount: Double,
        time: Double
    ) {
        guard let headPoint = points.first else { return }
        let count = points.count
        let gray = RGB(0.42, 0.42, 0.48)

        func width(_ i: Int) -> CGFloat {
            let t = count > 1 ? CGFloat(i) / CGFloat(count - 1) : 0
            return cell * (0.84 - 0.30 * t)
        }

        func color(_ i: Int) -> RGB {
            let base = theme.segmentColor(i, of: count)
            return deadAmount > 0 ? base.mix(gray, deadAmount * 0.75) : base
        }

        // 1. Soft neon glow under the whole body.
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: cell * 0.45))
            layer.opacity = 0.8 * (1 - deadAmount * 0.6)
            for i in stride(from: count - 1, through: 0, by: -1) {
                layer.fill(circlePath(points[i], width(i) * 0.75), with: .color(color(i).color()))
            }
        }

        // 2. Dark outline for depth.
        for i in stride(from: count - 1, through: 1, by: -1) {
            var segment = Path()
            segment.move(to: points[i])
            segment.addLine(to: points[i - 1])
            ctx.stroke(segment, with: .color(color(i).darker(0.55).color()),
                       style: StrokeStyle(lineWidth: width(i) + cell * 0.09, lineCap: .round))
        }

        // 3. Body fill (tail first so segments closer to the head sit on top).
        for i in stride(from: count - 1, through: 1, by: -1) {
            var segment = Path()
            segment.move(to: points[i])
            segment.addLine(to: points[i - 1])
            ctx.stroke(segment, with: .color(color(i).color()),
                       style: StrokeStyle(lineWidth: width(i), lineCap: .round))
        }

        // 4. Scale beads.
        for i in stride(from: 1, to: count, by: 2) {
            ctx.fill(circlePath(points[i], width(i) * 0.2), with: .color(color(i).darker(0.35).color(0.5)))
        }

        // 5. Glossy highlight stripe → looks like a tube.
        let shine = CGSize(width: -cell * 0.09, height: -cell * 0.11)
        for i in stride(from: count - 1, through: 1, by: -1) {
            var segment = Path()
            segment.move(to: CGPoint(x: points[i].x + shine.width, y: points[i].y + shine.height))
            segment.addLine(to: CGPoint(x: points[i - 1].x + shine.width, y: points[i - 1].y + shine.height))
            ctx.stroke(segment, with: .color(.white.opacity(0.22)),
                       style: StrokeStyle(lineWidth: width(i) * 0.28, lineCap: .round))
        }

        // 6. Head.
        var heading = fallbackHeading
        if count > 1 {
            let dx = points[0].x - points[1].x
            let dy = points[0].y - points[1].y
            let length = sqrt(dx * dx + dy * dy)
            if length > 0.001 {
                heading = CGVector(dx: dx / length, dy: dy / length)
            }
        }
        let side = CGVector(dx: -heading.dy, dy: heading.dx)
        let headRadius = cell * 0.5
        let headColor = color(0)

        // Tongue flick.
        if deadAmount == 0, time.truncatingRemainder(dividingBy: 1.8) < 0.22 {
            let base = CGPoint(x: headPoint.x + heading.dx * headRadius * 0.8,
                               y: headPoint.y + heading.dy * headRadius * 0.8)
            let tip = CGPoint(x: base.x + heading.dx * cell * 0.38, y: base.y + heading.dy * cell * 0.38)
            var tongue = Path()
            tongue.move(to: base)
            tongue.addLine(to: tip)
            for s: CGFloat in [-1, 1] {
                tongue.move(to: tip)
                tongue.addLine(to: CGPoint(
                    x: tip.x + heading.dx * cell * 0.13 + side.dx * cell * 0.1 * s,
                    y: tip.y + heading.dy * cell * 0.13 + side.dy * cell * 0.1 * s))
            }
            ctx.stroke(tongue, with: .color(RGB(1, 0.25, 0.4).color()),
                       style: StrokeStyle(lineWidth: cell * 0.07, lineCap: .round, lineJoin: .round))
        }

        ctx.fill(circlePath(headPoint, headRadius + cell * 0.045), with: .color(headColor.darker(0.55).color()))
        ctx.fill(
            circlePath(headPoint, headRadius),
            with: .radialGradient(
                Gradient(colors: [headColor.lighter(0.5).color(), headColor.color(), headColor.darker(0.25).color()]),
                center: CGPoint(x: headPoint.x - headRadius * 0.35, y: headPoint.y - headRadius * 0.35),
                startRadius: 0,
                endRadius: headRadius * 1.6
            )
        )

        // Eyes.
        for s: CGFloat in [-1, 1] {
            let eye = CGPoint(
                x: headPoint.x + heading.dx * cell * 0.13 + side.dx * cell * 0.22 * s,
                y: headPoint.y + heading.dy * cell * 0.13 + side.dy * cell * 0.22 * s
            )
            if deadAmount > 0 {
                let k = cell * 0.09
                var cross = Path()
                cross.move(to: CGPoint(x: eye.x - k, y: eye.y - k))
                cross.addLine(to: CGPoint(x: eye.x + k, y: eye.y + k))
                cross.move(to: CGPoint(x: eye.x + k, y: eye.y - k))
                cross.addLine(to: CGPoint(x: eye.x - k, y: eye.y + k))
                ctx.stroke(cross, with: .color(.black.opacity(0.8)),
                           style: StrokeStyle(lineWidth: cell * 0.06, lineCap: .round))
            } else {
                ctx.fill(circlePath(eye, cell * 0.14), with: .color(.white))
                let pupil = CGPoint(x: eye.x + heading.dx * cell * 0.05, y: eye.y + heading.dy * cell * 0.05)
                ctx.fill(circlePath(pupil, cell * 0.075), with: .color(Color(red: 0.05, green: 0.05, blue: 0.1)))
                ctx.fill(circlePath(CGPoint(x: pupil.x - cell * 0.03, y: pupil.y - cell * 0.03), cell * 0.025),
                         with: .color(.white))
            }
        }
    }

    // MARK: - Fruit

    static func drawOrb(_ ctx: GraphicsContext, center: CGPoint, radius: CGFloat, color: RGB, time: Double) {
        guard radius > 0.5 else { return }

        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: radius * 1.1))
            layer.fill(circlePath(center, radius * 1.35), with: .color(color.color(0.9)))
        }

        ctx.fill(circlePath(center, radius), with: .radialGradient(
            Gradient(colors: [color.lighter(0.7).color(), color.color(), color.darker(0.4).color()]),
            center: CGPoint(x: center.x - radius * 0.35, y: center.y - radius * 0.35),
            startRadius: 0,
            endRadius: radius * 1.5
        ))

        // Specular highlight.
        ctx.fill(
            Path(ellipseIn: CGRect(x: center.x - radius * 0.55, y: center.y - radius * 0.62,
                                   width: radius * 0.55, height: radius * 0.36)),
            with: .color(.white.opacity(0.75))
        )

        // Orbiting sparkle.
        let angle = CGFloat(time * 2.4)
        let sparkle = CGPoint(x: center.x + cos(angle) * radius * 1.45, y: center.y + sin(angle) * radius * 1.45)
        var glow = ctx
        glow.blendMode = .plusLighter
        glow.fill(circlePath(sparkle, radius * 0.16), with: .color(color.lighter(0.6).color(0.9)))
    }

    // MARK: - Bonus star

    static func starPath(center: CGPoint, outer: CGFloat, inner: CGFloat, rotation: CGFloat) -> Path {
        var path = Path()
        for i in 0..<10 {
            let r = i.isMultiple(of: 2) ? outer : inner
            let a = rotation + CGFloat(i) * .pi / 5 - .pi / 2
            let point = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    static func drawBonus(_ ctx: GraphicsContext, center: CGPoint, radius: CGFloat,
                          time: Double, remaining: Double, opacity: Double) {
        var c = ctx
        c.opacity = opacity
        let gold = Theme.bonus
        let rotation = CGFloat(time * 1.4)
        let pulse = CGFloat(1 + 0.07 * sin(time * 7))
        let star = starPath(center: center, outer: radius * 0.92 * pulse, inner: radius * 0.42 * pulse, rotation: rotation)

        c.drawLayer { layer in
            layer.addFilter(.blur(radius: radius * 0.8))
            layer.fill(star, with: .color(gold.color()))
        }
        c.fill(star, with: .radialGradient(
            Gradient(colors: [gold.lighter(0.7).color(), gold.color(), RGB(0.95, 0.5, 0.1).color()]),
            center: CGPoint(x: center.x - radius * 0.2, y: center.y - radius * 0.3),
            startRadius: 0,
            endRadius: radius
        ))
        c.stroke(star, with: .color(gold.darker(0.5).color()), lineWidth: max(1, radius * 0.06))

        // Countdown ring.
        var ring = Path()
        ring.addArc(center: center, radius: radius * 1.15,
                    startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * remaining), clockwise: false)
        c.stroke(ring, with: .color(gold.color(0.85)),
                 style: StrokeStyle(lineWidth: max(1.5, radius * 0.1), lineCap: .round))
    }

    static func easeOutBack(_ x: Double) -> Double {
        let c1 = 1.70158
        let c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }
}
