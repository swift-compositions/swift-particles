public import Picture

extension Particles.Trace {
    /// One straight piece of a trace, in the world.
    public struct Piece: Sendable, Hashable {
        /// Where the piece starts.
        public let start: Point<3, Double>

        /// Where the piece ends.
        public let end: Point<3, Double>

        /// A piece from a start to an end.
        public init(start: Point<3, Double>, end: Point<3, Double>) {
            self.start = start
            self.end = end
        }
    }
}

extension Particles.Trace.Piece {
    /// The length of the piece.
    public var length: Double {
        let (x, y, z) = (end.x - start.x, end.y - start.y, end.z - start.z)
        return (x * x + y * y + z * z).squareRoot()
    }

    /// The point a share of the way from the start to the end.
    public func point(at share: Double) -> Point<3, Double> {
        Point(
            x: start.x + (end.x - start.x) * share,
            y: start.y + (end.y - start.y) * share,
            z: start.z + (end.z - start.z) * share
        )
    }
}
