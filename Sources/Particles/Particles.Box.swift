public import Picture
public import Vector

extension Particles {
    /// A solid box along the axes around a centre, every part of it as likely as its share of the volume. It
    /// is a volume, so its homes have no normal.
    public struct Box: Sendable, Hashable {
        /// The centre of the box.
        public var center: Point<3, Double>

        /// The box's full extent along x, y and z.
        public var size: Vector<3, Double>

        /// A box of a size around a centre.
        public init(center: Point<3, Double>, size: Vector<3, Double>) {
            self.center = center
            self.size = size
        }
    }
}

extension Particles.Box: Particles.Shape {
    /// A particle's home: draws 0, 1 and 2 its place along x, y and z.
    public func home(_ draws: Particles.Draws) -> Particles.Home {
        let pair = draws.pair(0)
        return Particles.Home(
            place: Point(
                x: center.x + size.x * (pair.first - 0.5),
                y: center.y + size.y * (pair.second - 0.5),
                z: center.z + size.z * (draws[2] - 0.5)
            )
        )
    }
}
