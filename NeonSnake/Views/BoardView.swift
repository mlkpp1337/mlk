import SwiftUI

/// The playing field, rendered every frame with `Canvas`.
struct BoardView: View {
    let model: GameModel

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                draw(ctx, size: size, date: timeline.date)
            }
        }
    }

    private func draw(_ context: GraphicsContext, size: CGSize, date: Date) {
        let engine = model.engine
        let theme = model.theme
        let time = date.timeIntervalSinceReferenceDate

        let columns = CGFloat(engine.columns)
        let rows = CGFloat(engine.rows)
        let cell = min(size.width / columns, size.height / rows)
        let boardSize = CGSize(width: cell * columns, height: cell * rows)

        var ctx = context
        ctx.translateBy(x: (size.width - boardSize.width) / 2, y: (size.height - boardSize.height) / 2)

        // Screen shake right after a crash.
        var deathAge: Double?
        if let deathDate = model.deathDate {
            let age = date.timeIntervalSince(deathDate)
            deathAge = age
            if age < 0.5 {
                let amplitude = (1 - age / 0.5) * Double(cell) * 0.35
                ctx.translateBy(x: CGFloat(sin(age * 90) * amplitude), y: CGFloat(cos(age * 77) * amplitude))
            }
        }

        let boardRect = CGRect(origin: .zero, size: boardSize)
        let boardPath = Path(roundedRect: boardRect, cornerRadius: cell * 0.6, style: .continuous)
        let borderShading = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [theme.head.color(), theme.tail.color(), theme.food.color()]),
            startPoint: .zero,
            endPoint: CGPoint(x: boardSize.width, y: boardSize.height)
        )

        // Board background + checker tiles.
        ctx.fill(boardPath, with: .color(.black.opacity(0.38)))
        var even = Path()
        var odd = Path()
        let inset = cell * 0.07
        let corner = CGSize(width: cell * 0.22, height: cell * 0.22)
        for y in 0..<engine.rows {
            for x in 0..<engine.columns {
                let tile = CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell)
                    .insetBy(dx: inset, dy: inset)
                if (x + y) % 2 == 0 {
                    even.addRoundedRect(in: tile, cornerSize: corner)
                } else {
                    odd.addRoundedRect(in: tile, cornerSize: corner)
                }
            }
        }
        var tiles = ctx
        tiles.clip(to: boardPath)
        tiles.fill(even, with: .color(.white.opacity(0.045)))
        tiles.fill(odd, with: .color(.white.opacity(0.022)))

        // Neon border.
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: cell * 0.4))
            layer.opacity = 0.8
            layer.stroke(boardPath, with: borderShading, lineWidth: cell * 0.16)
        }
        ctx.stroke(boardPath, with: borderShading, lineWidth: max(1.5, cell * 0.07))

        func center(_ p: GridPoint) -> CGPoint {
            CGPoint(x: (CGFloat(p.x) + 0.5) * cell, y: (CGFloat(p.y) + 0.5) * cell)
        }

        // Fruit (pops in with an overshoot).
        let birthAge = min(1, max(0, date.timeIntervalSince(model.foodBorn) / 0.35))
        let pop = SnakeRenderer.easeOutBack(birthAge)
        let pulse = 1 + 0.08 * sin(time * 5)
        SnakeRenderer.drawOrb(ctx, center: center(engine.food),
                              radius: cell * 0.36 * CGFloat(pulse * pop),
                              color: theme.food, time: time)

        // Bonus star.
        if let bonus = engine.bonus {
            let remaining = Double(engine.bonusTicksLeft) / Double(SnakeEngine.bonusLifetime)
            let blink = engine.bonusTicksLeft < 10 && sin(time * 25) < 0 ? 0.35 : 1.0
            SnakeRenderer.drawBonus(ctx, center: center(bonus), radius: cell * 0.5,
                                    time: time, remaining: remaining, opacity: blink)
        }

        // Snake, smoothly interpolated between the previous and current cells.
        let progress = CGFloat(model.progress(at: date))
        let body = engine.body
        let previous = engine.previousBody
        let points: [CGPoint] = body.indices.map { i in
            let to = center(body[i])
            let from = center(i < previous.count ? previous[i] : previous[previous.count - 1])
            return CGPoint(x: from.x + (to.x - from.x) * progress, y: from.y + (to.y - from.y) * progress)
        }
        let delta = engine.direction.delta
        let deadAmount = deathAge.map { min(1, $0 / 0.4) } ?? 0
        SnakeRenderer.drawSnake(ctx, points: points, cell: cell, theme: theme,
                                fallbackHeading: CGVector(dx: CGFloat(delta.x), dy: CGFloat(delta.y)),
                                deadAmount: deadAmount, time: time)

        // Crash flash.
        if let age = deathAge, age < 0.25 {
            ctx.fill(boardPath, with: .color(.white.opacity(0.22 * (1 - age / 0.25))))
        }

        // Particles (additive blending for a neon look).
        var sparks = ctx
        sparks.blendMode = .plusLighter
        for p in model.particles {
            let age = date.timeIntervalSince(p.birth)
            guard age >= 0, age < p.life else { continue }
            let k = age / p.life
            let travel = age * (1 - 0.5 * k)
            let x = p.x + p.vx * travel
            let y = p.y + p.vy * travel + 1.5 * age * age
            let radius = CGFloat(p.size * (1 - k)) * cell
            sparks.fill(circlePath(CGPoint(x: CGFloat(x) * cell, y: CGFloat(y) * cell), radius),
                        with: .color(p.color.color(1 - k)))
        }

        // Floating score popups.
        for popup in model.popups {
            let age = date.timeIntervalSince(popup.birth)
            guard age >= 0, age < 0.9 else { continue }
            let k = age / 0.9
            var c = ctx
            c.opacity = 1 - k * k
            c.addFilter(.shadow(color: popup.color.color(0.9), radius: cell * 0.3))
            let text = Text(popup.text)
                .font(.system(size: cell * 0.8, weight: .heavy, design: .rounded))
                .foregroundStyle(popup.color.lighter(0.3).color())
            c.draw(text, at: CGPoint(x: CGFloat(popup.x) * cell, y: CGFloat(popup.y - 0.6 - k * 1.4) * cell))
        }
    }
}
