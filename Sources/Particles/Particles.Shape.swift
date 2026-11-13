extension Particles {
    /// A shape particles make their homes in: a function from a particle's draws to its home. The same draws
    /// give the same home, so a particle's home follows from the seed, the particle and the stream alone.
    public protocol Shape: Sendable {
        /// The home the draws give.
        func home(_ draws: Particles.Draws) -> Particles.Home
    }
}
