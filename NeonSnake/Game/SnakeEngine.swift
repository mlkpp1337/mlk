import Foundation

/// A cell on the game grid.
struct GridPoint: Hashable {
    var x: Int
    var y: Int

    static func + (lhs: GridPoint, rhs: GridPoint) -> GridPoint {
        GridPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
}

enum MoveDirection: CaseIterable {
    case up, down, left, right

    var delta: GridPoint {
        switch self {
        case .up: return GridPoint(x: 0, y: -1)
        case .down: return GridPoint(x: 0, y: 1)
        case .left: return GridPoint(x: -1, y: 0)
        case .right: return GridPoint(x: 1, y: 0)
        }
    }

    var opposite: MoveDirection {
        switch self {
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        }
    }
}

enum GameEvent: Equatable {
    case ateFood(GridPoint)
    case ateBonus(GridPoint)
    case bonusSpawned(GridPoint)
    case bonusExpired(GridPoint)
    case died
}

/// Pure game logic: no UI, no timers. One call to `step()` = one move.
struct SnakeEngine {
    /// How many ticks the bonus star stays on the board.
    static let bonusLifetime = 40
    /// A bonus star appears after every N regular fruits.
    static let bonusEvery = 5
    static let bonusPoints = 5

    let columns: Int
    let rows: Int

    /// Snake cells, head first.
    private(set) var body: [GridPoint]
    /// Snake cells before the last move — used for smooth interpolation.
    private(set) var previousBody: [GridPoint]
    private(set) var direction: MoveDirection = .right
    private(set) var food: GridPoint
    private(set) var bonus: GridPoint?
    private(set) var bonusTicksLeft = 0
    private(set) var score = 0
    private(set) var foodEaten = 0
    private(set) var isDead = false

    /// Buffered turns so quick swipes (e.g. up-then-left) are not lost.
    private var pendingTurns: [MoveDirection] = []

    init(columns: Int, rows: Int) {
        self.columns = max(columns, 8)
        self.rows = max(rows, 8)
        let start = GridPoint(x: self.columns / 2, y: self.rows / 2)
        let initial = (0..<4).map { GridPoint(x: start.x - $0, y: start.y) }
        body = initial
        previousBody = initial
        food = GridPoint(x: 0, y: 0)
        food = randomFreeCell() ?? GridPoint(x: 0, y: 0)
    }

    mutating func queueTurn(_ newDirection: MoveDirection) {
        guard !isDead, pendingTurns.count < 3 else { return }
        let reference = pendingTurns.last ?? direction
        guard newDirection != reference, newDirection != reference.opposite else { return }
        pendingTurns.append(newDirection)
    }

    @discardableResult
    mutating func step() -> [GameEvent] {
        guard !isDead else { return [] }

        if !pendingTurns.isEmpty {
            direction = pendingTurns.removeFirst()
        }

        previousBody = body
        let head = body[0] + direction.delta

        // Walls
        guard (0..<columns).contains(head.x), (0..<rows).contains(head.y) else {
            isDead = true
            return [.died]
        }

        let eatsFood = head == food
        let eatsBonus = head == bonus
        let grows = eatsFood || eatsBonus

        // The tail moves out of the way unless the snake grows this tick.
        let obstacles = grows ? body[...] : body.dropLast()
        if obstacles.contains(head) {
            isDead = true
            return [.died]
        }

        var events: [GameEvent] = []
        body.insert(head, at: 0)
        if !grows {
            body.removeLast()
        }

        if eatsFood {
            score += 1
            foodEaten += 1
            events.append(.ateFood(head))
            guard let next = randomFreeCell() else {
                // Board is completely filled — nothing left to eat.
                isDead = true
                events.append(.died)
                return events
            }
            food = next
            if bonus == nil, foodEaten % Self.bonusEvery == 0, let spot = randomFreeCell() {
                bonus = spot
                bonusTicksLeft = Self.bonusLifetime
                events.append(.bonusSpawned(spot))
            }
        }

        if eatsBonus, let eaten = bonus {
            score += Self.bonusPoints
            bonus = nil
            bonusTicksLeft = 0
            events.append(.ateBonus(eaten))
        } else if let current = bonus {
            bonusTicksLeft -= 1
            if bonusTicksLeft <= 0 {
                bonus = nil
                events.append(.bonusExpired(current))
            }
        }

        return events
    }

    private func randomFreeCell() -> GridPoint? {
        var occupied = Set(body)
        occupied.insert(food)
        if let bonus { occupied.insert(bonus) }

        // Fast path: random sampling works almost always.
        for _ in 0..<64 {
            let candidate = GridPoint(x: Int.random(in: 0..<columns), y: Int.random(in: 0..<rows))
            if !occupied.contains(candidate) { return candidate }
        }

        var free: [GridPoint] = []
        for y in 0..<rows {
            for x in 0..<columns {
                let candidate = GridPoint(x: x, y: y)
                if !occupied.contains(candidate) { free.append(candidate) }
            }
        }
        return free.randomElement()
    }
}
