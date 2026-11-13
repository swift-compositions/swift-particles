extension Particles.Spiral {
    /// A place on a spiral in polar form, as the spiral sees it: how far from the centre, which arm, how far
    /// round from that arm's line at that distance, and how high. The spiral turns it into a place
    /// (`place(of:turned:wound:)`), so a particle kept in this form can be turned as one body and wound
    /// tighter over time while it stays on its arm.
    public struct Polar: Sendable, Hashable {
        /// The distance from the centre.
        public var distance: Double

        /// The arm, from 0 below the spiral's count of arms.
        public var arm: Ordinal

        /// The angle from the arm's line at this distance, in −π…π; for a particle on an arm, its place across
        /// the arm over its distance.
        public var aside: Double

        /// The height above the plane z = 0.
        public var height: Double

        /// A place on a spiral at a distance, on an arm, an angle aside from it, and a height.
        public init(distance: Double, arm: Ordinal, aside: Double, height: Double) {
            self.distance = distance
            self.arm = arm
            self.aside = aside
            self.height = height
        }
    }
}
