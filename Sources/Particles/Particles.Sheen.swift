import Numeric
public import Picture
public import Vector

extension Particles {
    /// A light far away that flat pieces catch: a piece glints when its normal, from either side, lies near the
    /// half-way direction between the light and the eye, as paper or foil turning in a beam flashes for a moment.
    /// Directions are in the eye's space, where the eye looks along −z, and the eye is taken as far away, so the
    /// direction to it is +z everywhere.
    public struct Sheen: Sendable, Hashable {
        /// The unit direction toward the light, in the eye's space.
        public let direction: Vector<3, Double>

        /// How tight the glint is: the power the alignment is raised to, higher for a shorter flash.
        public var sharpness: Double

        /// The glint of a piece that faces the half-way direction squarely, 0…1.
        public var strength: Double

        /// The colour of the light.
        public var color: Picture.Color

        /// The unit half-way direction between the light and the eye.
        let halfway: Vector<3, Double>

        /// A light toward a direction, which need not be of unit length; a direction of no length is the eye's own.
        public init(toward direction: Vector<3, Double>, sharpness: Double = 24, strength: Double = 1, color: Picture.Color = .white) {
            func unit(_ v: Vector<3, Double>) -> Vector<3, Double>? {
                let length = (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot()
                guard length > 1e-12, length.isFinite else { return nil }
                return Vector(x: v.x / length, y: v.y / length, z: v.z / length)
            }
            let toward = unit(direction) ?? Vector(x: 0, y: 0, z: 1)
            self.direction = toward
            self.sharpness = sharpness
            self.strength = strength
            self.color = color
            self.halfway = unit(Vector(x: toward.x, y: toward.y, z: toward.z + 1)) ?? Vector(x: 0, y: 0, z: 1)
        }
    }
}

extension Particles.Sheen {
    /// How much a piece with a unit normal in the eye's space glints: `strength × |n · h|^sharpness`, h the
    /// half-way direction, from either side of the piece, held to 0…1.
    public func glint(normal: Vector<3, Double>) -> Double {
        let aligned = Swift.abs(normal.x * halfway.x + normal.y * halfway.y + normal.z * halfway.z)
        guard aligned > 0 else { return 0 }
        let glint = strength * Double.exp(Swift.max(sharpness, 0) * Double.log(Swift.min(aligned, 1)))
        return glint.isFinite ? Swift.min(Swift.max(glint, 0), 1) : 0
    }
}
