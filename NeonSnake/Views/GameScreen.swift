import SwiftUI

struct GameScreen: View {
    let model: GameModel
    @State private var dragAnchor: CGPoint?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 14) {
            HUDView(model: model)

            BoardView(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text("Свайпай в любом месте экрана")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .opacity(model.engine.score == 0 && model.phase == .playing ? 1 : 0)
                .animation(.easeOut(duration: 0.4), value: model.engine.score)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .contentShape(Rectangle())
        .gesture(swipe)
        .overlay {
            ZStack {
                if model.phase == .paused {
                    PauseOverlay(model: model)
                        .transition(.opacity)
                }
                if model.phase == .gameOver {
                    GameOverOverlay(model: model)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: model.phase)
        }
        // Arrow keys / space work with a hardware keyboard and in the Simulator.
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow, .space]) { press in
            switch press.key {
            case .upArrow: model.turn(.up)
            case .downArrow: model.turn(.down)
            case .leftArrow: model.turn(.left)
            case .rightArrow: model.turn(.right)
            case .space: model.togglePause()
            default: return .ignored
            }
            return .handled
        }
        .onAppear { focused = true }
    }

    /// Turns every ~22pt of finger travel, so one continuous drag can do several turns.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let anchor = dragAnchor ?? value.startLocation
                let dx = value.location.x - anchor.x
                let dy = value.location.y - anchor.y
                guard max(abs(dx), abs(dy)) > 22 else {
                    if dragAnchor == nil { dragAnchor = anchor }
                    return
                }
                let direction: MoveDirection
                if abs(dx) > abs(dy) {
                    direction = dx > 0 ? .right : .left
                } else {
                    direction = dy > 0 ? .down : .up
                }
                model.turn(direction)
                dragAnchor = value.location
            }
            .onEnded { _ in dragAnchor = nil }
    }
}

struct HUDView: View {
    let model: GameModel

    var body: some View {
        HStack(spacing: 10) {
            StatPill(title: "СЧЁТ", value: model.engine.score, icon: "sparkles", tint: model.theme.head)
            StatPill(title: "РЕКОРД", value: max(model.highScore, model.engine.score),
                     icon: "crown.fill", tint: Theme.bonus)
            Spacer(minLength: 0)
            Button {
                model.togglePause()
            } label: {
                Image(systemName: model.phase == .paused ? "play.fill" : "pause.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.15)))
            }
            .buttonStyle(PressableStyle())
            .disabled(model.phase != .playing && model.phase != .paused)
        }
    }
}

struct StatPill: View {
    let title: String
    let value: Int
    let icon: String
    let tint: RGB

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint.color())
                .shadow(color: tint.color(0.8), radius: 6)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .kerning(1.2)
                    .foregroundStyle(.white.opacity(0.55))
                Text("\(value)")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(value)))
                    .animation(.snappy, value: value)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(tint.color(0.35), lineWidth: 1))
    }
}
