public import Picture
public import Vector

extension Particles {
    /// A flat piece in the world: its place and the two unit directions along its width and its height. Its
    /// normal is the first crossed with the second.
    public struct Pose: Sendable, Hashable {
        /// The piece's centre.
        public var place: Point<3, Double>

        /// The unit direction of the piece's width.
        public var across: Vector<3, Double>

        /// The unit direction of the piece's height, perpendicular to `across`.
        public var along: Vector<3, Double>

        /// A piece at a place, turned so.
        public init(place: Point<3, Double>, across: Vector<3, Double>, along: Vector<3, Double>) {
            self.place = place
            self.across = across
            self.along = along
        }
    }
}

extension Particles.Pose {
    /// The piece's normal: `across` crossed with `along`.
    public var normal: Vector<3, Double> {
        Vector(
            x: across.y * along.z - across.z * along.y,
            y: across.z * along.x - across.x * along.z,
            z: across.x * along.y - across.y * along.x
        )
    }
}
