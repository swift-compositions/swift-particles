import Particles
import Testing

extension `Particles Tests` {
    @Suite
    struct `A passage starts at one home and ends at the other` {}
}

extension `Particles Tests`.`A passage starts at one home and ends at the other` {
    typealias Tests = `Particles Tests`

    static let from = Point<3, Double>(x: -3, y: 1, z: 0.5)
    static let to = Point<3, Double>(x: 2, y: -1, z: -1)

    @Test
    func `Before its departure a particle is at the start, after its arrival at the end`() {
        for turn in [0.0, 1.3] {
            let passage = Particles.Passage(from: Tests.seconds(1000), to: Tests.seconds(3000), each: Tests.seconds(500), turn: Radian(turn))
            for order in [0.0, 0.3, 1.0] {
                #expect(passage.place(from: Self.from, to: Self.to, order: order, at: Tests.seconds(999)) == Self.from)
                #expect(passage.place(from: Self.from, to: Self.to, order: order, at: Tests.seconds(3000)) == Self.to)
            }
            #expect(passage.share(of: 0, at: Tests.seconds(1000)) == 0)
            #expect(passage.share(of: 0, at: Tests.seconds(1500)) == 1)
            #expect(passage.share(of: 1, at: Tests.seconds(2500)) == 0)
        }
    }

    @Test
    func `A later order leaves later and arrives later`() {
        let passage = Particles.Passage(from: Tests.seconds(0), to: Tests.seconds(2000), each: Tests.seconds(400))
        #expect(passage.departure(of: 0) == 0)
        #expect(abs(passage.departure(of: 1) - 1.6) < 1e-12)
        let instant = Tests.seconds(900)
        let shares = stride(from: 0.0, through: 1.0, by: 0.05).map { passage.share(of: $0, at: instant) }
        #expect(zip(shares, shares.dropFirst()).allSatisfy { $0 >= $1 })
    }

    @Test
    func `With a monotone easing and no turn the way only ever comes nearer`() {
        let easings: [Timeline.Easing<Double>] = [.linear, .smooth, .power(3), .power(2).reversed, .power(3).symmetric, .bezier(0.2, 0, 0.1, 1)]
        for easing in easings {
            let passage = Particles.Passage(from: Tests.seconds(0), to: Tests.seconds(1000), each: Tests.seconds(1000), easing: easing)
            let instants = (0...200).map { Tests.seconds($0 * 5) }
            let left = instants.map { Tests.distance(passage.place(from: Self.from, to: Self.to, order: 0.5, at: $0), Self.to) }
            #expect(zip(left, left.dropFirst()).allSatisfy { $0 >= $1 - 1e-12 })
            #expect(left.first == Tests.distance(Self.from, Self.to))
            #expect(left.last == 0)
        }
    }

    @Test
    func `A turn bends the way without changing its ends`() {
        let passage = Particles.Passage(from: Tests.seconds(0), to: Tests.seconds(1000), each: Tests.seconds(1000), easing: .linear, turn: Radian(1))
        let middle = passage.place(from: Self.from, to: Self.to, share: 0.5)
        let straight = Point<3, Double>(x: -0.5, y: 0, z: -0.25)
        #expect(Tests.distance(middle, straight) > 0.5)
        #expect(abs(Tests.distance(middle, Self.to) - Tests.distance(straight, Self.to)) < 1e-12)
    }
}
