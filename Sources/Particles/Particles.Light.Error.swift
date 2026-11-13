extension Particles.Light {
    /// Why light cannot be added to light.
    public enum Error: Swift.Error, Sendable, Hashable {
        /// The other light covers another rectangle or has another scale.
        case mismatch
    }
}
