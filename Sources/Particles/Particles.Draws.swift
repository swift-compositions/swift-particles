public import Picture
public import Threefry

extension Particles {
    /// The unit draws of one particle in one stream, read in any order: `Threefry.Draws` of swift-threefry
    /// with the seed as key and the particle as item. So a draw lies in 0..<1, depends on nothing but the
    /// seed, the particle, the stream and the index, and is the same on every platform; draws `2k` and
    /// `2k + 1` are the two words of one block, read together by `pair(_:)`. Draws are distinct for streams
    /// below 2³² and indices below 2³³.
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
    /// The draws as swift-threefry addresses them.
    public var threefry: Threefry.Draws {
        Threefry.Draws(key: seed, item: UInt64(particle.rawValue), stream: UInt64(stream.rawValue))
    }

    /// The draw at an index, in 0..<1.
    public subscript(index: Ordinal) -> Double {
        threefry.unit(at: UInt64(index.rawValue), as: Double.self)
    }

    /// Draws `2 × pair` and `2 × pair + 1` at the cost of one: the two words of one block.
    public func pair(_ pair: Ordinal) -> (first: Double, second: Double) {
        threefry.pair(at: UInt64(pair.rawValue), as: Double.self)
    }

    /// The draws of the same particle in another stream.
    public func stream(_ stream: Ordinal) -> Self {
        Self(seed: seed, particle: particle, stream: stream)
    }
}
