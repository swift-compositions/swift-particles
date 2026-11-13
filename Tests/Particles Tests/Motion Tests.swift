import Numeric
import Particles
import Testing

extension `Particles Tests` {
    @Suite
    struct `A particle's place follows from the seed, the particle and the instant alone` {}
}

extension `Particles Tests`.`A particle's place follows from the seed, the particle and the instant alone` {
    typealias Tests = `Particles Tests`

    static let spiral = Particles.Spiral(arms: 2, inner: 0.2, reach: 3, winding: Radian(4), width: 0.3, stray: 0.1, thickness: 0.2)
    static let orbit = Particles.Orbit(rate: Radian(0.7), radius: 1, shear: 0.5)
    static let disc = Particles.Disc(center: Point(x: 0, y: 0, z: 1), radius: 2)
    static let passage = Particles.Passage(from: Tests.seconds(500), to: Tests.seconds(2500), each: Tests.seconds(800), turn: Radian(0.6))

    static func place(of particle: Ordinal, at instant: Rational) -> Point<3, Double> {
        let draws = Tests.population.draws(of: particle)
        let start = orbit.place(of: spiral.home(draws).place, at: instant)
        let end = disc.home(draws.stream(1)).place
        return passage.place(from: start, to: end, order: draws.stream(2)[0], at: instant)
    }

    @Test
    func `Any particle at any instant, read in any order, is in the same place`() {
        let particles: [Ordinal] = [0, 1, 7, 99, 1999]
        let instants = [0, 400, 1100, 1700, 2600].map { Tests.seconds($0) }
        let pairs = particles.flatMap { particle in instants.map { (particle, $0) } }
        let forward = pairs.map { Self.place(of: $0.0, at: $0.1) }
        let backward = pairs.reversed().map { Self.place(of: $0.0, at: $0.1) }
        #expect(forward == Array(backward.reversed()))
        let again = Particles.Population(seed: Threefry.Key(11, 29), count: 3)
        #expect(Self.spiral.home(again.draws(of: 1)) == Self.spiral.home(Tests.population.draws(of: 1)))
    }

    @Test
    func `An orbit turns about z, faster inside with a shear, and not at all at the instant 0`() {
        let near = Point<3, Double>(x: 0.5, y: 0, z: 0.1)
        let far = Point<3, Double>(x: 2, y: 0, z: -0.1)
        #expect(Self.orbit.place(of: near, at: .zero) == near)
        let instant = Tests.seconds(1000)
        let (a, b) = (Self.orbit.place(of: near, at: instant), Self.orbit.place(of: far, at: instant))
        #expect(abs((a.x * a.x + a.y * a.y).squareRoot() - 0.5) < 1e-12 && a.z == 0.1)
        #expect(Double.atan2(a.y, a.x) > Double.atan2(b.y, b.x))
        #expect(abs(Double.atan2(b.y, b.x) - 0.7 * (0.5).squareRoot()) < 1e-12)
    }

    @Test
    func `A flight is at its origin until its launch and then on its trajectories`() throws {
        let origin = Point<3, Double>(x: 1, y: 2, z: 3)
        let flight = try Particles.Flight(
            from: origin,
            after: 0.5,
            velocity: Vector(x: 2, y: 6, z: -1),
            acceleration: Vector(x: 0, y: -9.8, z: 0),
            drag: 1.5
        )
        #expect(flight.place(at: Tests.seconds(100)) == origin)
        #expect(flight.place(at: Tests.seconds(500)) == origin)
        let y = try Ballistics.Trajectory<Double>(velocity: 6, acceleration: -9.8, drag: 1.5)
        let x = try Ballistics.Trajectory<Double>(velocity: 2, acceleration: 0, drag: 1.5)
        let there = flight.place(at: Tests.seconds(1500))
        #expect(abs(there.y - (2 + y.position(at: 1))) < 1e-12)
        #expect(abs(there.x - (1 + x.position(at: 1))) < 1e-12)
        #expect(flight.launch == 0.5 && flight.flown(after: 0.2) == 0 && flight.flown(after: 1.5) == 1)
        #expect(!flight.launched(by: Tests.seconds(499)) && flight.launched(by: Tests.seconds(500)))
        #expect(flight.place(at: Tests.seconds(1500)) == flight.place(after: 1.5))
        #expect(throws: Ballistics.Trajectory<Double>.Error.drag) {
            try Particles.Flight(from: origin, velocity: Vector(x: 0, y: 0, z: 0), acceleration: Vector(x: 0, y: 0, z: 0), drag: -1)
        }
    }

    @Test
    func `A fluttering piece keeps two perpendicular unit axes`() throws {
        let flutter = Particles.Flutter(spin: Radian(0.3), spinning: Radian(2), tumble: Radian(1), tumbling: Radian(7), sway: 0.2, swaying: Radian(3))
        let flight = try Particles.Flight(
            from: Point(x: 0, y: 0, z: 0),
            velocity: Vector(x: 1, y: 4, z: 0),
            acceleration: Vector(x: 0, y: -3, z: 0),
            drag: 2,
            flutter: flutter
        )
        for thousandths in stride(from: 0, through: 3000, by: 250) {
            let pose = flight.pose(at: Tests.seconds(thousandths))
            let (a, b, n) = (pose.across, pose.along, pose.normal)
            #expect(abs(Tests.length(a.x, a.y, a.z) - 1) < 1e-12 && abs(Tests.length(b.x, b.y, b.z) - 1) < 1e-12)
            #expect(abs(a.x * b.x + a.y * b.y + a.z * b.z) < 1e-12)
            #expect(abs(Tests.length(n.x, n.y, n.z) - 1) < 1e-12)
        }
    }

    @Test
    func `A shutter is read from its opening to its closing, evenly`() throws {
        let shutter = Particles.Shutter(open: Tests.seconds(40), samples: 5)
        let instants = shutter.instants(closing: Tests.seconds(1000))
        #expect(instants == [960, 970, 980, 990, 1000].map { Tests.seconds($0) })
        #expect(Particles.Shutter.closed.instants(closing: Tests.seconds(1000)) == [Tests.seconds(1000)])
    }
}
