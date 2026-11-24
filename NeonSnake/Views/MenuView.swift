import SwiftUI

struct MenuView: View {
    let model: GameModel

    var body: some View {
        let theme = model.theme
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            MenuSnakeView(theme: theme)
                .frame(height: 190)

            VStack(spacing: -12) {
                Text("NEON")
                Text("SNAKE")
            }
            .font(.system(size: 66, weight: .black, design: .rounded))
            .kerning(4)
            .foregroundStyle(
                LinearGradient(colors: [theme.head.color(), theme.tail.color()],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .shadow(color: theme.head.color(0.7), radius: 18)
            .shadow(color: theme.tail.color(0.5), radius: 40)
            .padding(.top, 4)

            Label("Рекорд: \(model.highScore)", systemImage: "crown.fill")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.bonus.color())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.white.opacity(0.07), in: Capsule())
                .padding(.top, 18)

            Spacer(minLength: 20)

            GlowButton(title: "Играть", icon: "play.fill", theme: theme) {
                model.newGame()
            }
            .phaseAnimator([1.0, 1.035]) { content, scale in
                content.scaleEffect(scale)
            } animation: { _ in
                .easeInOut(duration: 1.1)
            }
            .padding(.horizontal, 36)

            ThemePicker(model: model)
                .padding(.top, 28)

            Text("Свайпай, чтобы поворачивать.\nСобирай фрукты, лови золотые звёзды — +5!")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 22)

            Spacer(minLength: 12)
        }
        .padding()
    }
}

struct ThemePicker: View {
    let model: GameModel

    var body: some View {
        HStack(spacing: 26) {
            ForEach(Theme.all) { theme in
                let selected = theme.id == model.theme.id
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        model.themeIndex = theme.id
                    }
                } label: {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(LinearGradient(colors: [theme.head.color(), theme.tail.color()],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 46, height: 46)
                            .overlay(Circle().fill(theme.food.color()).frame(width: 12, height: 12).offset(x: 13, y: 13))
                            .padding(4)
                            .overlay(Circle().strokeBorder(.white, lineWidth: selected ? 2.5 : 0))
                            .shadow(color: theme.head.color(selected ? 0.8 : 0.2), radius: selected ? 12 : 4)
                            .scaleEffect(selected ? 1.08 : 1)
                        Text(theme.name)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(selected ? 1 : 0.55))
                    }
                }
                .buttonStyle(PressableStyle())
            }
        }
        .sensoryFeedback(.selection, trigger: model.themeIndex)
    }
}

/// Decorative snake that endlessly chases a fruit along a figure-eight.
struct MenuSnakeView: View {
    let theme: Theme

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let cell: CGFloat = 22
                let w = Double(size.width)
                let h = Double(size.height)

                func point(_ s: Double) -> CGPoint {
                    CGPoint(x: w / 2 + w * 0.34 * sin(s), y: h / 2 + h * 0.30 * sin(2 * s))
                }

                let head = t * 1.3
                SnakeRenderer.drawOrb(ctx, center: point(head + 0.75), radius: cell * 0.38,
                                      color: theme.food, time: t)
                let points = (0..<26).map { point(head - Double($0) * 0.075) }
                SnakeRenderer.drawSnake(ctx, points: points, cell: cell, theme: theme,
                                        fallbackHeading: CGVector(dx: 1, dy: 0),
                                        deadAmount: 0, time: t)
            }
        }
    }
}
