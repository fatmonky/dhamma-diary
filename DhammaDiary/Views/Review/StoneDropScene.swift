import SpriteKit
import SwiftUI

/// Daily Review's falling stones (spec 10.2): the day's stones drop one by one
/// into two heaps, white on the left from the top-left corner and black on the
/// right from the top-right, with an invisible wall between them (PJ, 28 Nov:
/// one mixed heap of 40 was a mess). Each landed stone is drawn towards its
/// heap's centre with an oval pull, so the heap gathers into the outline of
/// one large stone made of the small ones (PJ, 28 Nov: "a composite stone").
final class StoneDropScene: SKScene, SKPhysicsContactDelegate {
    private enum Category {
        static let stone: UInt32 = 1 << 0
        static let palm: UInt32 = 1 << 1
    }

    private let types: [StoneType]
    private let feedback: StoneDropFeedback
    private let interval: TimeInterval
    private let radius: CGFloat

    private var nextIndex = 0
    private var stones: [SKSpriteNode] = []
    /// Stones that have touched something since they fell.
    private var landed: Set<ObjectIdentifier> = []
    /// Sides whose palm already holds a stone: later landings there sound heavier.
    private var occupied: Set<StoneType> = []
    private var lastClack: TimeInterval = 0
    private var lastDropTime: TimeInterval?
    private var lastUpdate: TimeInterval?
    /// Each colour's composite stone: centre and half-width/half-height.
    private var ovals: [StoneType: (centre: CGPoint, a: CGFloat, b: CGFloat)] = [:]
    /// How hard landed stones are drawn in, in points per second squared at the oval's edge.
    private let pull: CGFloat = 1100
    private var stillSince: TimeInterval?
    private var hasSettled = false
    private var isBuilt = false
    private var placeQuietlyOnMove = false

    /// Called once, when the pile has come to rest (or on skip).
    var onSettled: () -> Void = {}

    init(types: [StoneType], size: CGSize, feedback: StoneDropFeedback) {
        self.types = types
        self.feedback = feedback
        self.interval = DailyReview.dropInterval(forCount: types.count)
        // Smaller stones for a big day, so each heap stays in its half.
        let largest = max(types.filter { $0 == .white }.count, types.filter { $0 == .black }.count)
        self.radius = switch largest {
        case ..<8: 22
        case ..<16: 18
        case ..<28: 15
        case ..<45: 12
        default: 10
        }
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func didMove(to view: SKView) {
        guard !isBuilt else { return }
        isBuilt = true
        view.allowsTransparency = true
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        physicsWorld.contactDelegate = self
        buildPalm()
        buildOvals()
        if placeQuietlyOnMove {
            dropAllQuietly()
            return
        }
        run(.sequence([
            .wait(forDuration: 0.4),
            .repeat(.sequence([.run { [weak self] in self?.dropNext() }, .wait(forDuration: interval)]), count: types.count),
        ]), withKey: "drops")
    }

    /// Two shallow hollows along the bottom, one per colour, each walled in:
    /// the screen edge on the outside and a full-height invisible wall in the
    /// middle, so no stone crosses. SpriteKit's y runs upwards.
    private func buildPalm() {
        for side in [StoneType.white, .black] {
            let path = CGMutablePath()
            // A small gap either side of the middle keeps the heaps apart.
            let gap: CGFloat = 10
            let (from, to) = side == .white ? (CGFloat(0), size.width / 2 - gap) : (size.width / 2 + gap, size.width)
            let floor: CGFloat = 16
            let rim: CGFloat = 60
            let centre = (from + to) / 2
            let half = (to - from) / 2
            path.move(to: CGPoint(x: from, y: size.height * 3))
            let steps = 16
            for i in 0...steps {
                let x = from + (to - from) * CGFloat(i) / CGFloat(steps)
                let u = (x - centre) / half
                path.addLine(to: CGPoint(x: x, y: floor + rim * pow(abs(u), 2.2)))
            }
            path.addLine(to: CGPoint(x: to, y: size.height * 3))
            let body = SKPhysicsBody(edgeChainFrom: path)
            body.friction = 0.8
            body.restitution = 0.15
            body.categoryBitMask = Category.palm
            let palm = SKNode()
            palm.physicsBody = body
            addChild(palm)
        }
    }

    /// Sizes each composite stone to hold its stones, packed loosely: an oval
    /// half as wide again as tall, resting on the palm in the middle of its half.
    private func buildOvals() {
        let stoneArea = CGFloat.pi * radius * radius * 0.82
        for side in [StoneType.white, .black] {
            let count = CGFloat(max(types.filter { $0 == side }.count, 1))
            let b = (count * stoneArea / 0.8 / (.pi * 1.5)).squareRoot()
            let a = b * 1.5
            ovals[side] = (CGPoint(x: centreX(of: side), y: 18 + b), a, b)
        }
    }

    /// Once a stone has landed it leaves gravity and is drawn towards its
    /// oval's centre instead, harder along the short axis, so the heap packs
    /// into an oval rather than a round blob.
    private func gather(_ dt: TimeInterval) {
        for stone in stones where landed.contains(ObjectIdentifier(stone)) {
            guard let body = stone.physicsBody,
                  let oval = ovals[StoneType(rawValue: stone.name ?? "") ?? .white] else { continue }
            let dx = stone.position.x - oval.centre.x
            let dy = stone.position.y - oval.centre.y
            let t = CGFloat(dt)
            body.velocity.dx -= pull * dx / oval.a * t
            body.velocity.dy -= pull * dy * oval.a / (oval.b * oval.b) * t
        }
    }

    private func land(_ node: SKNode) {
        guard !landed.contains(ObjectIdentifier(node)), let body = node.physicsBody else { return }
        landed.insert(ObjectIdentifier(node))
        body.affectedByGravity = false
        body.linearDamping = 3
        body.angularDamping = 3
        // Slippery once gathered, so the pebbles slide into a smooth outline.
        body.friction = 0.15
    }

    /// The middle of a colour's half of the screen.
    private func centreX(of type: StoneType) -> CGFloat {
        type == .white ? size.width / 4 - 5 : size.width * 3 / 4 + 5
    }

    private func dropNext() {
        guard nextIndex < types.count else { return }
        let type = types[nextIndex]
        nextIndex += 1
        // From its top corner, tossed gently towards the middle of its half.
        let inward: CGFloat = type == .white ? 1 : -1
        let x = type == .white ? radius + 10 : size.width - radius - 10
        let stone = makeStone(type, at: CGPoint(x: x, y: size.height + radius * 1.5))
        stone.physicsBody?.velocity = CGVector(dx: inward * .random(in: 70...130), dy: .random(in: -40...20))
        stone.physicsBody?.angularVelocity = .random(in: -4...4)
        lastDropTime = nil
        if nextIndex == types.count {
            lastDropTime = -1 // stamped on the next frame
        }
    }

    private func makeStone(_ type: StoneType, at point: CGPoint) -> SKSpriteNode {
        let size = CGSize(width: radius * 2, height: radius * 2 * 0.82)
        let stone = SKSpriteNode(texture: Self.texture(for: type), size: size)
        stone.position = point
        stone.name = type.rawValue
        stone.zRotation = .random(in: -0.6...0.6)
        let body = SKPhysicsBody(texture: stone.texture!, alphaThreshold: 0.5, size: size)
        body.restitution = 0.22
        body.friction = 0.7
        body.density = 2.6
        body.linearDamping = 0.15
        body.angularDamping = 0.8
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = Category.stone
        body.collisionBitMask = Category.stone | Category.palm
        body.contactTestBitMask = Category.stone | Category.palm
        stone.physicsBody = body
        addChild(stone)
        stones.append(stone)
        return stone
    }

    /// Tap to skip (spec 10.2): the rest drop at once, silently, and the
    /// summary shows straight away.
    func skipToEnd() {
        guard !hasSettled else { return }
        removeAction(forKey: "drops")
        feedback.isMuted = true
        while nextIndex < types.count {
            let type = types[nextIndex]
            nextIndex += 1
            land(makeStone(type, at: pointInOval(of: type)))
        }
        physicsWorld.speed = 2.5
        settle()
    }

    /// Reduce Motion: everything at once, silently, sped up; the view keeps
    /// it hidden until it has settled.
    func dropAllQuietly() {
        // Called before the scene is shown: wait until the palm and ovals exist.
        guard isBuilt else {
            placeQuietlyOnMove = true
            return
        }
        removeAction(forKey: "drops")
        feedback.isMuted = true
        physicsWorld.speed = 4
        while nextIndex < types.count {
            let type = types[nextIndex]
            nextIndex += 1
            land(makeStone(type, at: pointInOval(of: type)))
        }
        lastDropTime = -1
    }

    /// Somewhere inside a colour's oval, a little spread out, for stones
    /// placed rather than dropped.
    private func pointInOval(of type: StoneType) -> CGPoint {
        guard let oval = ovals[type] else { return CGPoint(x: centreX(of: type), y: size.height / 2) }
        // The upper part only, so none start below the palm's edge.
        let angle = CGFloat.random(in: 0.1...(.pi - 0.1))
        let distance = CGFloat.random(in: 0.2...1).squareRoot() * 1.6
        return CGPoint(x: oval.centre.x + cos(angle) * oval.a * distance * 0.8,
                       y: oval.centre.y + sin(angle) * oval.b * distance)
    }

    private func settle() {
        guard !hasSettled else { return }
        hasSettled = true
        onSettled()
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate.map { min(currentTime - $0, 1.0 / 30) } ?? 0
        lastUpdate = currentTime
        gather(dt * Double(physicsWorld.speed))
        guard !hasSettled, nextIndex == types.count, let dropped = lastDropTime else { return }
        if dropped < 0 {
            lastDropTime = currentTime
            return
        }
        let moving = stones.contains { stone in
            guard let body = stone.physicsBody else { return false }
            return hypot(body.velocity.dx, body.velocity.dy) > 12 || abs(body.angularVelocity) > 0.8
        }
        if moving {
            stillSince = nil
        } else if stillSince == nil {
            stillSince = currentTime
        }
        // At rest for a moment, or long enough after the last drop anyway.
        let restedLongEnough = stillSince.map { currentTime - $0 > 0.35 } ?? false
        // Give the heaps time to gather, even when sped up.
        if restedLongEnough || currentTime - dropped > max(1.5, 3.0 / Double(physicsWorld.speed)) {
            settle()
        }
    }

    // MARK: - Contacts

    func didBegin(_ contact: SKPhysicsContact) {
        guard let a = contact.bodyA.node, let b = contact.bodyB.node else { return }
        let aIsStone = contact.bodyA.categoryBitMask == Category.stone
        let bIsStone = contact.bodyB.categoryBitMask == Category.stone
        // Roughly the change in speed, in points per second.
        // The palm is an edge with no mass, so use the lighter stone's.
        let mass = [contact.bodyA.mass, contact.bodyB.mass].filter { $0 > 0 }.min() ?? 0
        let speed = mass > 0 ? contact.collisionImpulse / mass : 0
        let strength = Double(min(speed / 700, 1))
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debug.logContacts") {
            print("contact speed \(Int(speed)) impulse \(contact.collisionImpulse) stones \(aIsStone)/\(bIsStone)")
        }
        #endif

        if aIsStone != bIsStone {
            // A stone on the palm.
            let stone = aIsStone ? a : b
            let first = !landed.contains(ObjectIdentifier(stone))
            land(stone)
            if first {
                // Onto an empty palm it's soft; beside stones already there, heavier.
                let side = StoneType(rawValue: stone.name ?? "") ?? .white
                feedback.play(occupied.contains(side) ? .pile : .palm, strength: strength)
                occupied.insert(side)
            } else if speed > 60 {
                feedback.play(.clack, strength: strength * 0.6)
            }
            return
        }

        // Stone on stone: the falling one lands on the pile with a thud;
        // anything after that is a light clack.
        let aNew = !landed.contains(ObjectIdentifier(a))
        let bNew = !landed.contains(ObjectIdentifier(b))
        land(a)
        land(b)
        if aNew != bNew {
            feedback.play(.pile, strength: strength)
        } else if speed > 40, contact.collisionImpulse > 0 {
            let now = CACurrentMediaTime()
            guard now - lastClack > 0.06 else { return }
            lastClack = now
            feedback.play(.clack, strength: strength)
        }
    }

    // MARK: - Textures

    @MainActor private static var textures: [StoneType: SKTexture] = [:]

    /// Today's stone, drawn once per colour and squashed slightly oval by the sprite.
    @MainActor private static func texture(for type: StoneType) -> SKTexture {
        if let texture = textures[type] { return texture }
        // A faint rim, so a black stone still reads against the dark screen.
        let stone = StoneIcon(type: type, size: 120)
            .overlay(Circle().stroke(Color(white: type == .black ? 0.32 : 0.7), lineWidth: 2.5))
            .padding(2)
        let renderer = ImageRenderer(content: stone)
        renderer.scale = 2
        let texture = renderer.uiImage.map { SKTexture(image: $0) } ?? SKTexture()
        textures[type] = texture
        return texture
    }
}
