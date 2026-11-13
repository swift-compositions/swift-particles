public import Picture

extension Particles {
    /// A seeded population: `count` particles, each known by its ordinal from 0, whose draws follow from the
    /// seed, the particle and a stream alone.
    public struct Population: Sendable, Hashable {
        /// The key every draw of every particle is made with.
        public var seed: Threefry.Key

        /// How many particles there are.
        public var count: Cardinal

        /// A population of a number of particles drawn from a seed.
        public init(seed: Threefry.Key, count: Cardinal) {
            self.seed = seed
            self.count = count
        }
    }
}

extension Particles.Population {
    /// The draws of one particle in one stream: the same for the same seed, particle and stream, whatever
    /// else is read before or after.
    public func draws(of particle: Ordinal, stream: Ordinal = .zero) -> Particles.Draws {
        Particles.Draws(seed: seed, particle: particle, stream: stream)
    }

    /// Every particle's ordinal, from 0 up to the count.
    public var particles: some Swift.Sequence<Ordinal> {
        (UInt.zero..<count.rawValue).lazy.map { Ordinal($0) }
    }
}
