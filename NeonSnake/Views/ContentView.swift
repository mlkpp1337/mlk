import SwiftUI

struct ContentView: View {
    @State private var model = GameModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            ZStack {
                BackgroundView(theme: model.theme)

                if model.phase == .menu {
                    MenuView(model: model)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    GameScreen(model: model)
                        .transition(.opacity)
                }
            }
            .onAppear { model.layoutSize = geo.size }
            .onChange(of: geo.size) { _, newSize in model.layoutSize = newSize }
        }
        .animation(.easeInOut(duration: 0.35), value: model.phase == .menu)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active { model.pause() }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: model.eatFeedback)
        .sensoryFeedback(.success, trigger: model.bonusFeedback)
        .sensoryFeedback(.error, trigger: model.deathFeedback)
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
