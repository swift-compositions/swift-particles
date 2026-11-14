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

extension `Particles Tests`.`A particle's draws follow from the seed, the particle, the stream and the index alone` {
    @Test
    func `Draws are the same on every platform`() {
        let draws = Tests.population.draws(of: 17, stream: 3)
        #expect(
            (0..<10 as Range<UInt>).map { draws[Ordinal($0)] }
                == [
                    0x0b_8747_017c_658f, 0x14_df4c_8ac8_a89f, 0x19_4ec4_e541_451a, 0x14_158d_8278_d181,
                    0x03_acf8_0738_8df4, 0x1a_fe3c_ba6f_37f1, 0x18_b63a_b2ba_ac06, 0x1c_a37e_d4a1_7788,
                    0x09_c795_3c0e_1f42, 0x0d_ea23_ae4c_3d95,
                ].map { Double($0) * 0x1p-53 }
        )
        let first = Tests.population.draws(of: 0)
        #expect([first[0], first[1]] == [0x15_a2f0_76ad_eaee, 0x06_b6c4_3493_516d].map { Double($0) * 0x1p-53 })
        #expect(Tests.population.draws(of: 1999, stream: 1)[41] == Double(0x1f_9787_5d29_adda) * 0x1p-53)
    }

    @Test
    func `A pair is the two draws it holds, and the draws are swift-threefry's`() {
        let draws = Tests.population.draws(of: 17, stream: 3)
        (0..<5 as Range<UInt>).forEach { pair in
            let both = draws.pair(Ordinal(pair))
            #expect(both.first == draws[Ordinal(2 * pair)])
            #expect(both.second == draws[Ordinal(2 * pair + 1)])
        }
        let threefry = Threefry.Draws(key: Tests.population.seed, item: 17, stream: 3)
        #expect(draws.threefry == threefry)
        #expect(draws[7] == threefry.unit(at: 7, as: Double.self))
    }
}
