import Numeric
import Particles
import Testing

extension `Particles Tests` {
    @Suite
    struct `A mote mixes part of the way to another` {}
}

extension `Particles Tests`.`A mote mixes part of the way to another` {
    typealias Tests = `Particles Tests`

    static let start = Particles.Mote(position: Tests.at(10.1, 20.3), radius: 0.7, color: Picture.Color(red: 1, green: 0.2, blue: 0.1), strength: 0.3, blur: 0.1)
    static let end = Particles.Mote(position: Tests.at(70.7, -5.9), radius: 2.3, color: Picture.Color(red: 0.1, green: 0.4, blue: 0.9, alpha: 0.5), strength: 1.7, blur: 1.3)
    static let passage = Particles.Passage(from: .zero, to: Tests.seconds(1000), each: Tests.seconds(500), turn: Radian(0.8))

    @Test
    func `At 0 it is the mote and at 1 the other, exactly, with or without a passage`() {
        for passage in [nil, Self.passage] {
            #expect(Self.start.mixed(to: Self.end, at: 0, through: passage) == Self.start)
            #expect(Self.start.mixed(to: Self.end, at: 1, through: passage) == Self.end)
            #expect(Self.start.mixed(to: Self.end, at: -0.5, through: passage) == Self.start)
            #expect(Self.start.mixed(to: Self.end, at: 1.5, through: passage) == Self.end)
        }
    }

    @Test
    func `Between, each part goes its share of the way, and a passage bends the position as it bends a place`() {
        let share = 0.3
        let mixed = Self.start.mixed(to: Self.end, at: share)
        #expect(abs(mixed.position[0] - (10.1 + 60.6 * share)) < 1e-12)
        #expect(abs(mixed.position[1] - (20.3 - 26.2 * share)) < 1e-12)
        #expect(abs(mixed.radius - (0.7 + 1.6 * share)) < 1e-12)
        #expect(abs(mixed.strength - (0.3 + 1.4 * share)) < 1e-12)
        #expect(abs(mixed.blur - (0.1 + 1.2 * share)) < 1e-12)
        #expect(mixed.color == Self.start.color.mixed(inSRGBTo: Self.end.color, at: share))
        let bent = Self.start.mixed(to: Self.end, at: share, through: Self.passage)
        let place = Self.passage.place(from: Point(x: 10.1, y: 20.3, z: 0), to: Point(x: 70.7, y: -5.9, z: 0), share: share)
        #expect(bent.position == Tests.at(place.x, place.y))
        #expect(bent.position != mixed.position)
        #expect(bent.radius == mixed.radius && bent.color == mixed.color && bent.strength == mixed.strength)
    }
}
