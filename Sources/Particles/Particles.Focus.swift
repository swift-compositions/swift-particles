extension Particles {
    /// A lens's depth of field: a point at the focal distance ahead of the eye is sharp, and one at a distance
    /// d is spread over a disc of radius `aperture × |d − distance| / d` in picture units, the thin lens's
    /// circle of confusion, so `aperture` is the blur of a point at infinity.
    public struct Focus: Sendable, Hashable {
        /// How far ahead of the eye a point is sharp.
        public var distance: Double

        /// The blur radius, in picture units, of a point infinitely far away.
        public var aperture: Double

        /// A focus at a distance with an aperture.
        public init(distance: Double, aperture: Double) {
            self.distance = distance
            self.aperture = aperture
        }
    }
}

extension Particles.Focus {
    /// The blur radius, in picture units, of a point at a distance ahead of the eye; 0 at the focal distance and
    /// for a point that is not ahead.
    public func blur(at distance: Double) -> Double {
        guard distance > 0 else { return 0 }
        return aperture * Swift.abs(distance - self.distance) / distance
    }
}
