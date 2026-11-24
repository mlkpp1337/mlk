import SwiftUI
import Observation

enum GamePhase: Equatable {
    case menu
    case playing
    case paused
    case dying
    case gameOver
}

/// A spark from an explosion. Positions/velocities are in grid-cell units.
struct Particle {
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var birth: Date
    var life: Double
    var size: Double
    var color: RGB
}

/// Floating "+1" text.
struct ScorePopup {
    var x: Double
    var y: Double
    var text: String
    var color: RGB
    var birth: Date
}

@MainActor
@Observable
final class GameModel {
    static let baseInterval = 0.15
    static let minInterval = 0.065
    static let speedUpPerFruit = 0.0035

    var phase: GamePhase = .menu
    private(set) var engine = SnakeEngine(columns: 17, rows: 28)
    private(set) var lastTick = Date()
    private(set) var tickInterval = GameModel.baseInterval
    private(set) var particles: [Particle] = []
    private(set) var popups: [ScorePopup] = []
    private(set) var foodBorn = Date()
    private(set) var deathDate: Date?
    private(set) var isNewRecord = false

    // Counters used as haptic feedback triggers.
    private(set) var eatFeedback = 0
    private(set) var bonusFeedback = 0
    private(set) var deathFeedback = 0

    var highScore: Int = UserDefaults.standard.integer(forKey: "highScore") {
        didSet { UserDefaults.standard.set(highScore, forKey: "highScore") }
    }

    var themeIndex: Int = UserDefaults.standard.integer(forKey: "themeIndex") {
        didSet { UserDefaults.standard.set(themeIndex, forKey: "themeIndex") }
    }

    var theme: Theme { Theme.all[abs(themeIndex) % Theme.all.count] }

    /// Size of the safe-area screen, used to pick a grid that fills the board.
    @ObservationIgnored var layoutSize = CGSize(width: 390, height: 760)
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var frozenProgress: Double = 0

    // MARK: - Game flow

    func newGame() {
        loop?.cancel()

        let columns = layoutSize.width > 600 ? 24 : 17
        let boardWidth = max(layoutSize.width - 28, 200)
        let boardHeight = max(layoutSize.height - 124, 200)
        let cell = boardWidth / CGFloat(columns)
        let rows = max(14, Int(boardHeight / cell))

        let now = Date()
        engine = SnakeEngine(columns: columns, rows: rows)
        tickInterval = Self.baseInterval
        particles = []
        popups = []
        deathDate = nil
        isNewRecord = false
        foodBorn = now
        lastTick = now
        phase = .playing
        startLoop(firstDelay: 0.45)
    }

    func turn(_ direction: MoveDirection) {
        guard phase == .playing else { return }
        engine.queueTurn(direction)
    }

    func pause() {
        guard phase == .playing else { return }
        frozenProgress = progress(at: Date())
        loop?.cancel()
        loop = nil
        phase = .paused
    }

    func resume() {
        guard phase == .paused else { return }
        lastTick = Date().addingTimeInterval(-frozenProgress * tickInterval)
        phase = .playing
        startLoop(firstDelay: max(0.02, (1 - frozenProgress) * tickInterval))
    }

    func togglePause() {
        if phase == .playing {
            pause()
        } else {
            resume()
        }
    }

    func backToMenu() {
        loop?.cancel()
        loop = nil
        phase = .menu
    }

    /// 0…1 — how far the snake is between the previous and the current cell.
    func progress(at date: Date) -> Double {
        switch phase {
        case .playing:
            return min(max(date.timeIntervalSince(lastTick) / tickInterval, 0), 1)
        case .paused:
            return frozenProgress
        default:
            return 1
        }
    }

    // MARK: - Loop

    private func startLoop(firstDelay: Double) {
        loop?.cancel()
        loop = Task { [weak self] in
            var delay = firstDelay
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled, let self else { return }
                self.tick()
                delay = self.tickInterval
            }
        }
    }

    private func tick() {
        guard phase == .playing else { return }
        let now = Date()
        let events = engine.step()
        lastTick = now

        particles.removeAll { now.timeIntervalSince($0.birth) > $0.life }
        popups.removeAll { now.timeIntervalSince($0.birth) > 1 }

        for event in events {
            switch event {
            case .ateFood(let point):
                burst(at: point, color: theme.food, count: 18, speed: 4, now: now)
                popups.append(ScorePopup(x: Double(point.x) + 0.5, y: Double(point.y) + 0.5,
                                         text: "+1", color: theme.food, birth: now))
                foodBorn = now
                eatFeedback += 1
            case .ateBonus(let point):
                burst(at: point, color: Theme.bonus, count: 34, speed: 6, now: now)
                popups.append(ScorePopup(x: Double(point.x) + 0.5, y: Double(point.y) + 0.5,
                                         text: "+\(SnakeEngine.bonusPoints)", color: Theme.bonus, birth: now))
                bonusFeedback += 1
            case .bonusSpawned(let point):
                burst(at: point, color: Theme.bonus, count: 10, speed: 2, now: now)
            case .bonusExpired(let point):
                burst(at: point, color: Theme.bonus.darker(0.3), count: 10, speed: 1.5, now: now)
            case .died:
                die(now: now)
            }
        }

        tickInterval = max(Self.minInterval,
                           Self.baseInterval - Double(engine.foodEaten) * Self.speedUpPerFruit)
    }

    private func die(now: Date) {
        loop?.cancel()
        loop = nil
        deathDate = now
        phase = .dying
        deathFeedback += 1

        let body = engine.body
        burst(at: body[0], color: theme.head, count: 40, speed: 7, now: now)
        for (index, point) in body.enumerated() where index % 2 == 0 {
            burst(at: point, color: theme.segmentColor(index, of: body.count), count: 3, speed: 2.5, now: now)
        }

        if engine.score > highScore {
            highScore = engine.score
            isNewRecord = true
        }

        Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.9))
            guard let self, self.phase == .dying else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.phase = .gameOver
            }
        }
    }

    private func burst(at point: GridPoint, color: RGB, count: Int, speed: Double, now: Date) {
        let cx = Double(point.x) + 0.5
        let cy = Double(point.y) + 0.5
        for _ in 0..<count {
            let angle = Double.random(in: 0..<(2 * Double.pi))
            let velocity = speed * Double.random(in: 0.35...1.0)
            particles.append(Particle(
                x: cx, y: cy,
                vx: cos(angle) * velocity, vy: sin(angle) * velocity,
                birth: now,
                life: Double.random(in: 0.45...0.9),
                size: Double.random(in: 0.08...0.2),
                color: color
            ))
        }
    }
}
