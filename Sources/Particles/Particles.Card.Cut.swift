extension Particles.Card {
    /// The shape cut from the paper.
    public enum Cut: Sendable, Hashable, CaseIterable {
        /// The parallelogram the two half-axes span: a rectangle seen in perspective.
        case rectangle

        /// The ellipse inside that parallelogram: a disc seen in perspective.
        case ellipse
    }
}
