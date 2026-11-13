import Numeric
import Particles
import Testing

extension `Particles Tests` {
    @Suite
    struct `A flow goes along a trace and round again` {}
}

extension `Particles Tests`.`A flow goes along a trace and round again` {
    typealias Tests = `Particles Tests`

    static let places: [Point<3, Double>] = [
        Point(x: 0, y: 0, z: 0), Point(x: 3, y: 0, z: 0), Point(x: 3, y: 4, z: 0),
        Point(x: 10, y: 4, z: 0), Point(x: 10, y: 6, z: 0),
    ]

    @Test
    func `A chain runs through its places in order, and a step longer than the gap is a break`() throws {
        let chain = try #require(Particles.Trace(through: Self.places))
        #expect(chain.length == 3 + 4 + 7 + 2)
        #expect(chain.place(along: 0) == Self.places[0])
        #expect(chain.place(along: 5) == Point(x: 3, y: 2, z: 0))
        let broken = try #require(Particles.Trace(through: Self.places, gap: 5))
        #expect(broken.length == 3 + 4 + 2)
        #expect(broken.place(along: 7) == Self.places[2])
        #expect(broken.place(along: 7.5) == Point(x: 10, y: 4.5, z: 0))
        #expect(broken.place(along: 8) == Point(x: 10, y: 5, z: 0))
        let closed = try #require(Particles.Trace(through: Self.places, closed: true))
        #expect(abs(closed.length - (16 + (100.0 + 36).squareRoot())) < 1e-12)
        #expect(Particles.Trace(through: [Self.places[0], Self.places[0]]) == nil)
        #expect(Particles.Trace(through: Self.places, gap: 1) == nil)
    }

    @Test
    func `A distance is taken around the whole length, so a flow goes round forever`() throws {
        let chain = try #require(Particles.Trace(through: Self.places, closed: true))
        for distance in [0.0, 1.5, 7.25, 13, 20.4] {
            let here = chain.place(along: distance)
            #expect(Tests.distance(chain.place(along: distance + chain.length), here) < 1e-9)
            #expect(Tests.distance(chain.place(along: distance - 3 * chain.length), here) < 1e-9)
        }
        let draws = Tests.population.draws(of: 17)
        #expect(chain.home(draws).place == chain.place(along: draws[0] * chain.length))
    }

    @Test
    func `A stretch is unbroken unless it crosses a break, round past the end too`() throws {
        let broken = try #require(Particles.Trace(through: Self.places, gap: 5))
        #expect(broken.unbroken(from: 0.5, to: 6.5))
        #expect(!broken.unbroken(from: 6.5, to: 7.5))
        #expect(broken.unbroken(from: 7.2, to: 8.8))
        #expect(!broken.unbroken(from: 8.8, to: 0.5))
        let closed = try #require(Particles.Trace(through: Self.places, closed: true))
        #expect(closed.unbroken(from: 20, to: 1))
        #expect(closed.unbroken(from: 1, to: 0.5))
        let corners: [Picture.Plane.Point<2>] = [Tests.at(0, 0), Tests.at(4, 0), Tests.at(4, 2)]
        let sides = zip(corners, corners.dropFirst()).map { Picture.Plane.Path.Segment.line(.init(start: $0, end: $1)) }
        let two = Picture.Plane.Path(subpaths: [
            .init(startPoint: corners[0], segments: sides, isClosed: false),
            .init(startPoint: Tests.at(10, 10), segments: [.line(.init(start: Tests.at(10, 10), end: Tests.at(12, 10)))], isClosed: false),
        ])
        let path = try #require(Particles.Trace(two, tolerance: 0.01))
        #expect(path.unbroken(from: 1, to: 5))
        #expect(!path.unbroken(from: 5, to: 7))
    }
}
