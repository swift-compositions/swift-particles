import Particles
import Testing

extension `Particles Tests` {
    @Suite
    struct `A particle's draws follow from the seed, the particle, the stream and the index alone` {}
}

extension `Particles Tests`.`A particle's draws follow from the seed, the particle, the stream and the index alone` {
    typealias Tests = `Particles Tests`

    @Test
    func `Draws read in any order are the same, and lie in 0 up to 1`() {
        let draws = Tests.population.draws(of: 17, stream: 3)
        let indices: [Ordinal] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 40, 41]
        let forward = indices.map { draws[$0] }
        let backward = indices.reversed().map { draws[$0] }
        #expect(forward == Array(backward.reversed()))
        #expect(forward.allSatisfy { $0 >= 0 && $0 < 1 })
        #expect(Set(forward).count == forward.count)
    }

    @Test
    func `Another particle, stream or seed draws other numbers`() {
        let draws = Tests.population.draws(of: 17)
        #expect(draws[0] != Tests.population.draws(of: 18)[0])
        #expect(draws[0] != draws.stream(1)[0])
        #expect(draws[0] != Particles.Population(seed: Threefry.Key(11, 30), count: 2000).draws(of: 17)[0])
    }

    @Test
    func `Draws spread evenly over the unit interval`() {
        let values = Tests.population.particles.map { Tests.population.draws(of: $0)[0] }
        let mean = values.reduce(0, +) / Double(values.count)
        #expect(abs(mean - 0.5) < 0.02)
        let low = values.filter { $0 < 0.25 }.count
        #expect(abs(Double(low) / Double(values.count) - 0.25) < 0.03)
    }
}
