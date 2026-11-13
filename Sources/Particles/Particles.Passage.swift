import Numeric
public import Picture

extension Particles {
    /// A move of a population from one home to another over a span of time, staggered: each particle has an
    /// order in 0…1 and leaves at `start + (end − each − start) × order`, takes `each` to arrive, and goes the
    /// eased share of the way. So order 0 leaves at the start and order 1 arrives at the end. With a `turn`
    /// the way bends: what is left of it is turned about `axis` by `turn × 4 × s × (1 − s)` at the share s,
    /// none at either end.
    public struct Passage: Sendable {
        /// The instant the first particle leaves.
        public let start: Rational

        /// The instant the last particle arrives.
        public let end: Rational

        /// How long one particle's way takes; held to the span.
        public let each: Rational

        /// How a particle's share of the way follows its share of the time.
        public let easing: Timeline.Easing<Double>

        /// How far the way bends at its middle.
        public let turn: Radian<Double>

        /// The axis the way bends about.
        public let axis: Vector<3, Double>

        /// The span and the time of one way as seconds.
        let seconds: (start: Double, end: Double, each: Double)

        /// A passage over a span, each particle's way taking a time, eased.
        public init(
            from start: Rational,
            to end: Rational,
            each: Rational,
            easing: Timeline.Easing<Double> = .smooth,
            turn: Radian<Double> = .zero,
            axis: Vector<3, Double> = Vector(x: 0, y: 0, z: 1)
        ) {
            self.start = start
            self.end = end
            self.each = each
            self.easing = easing
            self.turn = turn
            self.axis = axis
            let span = Swift.max(end.seconds - start.seconds, 0)
            self.seconds = (start.seconds, end.seconds, Swift.min(Swift.max(each.seconds, 0), span))
        }
    }
}

extension Particles.Passage {
    /// When a particle of an order, held to 0…1, leaves, in seconds.
    public func departure(of order: Double) -> Double {
        seconds.start + (seconds.end - seconds.each - seconds.start) * Swift.min(Swift.max(order, 0), 1)
    }

    /// The share of its way a particle of an order has gone at an instant: 0 before it leaves, 1 once it has
    /// arrived, and the easing of the share of `each` gone between.
    public func share(of order: Double, at instant: Rational) -> Double {
        share(of: order, after: instant.seconds)
    }

    /// The share of its way a particle of an order has gone at a time in seconds.
    public func share(of order: Double, after time: Double) -> Double {
        let left = time - departure(of: order)
        guard left > 0 else { return 0 }
        guard left < seconds.each, seconds.each > 0 else { return 1 }
        return easing.progress(left, seconds.each)
    }

    /// Where a particle of an order is at an instant on its way from one place to another.
    public func place(from start: Point<3, Double>, to end: Point<3, Double>, order: Double, at instant: Rational) -> Point<3, Double> {
        place(from: start, to: end, share: share(of: order, at: instant))
    }

    /// The place a share of the way from one place to another: the start at 0 and the end at 1, along the
    /// straight line between without a turn.
    public func place(from start: Point<3, Double>, to end: Point<3, Double>, share: Double) -> Point<3, Double> {
        let rest = 1 - share
        var left = (x: (start.x - end.x) * rest, y: (start.y - end.y) * rest, z: (start.z - end.z) * rest)
        let angle = turn.underlying * 4 * share * rest
        if angle != 0 {
            let length = (axis.x * axis.x + axis.y * axis.y + axis.z * axis.z).squareRoot()
            if length > 0 {
                let unit = (x: axis.x / length, y: axis.y / length, z: axis.z / length)
                let (cosine, sine) = (Double.cos(angle), Double.sin(angle))
                let along = unit.x * left.x + unit.y * left.y + unit.z * left.z
                let cross = (
                    x: unit.y * left.z - unit.z * left.y,
                    y: unit.z * left.x - unit.x * left.z,
                    z: unit.x * left.y - unit.y * left.x
                )
                left = (
                    x: left.x * cosine + cross.x * sine + unit.x * along * (1 - cosine),
                    y: left.y * cosine + cross.y * sine + unit.y * along * (1 - cosine),
                    z: left.z * cosine + cross.z * sine + unit.z * along * (1 - cosine)
                )
            }
        }
        return Point(x: end.x + left.x, y: end.y + left.y, z: end.z + left.z)
    }
}
