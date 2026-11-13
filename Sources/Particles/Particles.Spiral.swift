import Numeric
public import Picture

extension Particles {
    /// A spiral galaxy in the plane z = 0 around the origin: arms that wind out from an inner radius to a
    /// reach, with particles crowded toward the centre, spread across each arm, a share of strays at any
    /// angle, and a height that thins toward the rim. Its normal is +z.
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
    /// The angle the arms have turned through at a distance from the centre, before an arm's own direction:
    /// `winding` times the share of the way from the inner radius to the reach.
    public func turn(at distance: Double) -> Double {
        let span = reach - inner
        let out = span > 0 ? (distance - inner) / span : 0
        return winding.underlying * out
    }
}

extension Particles.Spiral: Particles.Shape {
    /// A particle's home: draw 0 its distance, draw 1 its arm, draw 2 whether it strays, draws 3 to 5 its
    /// place across the arm (or with draw 3 its angle as a stray), and draws 6 to 8 its height.
    public func home(_ draws: Particles.Draws) -> Particles.Home {
        let count = Double(Swift.max(arms.rawValue, 1))
        let near = draws[0]
        let out = near > 0 ? Double.exp(Swift.max(concentration, 0) * Double.log(near)) : 0
        let distance = inner + (reach - inner) * out
        let arm = (draws[1] * count).rounded(.down)
        let strays = draws[2] < stray
        let across = width * Particles.centred(draws, 3)
        let aside = strays ? 2 * Double.pi * draws[3] : across / Swift.max(distance, width, 1e-9)
        let angle = 2 * Double.pi * arm / count + turn(at: distance) + aside
        let height = thickness / 2 * Particles.centred(draws, 6) * (1 - 0.6 * out)
        return Particles.Home(
            place: Point(x: distance * Double.cos(angle), y: distance * Double.sin(angle), z: height),
            normal: Vector(x: 0, y: 0, z: 1)
        )
    }
}
