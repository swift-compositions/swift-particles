public import Picture

extension Particles {
    /// A line made of straight pieces, every part of it as likely as its share of the length: a path flattened
    /// to within a tolerance and laid in the world's plane z = 0 with picture y turned up and the middle of its
    /// box at the origin, or a chain of places in order. A line has no one normal, so its homes have none.
    ///
    /// A particle on a line is its distance along it, and a flow is that distance growing with time:
    /// `place(along:)` takes a distance around the whole length, from one piece to the next and from the last
    /// back to the first, so a flow goes round forever. Where one piece does not start where the one before it
    /// ends, between the subpaths of a path or across a gap in a chain, the line is broken and a flow leaps
    /// across at once; `unbroken(from:to:)` says whether a stretch of the line crosses such a break.
    public struct Trace: Sendable, Hashable {
        /// The straight pieces of the line, in order.
        public let pieces: [Piece]

        /// The length of the pieces up to and including each one, in order.
        public let running: [Double]

        /// A line of pieces, those of no length left out; nil when no length is left.
        init?(pieces: some Swift.Sequence<Piece>) {
            var kept: [Piece] = []
            var running: [Double] = []
            var total = 0.0
            for piece in pieces {
                let length = piece.length
                guard length > 0, length.isFinite else { continue }
                total += length
                kept.append(piece)
                running.append(total)
            }
            guard total > 0, total.isFinite else { return nil }
            self.pieces = kept
            self.running = running
        }
    }
}

extension Particles.Trace {
    /// The line of a path flattened to within a tolerance; nil for a path with no length, or a tolerance
    /// that is not positive and finite.
    public init?(_ path: Picture.Plane.Path, tolerance: Double) {
        let flat: Picture.Plane.Path
        do throws(Picture.Plane.Path.Error) {
            flat = try path.flattened(tolerance: .init(tolerance))
        } catch {
            return nil
        }
        let lines = flat.subpaths.flatMap { subpath in
            var ends: [(Picture.Plane.Point<2>, Picture.Plane.Point<2>)] = []
            var at = subpath.startPoint
            for segment in subpath.segments {
                guard let end = segment.endPoint else { continue }
                ends.append((at, end))
                at = end
            }
            if subpath.isClosed { ends.append((at, subpath.startPoint)) }
            return ends
        }
        let middle = Particles.middle(of: lines.flatMap { [$0.0, $0.1] })
        self.init(pieces: lines.lazy.map { Piece(start: Particles.place(of: $0.0, around: middle), end: Particles.place(of: $0.1, around: middle)) })
    }

    /// The line through places in order, as they are, and from the last back to the first when closed. A step
    /// longer than `gap` is a break: it is left out and the line leaps across it. Nil when no step of any length
    /// is left.
    public init?(through places: [Point<3, Double>], closed: Bool = false, gap: Double = .infinity) {
        var steps = zip(places, places.dropFirst()).map { Piece(start: $0, end: $1) }
        if closed, places.count > 2, let first = places.first, let last = places.last {
            steps.append(Piece(start: last, end: first))
        }
        self.init(pieces: steps.lazy.filter { $0.length <= gap })
    }
}

extension Particles.Trace {
    /// The whole length of the line.
    public var length: Double { running.last ?? 0 }

    /// The piece a distance along the line lies on, and the share of that piece it is from its start, the
    /// distance held to the line.
    func spot(at distance: Double) -> (piece: Int, share: Double) {
        var (from, to) = (running.startIndex, running.endIndex - 1)
        while from < to {
            let middle = from + (to - from) / 2
            if running[middle] < distance { from = middle + 1 } else { to = middle }
        }
        let piece = pieces[from]
        return (from, Swift.min(Swift.max((distance - (running[from] - piece.length)) / piece.length, 0), 1))
    }

    /// A distance along the line taken around its whole length, into 0 up to the length.
    func around(_ distance: Double) -> Double {
        guard distance.isFinite else { return 0 }
        let wrapped = distance - length * (distance / length).rounded(.down)
        return wrapped < length ? Swift.max(wrapped, 0) : 0
    }

    /// The place a distance along the line from its start, the distance taken around the whole length, so a
    /// distance that grows with time flows along the line and round again.
    public func place(along distance: Double) -> Point<3, Double> {
        let spot = spot(at: around(distance))
        return pieces[spot.piece].point(at: spot.share)
    }

    /// Whether the line runs on without a break from one distance along it to another ahead of it, both taken
    /// around the whole length and the way going forward, round past the end when the second lies behind the
    /// first: whether each piece on the way starts where the one before it ends. A streak drawn between the
    /// two then follows the line instead of crossing a gap.
    public func unbroken(from start: Double, to end: Double) -> Bool {
        var at = spot(at: around(start)).piece
        let last = spot(at: around(end)).piece
        let wraps = around(end) < around(start)
        var steps = wraps ? pieces.count - at + last : last - at
        while steps > 0 {
            let next = (at + 1) % pieces.count
            guard pieces[at].end == pieces[next].start else { return false }
            at = next
            steps -= 1
        }
        return true
    }
}

extension Particles.Trace: Particles.Shape {
    /// A particle's home: draw 0 times the length, measured along the line from its start.
    public func home(_ draws: Particles.Draws) -> Particles.Home {
        Particles.Home(place: place(along: draws[0] * length))
    }
}
