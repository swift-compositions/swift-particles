public import Picture

extension Particles {
    /// How a flat piece turns and sways in flight: it spins about its own normal, tumbles about its own width,
    /// and sways from side to side along x the more as drag has brought it to its terminal speed.
    public struct Flutter: Sendable, Hashable {
        /// The spin at launch.
        public var spin: Radian<Double>

        /// The spin per second.
        public var spinning: Radian<Double>

        /// The tumble at launch.
        public var tumble: Radian<Double>

        /// The tumble per second.
        public var tumbling: Radian<Double>

        /// How far it sways to either side once settled.
        public var sway: Double

        /// The sway's angular frequency per second.
        public var swaying: Radian<Double>

        /// Where the sway starts in its cycle.
        public var phase: Radian<Double>

        /// A flutter of a spin, a tumble and a sway.
        public init(
            spin: Radian<Double> = .zero,
            spinning: Radian<Double> = .zero,
            tumble: Radian<Double> = .zero,
            tumbling: Radian<Double> = .zero,
            sway: Double = 0,
            swaying: Radian<Double> = .zero,
            phase: Radian<Double> = .zero
        ) {
            self.spin = spin
            self.spinning = spinning
            self.tumble = tumble
            self.tumbling = tumbling
            self.sway = sway
            self.swaying = swaying
            self.phase = phase
        }
    }
}

extension Particles.Flutter {
    /// No turning and no sway: a piece that keeps facing +z.
    public static var still: Self { Self() }
}
