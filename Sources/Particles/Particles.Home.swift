public import Picture

extension Particles {
    /// Where a particle rests in a shape: a place in the world, and the shape's unit normal there where the
    /// shape has one.
    public struct Home: Sendable, Hashable {
        /// The place in the world.
        public var place: Point<3, Double>

        /// The shape's unit normal at the place; nil for a shape without one, such as a volume.
        public var normal: Vector<3, Double>?

        /// A home at a place, with a normal where the shape has one.
        public init(place: Point<3, Double>, normal: Vector<3, Double>? = nil) {
            self.place = place
            self.normal = normal
        }
    }
}
