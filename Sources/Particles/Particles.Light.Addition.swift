extension Particles.Light {
    /// One thing added to a light.
    enum Addition: Sendable, Hashable {
        /// A mote, spread at its position.
        case mote(Particles.Mote)

        /// A trail of motes read across a shutter, at least two of which differ, and its persistence.
        case trail([Particles.Mote], persistence: Double)

        /// Another light over the same rectangle at the same scale.
        case light(Particles.Light)
    }
}
