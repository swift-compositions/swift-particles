public import Picture

extension Particles {
    /// The unit draws of one particle in one stream, read in any order: the draw at an index is
    /// `Threefry.block` with the seed as key and, as counter, the particle and the stream times 2³² plus half
    /// the index, its first word for an even index and its second for an odd one, the top 53 bits of it over
    /// 2⁵³. So a draw lies in 0..<1, depends on nothing but the seed, the particle, the stream and the index,
    /// and is the same on every platform. Draws are distinct for streams below 2³² and indices below 2³³.
    public struct Draws: Sendable, Hashable {
        /// The population's seed.
        public let seed: Threefry.Key

        /// The particle the draws belong to.
        public let particle: Ordinal

        /// The stream, so that independent uses of one particle draw independent numbers.
        public let stream: Ordinal

        /// The draws of a particle in a stream of a seed.
        public init(seed: Threefry.Key, particle: Ordinal, stream: Ordinal = .zero) {
            self.seed = seed
            self.particle = particle
            self.stream = stream
        }
    }
}

extension Particles.Draws {
    /// The draw at an index, in 0..<1.
    @inlinable
    public subscript(index: Ordinal) -> Double {
        let counter = Threefry.Block(UInt64(particle.rawValue), (UInt64(stream.rawValue) << 32) &+ (UInt64(index.rawValue) >> 1))
        let block = Threefry.block(key: seed, counter: counter)
        let word = index.rawValue & 1 == 0 ? block.first : block.second
        return Double(word >> 11) * 0x1p-53
    }

    /// The draws of the same particle in another stream.
    public func stream(_ stream: Ordinal) -> Self {
        Self(seed: seed, particle: particle, stream: stream)
    }
}
