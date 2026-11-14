import Numeric
public import Picture
import Vector

extension Particles {
    /// A spiral galaxy in the plane z = 0 around the origin: arms that wind out from an inner radius to a
    /// reach, with particles crowded toward the centre, spread across each arm, a share of strays at any
    /// angle, and a height that thins toward the rim. Its normal is +z. A home can also be kept in polar form
    /// (`Polar`), so the spiral can turn and wind it over time.
    public struct Spiral: Sendable, Hashable {
        /// How many arms, at equal angles; none counts as one.
        public var arms: Cardinal

        /// The distance from the centre at which the arms begin.
        public var inner: Double

        /// The distance from the centre at which the arms end.
        public var reach: Double

        /// How strongly particles crowd toward the inner radius: a draw u places a particle at
        /// `inner + (reach − inner) × u^concentration`, so 1 spreads them evenly in distance and more crowds
        /// them inward.
        public var concentration: Double

        /// How far an arm turns between the inner radius and the reach.
        public var winding: Radian<Double>

        /// How far across its arm a particle may lie, as a distance at any radius, so an arm keeps its width.
        public var width: Double

        /// The share of particles, 0…1, that lie at any angle instead of on an arm.
        public var stray: Double

        /// The full height of the disc at the centre; it thins to two fifths of that at the reach.
        public var thickness: Double

        /// A spiral of arms between two radii.
        public init(
            arms: Cardinal,
            inner: Double,
            reach: Double,
            concentration: Double = 1,
            winding: Radian<Double>,
            width: Double,
            stray: Double = 0,
            thickness: Double = 0
        ) {
            self.arms = arms
            self.inner = inner
            self.reach = reach
            self.concentration = concentration
            self.winding = winding
            self.width = width
            self.stray = stray
            self.thickness = thickness
        }
    }
}

extension Particles.Spiral {
    /// The share of the way from the inner radius to the reach at a distance from the centre; 0 for a spiral
    /// whose reach is not beyond its inner radius.
    public func share(at distance: Double) -> Double {
        let span = reach - inner
        return span > 0 ? (distance - inner) / span : 0
    }

    /// The angle the arms have turned through at a distance from the centre, before an arm's own direction:
    /// `winding` times the share of the way from the inner radius to the reach.
    public func turn(at distance: Double) -> Double {
        winding.underlying * share(at: distance)
    }

    /// The direction of an arm's line at the inner radius: its share of a whole turn, `2π × arm / arms`.
    public func direction(of arm: Ordinal) -> Double {
        2 * Double.pi * Double(arm.rawValue) / Double(Swift.max(arms.rawValue, 1))
    }

    /// A particle's home in polar form: draw 0 its distance, draw 1 its arm, draw 2 whether it strays, draws 3
    /// to 5 its place across the arm (or with draw 3 its angle as a stray), and draws 6 to 8 its height. The
    /// draws are read in pairs, so a home costs five blocks, or four for a stray.
    public func polar(_ draws: Particles.Draws) -> Polar {
        let count = Swift.max(arms.rawValue, 1)
        let place = draws.pair(0)
        let side = draws.pair(1)
        let near = place.first
        let out = near > 0 ? Double.exp(Swift.max(concentration, 0) * Double.log(near)) : 0
        let distance = inner + (reach - inner) * out
        let arm = Swift.min(UInt((place.second * Double(count)).rounded(.down)), count - 1)
        let aside: Double
        if side.first < stray {
            let round = side.second
            aside = 2 * Double.pi * (round - round.rounded())
        } else {
            let across = draws.pair(2)
            aside = width * Particles.centred(side.second, across.first, across.second) / Swift.max(distance, width, 1e-9)
        }
        let rise = draws.pair(3)
        let height = Particles.centred(rise.first, rise.second, draws[8])
        return Polar(
            distance: distance,
            arm: Ordinal(arm),
            aside: aside,
            height: thickness / 2 * height * (1 - 0.6 * out)
        )
    }

    /// The angle about z of a place in polar form: its arm's direction, plus the arms' turn at its distance
    /// wound by `wound` more than `winding`, plus its angle aside, plus `turned`. A wound adds nothing at the
    /// inner radius and all of itself at the reach, as the winding does; a turn that differs with the
    /// distance, such as an `Orbit`'s with a shear, is `orbit.angle(at: polar.distance, after:)` as `turned`.
    public func angle(of polar: Polar, turned: Radian<Double> = .zero, wound: Radian<Double> = .zero) -> Double {
        direction(of: polar.arm) + (winding.underlying + wound.underlying) * share(at: polar.distance) + polar.aside + turned.underlying
    }

    /// The place of a place in polar form, turned and wound: at its distance from the z axis, at its angle
    /// (`angle(of:turned:wound:)`), and at its height. Unturned and unwound it is the home the polar form was
    /// drawn for.
    public func place(of polar: Polar, turned: Radian<Double> = .zero, wound: Radian<Double> = .zero) -> Point<3, Double> {
        let angle = angle(of: polar, turned: turned, wound: wound)
        return Point(x: polar.distance * Double.cos(angle), y: polar.distance * Double.sin(angle), z: polar.height)
    }
}

extension Particles.Spiral: Particles.Shape {
    /// A particle's home: the place of its polar form (`polar(_:)`), unturned and unwound.
    public func home(_ draws: Particles.Draws) -> Particles.Home {
        Particles.Home(place: place(of: polar(draws)), normal: Vector(x: 0, y: 0, z: 1))
    }
}
