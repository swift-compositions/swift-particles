import Numeric
public import Picture

extension Particles {
    /// A particle thrown from a place at an instant with a velocity, under a constant acceleration such as
    /// gravity and a drag in proportion to its velocity: along each axis a `Ballistics.Trajectory` of
    /// swift-ballistics with the same drag, so its place at any instant is in closed form. A flat piece in
    /// flight also flutters.
    public struct Flight: Sendable, Hashable {
        /// Where it is thrown from.
        public let origin: Point<3, Double>

        /// When it is thrown.
        public let launch: Rational

        /// The motion along x.
        public let x: Ballistics.Trajectory<Double>

        /// The motion along y.
        public let y: Ballistics.Trajectory<Double>

        /// The motion along z.
        public let z: Ballistics.Trajectory<Double>

        /// How a flat piece turns and sways on the way.
        public let flutter: Particles.Flutter

        /// The launch in seconds.
        let seconds: Double

        /// A throw from a place at an instant; it fails as `Ballistics.Trajectory` does, for a velocity or an
        /// acceleration that is not finite and a drag that is negative or not finite.
        public init(
            from origin: Point<3, Double>,
            at launch: Rational,
            velocity: Vector<3, Double>,
            acceleration: Vector<3, Double>,
            drag: Double,
            flutter: Particles.Flutter = .still
        ) throws(Ballistics.Trajectory<Double>.Error) {
            self.origin = origin
            self.launch = launch
            self.x = try Ballistics.Trajectory(velocity: velocity.x, acceleration: acceleration.x, drag: drag)
            self.y = try Ballistics.Trajectory(velocity: velocity.y, acceleration: acceleration.y, drag: drag)
            self.z = try Ballistics.Trajectory(velocity: velocity.z, acceleration: acceleration.z, drag: drag)
            self.flutter = flutter
            self.seconds = launch.seconds
        }
    }
}

extension Particles.Flight {
    /// Where it is at an instant: the origin before the launch, then the trajectories' positions plus the
    /// sway along x.
    public func place(at instant: Rational) -> Point<3, Double> {
        place(after: instant.seconds)
    }

    /// Where it is at a time in seconds.
    public func place(after time: Double) -> Point<3, Double> {
        let flown = Swift.max(time - seconds, 0)
        let settled = -Double.expm1(-x.drag * flown)
        let sway = flutter.sway * settled * Double.sin(flutter.swaying.underlying * flown + flutter.phase.underlying)
        return Point(
            x: origin.x + x.position(at: flown) + sway,
            y: origin.y + y.position(at: flown),
            z: origin.z + z.position(at: flown)
        )
    }

    /// The pose of a flat piece at an instant: its place, and its width and height first spun about +z and then
    /// tumbled about the spun width.
    public func pose(at instant: Rational) -> Particles.Pose {
        pose(after: instant.seconds)
    }

    /// The pose of a flat piece at a time in seconds.
    public func pose(after time: Double) -> Particles.Pose {
        let flown = Swift.max(time - seconds, 0)
        let spin = flutter.spin.underlying + flutter.spinning.underlying * flown
        let tumble = flutter.tumble.underlying + flutter.tumbling.underlying * flown
        let (cs, ss) = (Double.cos(spin), Double.sin(spin))
        let (ct, st) = (Double.cos(tumble), Double.sin(tumble))
        return Particles.Pose(
            place: place(after: time),
            across: Vector(x: cs, y: ss, z: 0),
            along: Vector(x: -ss * ct, y: cs * ct, z: st)
        )
    }

    /// Whether it has been thrown by an instant.
    public func launched(by instant: Rational) -> Bool {
        instant.seconds >= seconds
    }
}
