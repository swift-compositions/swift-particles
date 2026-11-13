public import Picture

extension Particles {
    /// A shutter open for a time before each instant a picture is taken at, read at a number of evenly spaced
    /// instants from its opening to its closing, so a particle's travel while it is open can be drawn.
    public struct Shutter: Sendable, Hashable {
        /// How long it is open before the instant.
        public var open: Rational

        /// How many instants it is read at, the opening and the closing among them; fewer than two read only
        /// the closing.
        public var samples: Cardinal

        /// A shutter open for a time, read at a number of instants.
        public init(open: Rational, samples: Cardinal) {
            self.open = open
            self.samples = samples
        }
    }
}

extension Particles.Shutter {
    /// A shutter that is never open: every picture is of its instant alone.
    public static var closed: Self { Self(open: .zero, samples: 1) }

    /// The instants it is read at for a picture taken at an instant, from the opening to the closing at that
    /// instant, evenly spaced; the instant alone when it is not open or reads fewer than two.
    public func instants(closing instant: Rational) -> [Rational] {
        guard samples.rawValue > 1, open.polarity == .positive else { return [instant] }
        let steps = Integer(samples.rawValue - 1)
        return (UInt.zero..<samples.rawValue).map { step in
            let fraction: Rational
            do throws(Rational.Error) {
                fraction = try Rational(numerator: Integer(step), denominator: steps)
            } catch {
                preconditionFailure("a shutter that reads two or more instants has a step")
            }
            return instant - open + open * fraction
        }
    }

    /// The instants it is read at, as seconds: `instants(closing:)` each made a `Double` once, for motions read
    /// many times at the same instants.
    public func seconds(closing instant: Rational) -> [Double] {
        instants(closing: instant).map { $0.approximation(as: Double.self) }
    }
}
