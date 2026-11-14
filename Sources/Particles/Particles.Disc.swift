import Numeric
public import Picture
import Vector

extension Particles {
    /// A flat disc of a radius around a centre, in the plane through the centre parallel to z = 0, every part
    /// of it as likely as its share of the area. Its normal is +z.
    public struct Disc: Sendable, Hashable {
        /// The centre of the disc.
        public var center: Point<3, Double>

        /// The radius of the disc.
        public var radius: Double

        /// A disc of a radius around a centre.
        public init(center: Point<3, Double>, radius: Double) {
            self.center = center
            self.radius = radius
        }
    }
}

extension Particles.Disc: Particles.Shape {
    /// A particle's home: the root of draw 0 its share of the radius, draw 1 its angle.
    public func home(_ draws: Particles.Draws) -> Particles.Home {
        let pair = draws.pair(0)
        let distance = radius * pair.first.squareRoot()
        let angle = 2 * Double.pi * pair.second
        return Particles.Home(
            place: Point(x: center.x + distance * Double.cos(angle), y: center.y + distance * Double.sin(angle), z: center.z),
            normal: Vector(x: 0, y: 0, z: 1)
        )
    }
}
