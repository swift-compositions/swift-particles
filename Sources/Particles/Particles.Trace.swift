public import Picture

extension Particles {
    /// The line of a path, every part of it as likely as its share of the length: the path flattened to within
    /// a tolerance and laid in the world's plane z = 0 with picture y turned up and the middle of its box at
    /// the origin. A line has no one normal, so its homes have none.
    public struct Trace: Sendable, Hashable {
        /// The straight pieces of the flattened path, in the world.
        public let pieces: [Piece]

        /// The length of the pieces up to and including each one, in order.
        public let running: [Double]

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
            var pieces: [Piece] = []
            var running: [Double] = []
            var total = 0.0
            for (start, end) in lines {
                let piece = Piece(start: Particles.place(of: start, around: middle), end: Particles.place(of: end, around: middle))
                guard piece.length > 0 else { continue }
                total += piece.length
                pieces.append(piece)
                running.append(total)
            }
            guard total > 0, total.isFinite else { return nil }
            self.pieces = pieces
            self.running = running
        }
    }
}

extension Particles.Trace {
    /// The whole length of the line.
    public var length: Double { running.last ?? 0 }
}

extension Particles.Trace: Particles.Shape {
    /// A particle's home: draw 0 times the length, measured along the line from its start.
    public func home(_ draws: Particles.Draws) -> Particles.Home {
        let lot = draws[0] * length
        var (from, to) = (running.startIndex, running.endIndex - 1)
        while from < to {
            let middle = from + (to - from) / 2
            if running[middle] < lot { from = middle + 1 } else { to = middle }
        }
        let piece = pieces[from]
        let share = Swift.min(Swift.max((lot - (running[from] - piece.length)) / piece.length, 0), 1)
        return Particles.Home(place: piece.point(at: share))
    }
}
