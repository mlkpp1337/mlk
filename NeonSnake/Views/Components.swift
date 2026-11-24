import SwiftUI

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Main call-to-action button with a theme gradient and glow.
struct GlowButton: View {
    let title: String
    let icon: String
    let theme: Theme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.black.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [theme.head.color(), theme.tail.color()],
                                   startPoint: .leading, endPoint: .trailing),
                    in: Capsule()
                )
                .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                .shadow(color: theme.head.color(0.55), radius: 16, y: 4)
        }
        .buttonStyle(PressableStyle())
    }
}

struct SecondaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }
}

/// Frosted-glass card used by the pause and game-over screens.
struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 16) { content }
            .padding(28)
            .frame(maxWidth: 340)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 30, y: 10)
            .padding(24)
    }
}

struct PauseOverlay: View {
    let model: GameModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            GlassCard {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(model.theme.head.color())
                    .shadow(color: model.theme.head.color(0.7), radius: 14)
                Text("Пауза")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                GlowButton(title: "Продолжить", icon: "play.fill", theme: model.theme) {
                    model.resume()
                }
                SecondaryButton(title: "В меню", icon: "house.fill") {
                    model.backToMenu()
                }
            }
        }
    }
}

struct GameOverOverlay: View {
    let model: GameModel
    @State private var appeared = false

    var body: some View {
        let theme = model.theme
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            GlassCard {
                if model.isNewRecord {
                    Label("Новый рекорд!", systemImage: "crown.fill")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Theme.bonus.color(), in: Capsule())
                        .shadow(color: Theme.bonus.color(0.7), radius: 12)
                        .symbolEffect(.bounce, value: appeared)
                }

                Text("Игра окончена")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text("\(appeared ? model.engine.score : 0)")
                    .font(.system(size: 84, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(
                        LinearGradient(colors: [theme.head.color(), theme.tail.color()],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: theme.head.color(0.6), radius: 20)
                    .contentTransition(.numericText(value: Double(appeared ? model.engine.score : 0)))

                HStack(spacing: 12) {
                    MiniStat(icon: "crown.fill", title: "Рекорд", value: model.highScore, tint: Theme.bonus)
                    MiniStat(icon: "ruler.fill", title: "Длина", value: model.engine.body.count, tint: theme.head)
                }

                GlowButton(title: "Ещё раз", icon: "arrow.counterclockwise", theme: theme) {
                    model.newGame()
                }
                SecondaryButton(title: "В меню", icon: "house.fill") {
                    model.backToMenu()
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7).delay(0.15)) { appeared = true }
        }
    }
}

struct MiniStat: View {
    let icon: String
    let title: String
    let value: Int
    let tint: RGB

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(tint.color())
            Text("\(value)")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
