public import Picture

extension Rational {
    /// The instant as seconds in floating point, the form every motion computes with.
    @usableFromInline
    var seconds: Double { approximation(as: Double.self) }
}
