import Numeric
public import Picture

extension Particles {
    /// A turn about the z axis through the origin that is faster near the axis: a place at a distance r from
    /// the axis has turned by `rate × t × (radius / r)^shear` at an instant t, so with a shear of 0 everything
    /// turns as one body and with more the inside overtakes the outside and winds what lies across it.
    public struct Orbit: Sendable, Hashable {
        /// The angle a place at `radius` turns through in a second.
        public var rate: Radian<Double>

        /// The distance from the axis at which the rate holds.
        public var radius: Double

        /// How much faster the inside turns; 0 turns as one body.
        public var shear: Double

        /// A turn about the z axis at a rate at a distance from it.
        public init(rate: Radian<Double>, radius: Double, shear: Double = 0) {
            self.rate = rate
            self.radius = radius
            self.shear = shear
        }
    }
}

extension Particles.Orbit {
    /// The angle a place at a distance from the axis has turned through at an instant.
    public func angle(at distance: Double, after seconds: Double) -> Double {
        guard shear != 0 else { return rate.underlying * seconds }
        return rate.underlying * seconds * Double.exp(shear * Double.log(radius / Swift.max(distance, 1e-9)))
    }

    /// Where a place has turned to at an instant; at the instant 0 it is the place itself.
    public func place(of place: Point<3, Double>, at instant: Rational) -> Point<3, Double> {
        self.place(of: place, after: instant.seconds)
    }

    /// Where a place has turned to after a time in seconds.
    public func place(of place: Point<3, Double>, after seconds: Double) -> Point<3, Double> {
        let angle = angle(at: (place.x * place.x + place.y * place.y).squareRoot(), after: seconds)
        let (cosine, sine) = (Double.cos(angle), Double.sin(angle))
        return Point(x: cosine * place.x - sine * place.y, y: sine * place.x + cosine * place.y, z: place.z)
    }
}
