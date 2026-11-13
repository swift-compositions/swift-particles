import Picture

/// Particle systems for pictures: a seeded population of particles, each with a place at any instant that
/// follows from the seed, the particle and the instant alone, drawn into a `Picture` as light or as cards.
public enum Particles {}

extension Particles {
    /// A point of picture space as a place of the world's plane z = 0: x as it is and y turned over, since
    /// picture space has y down and the world y up, both measured from a middle.
    static func place(of point: Picture.Plane.Point<2>, around middle: (x: Double, y: Double)) -> Point<3, Double> {
        Point(x: point[0] - middle.x, y: middle.y - point[1], z: 0)
    }

    /// The middle of the box around points of picture space, (0, 0) for none.
    static func middle(of points: some Swift.Sequence<Picture.Plane.Point<2>>) -> (x: Double, y: Double) {
        var low = (x: Double.infinity, y: Double.infinity)
        var high = (x: -Double.infinity, y: -Double.infinity)
        for point in points {
            low = (Swift.min(low.x, point[0]), Swift.min(low.y, point[1]))
            high = (Swift.max(high.x, point[0]), Swift.max(high.y, point[1]))
        }
        guard low.x <= high.x, low.y <= high.y else { return (0, 0) }
        return ((low.x + high.x) / 2, (low.y + high.y) / 2)
    }

    /// Three draws as one centred on 0 within −1…1, their mean moved and stretched, so most fall near 0.
    static func centred(_ draws: Particles.Draws, _ first: Ordinal) -> Double {
        let second = Ordinal(first.rawValue + 1)
        let third = Ordinal(first.rawValue + 2)
        return (draws[first] + draws[second] + draws[third] - 1.5) / 1.5
    }
}

extension Particles {
    /// The placement of a raster of `scale` pixels to a unit whose first corner lies at a rectangle's.
    static func placement(of frame: Picture.Plane.Rectangle, scale: Double) -> Picture.Transform {
        Picture.Transform(rows: [[1 / scale, 0, frame.llx.underlying], [0, 1 / scale, frame.lly.underlying]])
    }

    /// A rectangle as a closed path of four straight sides.
    static func path(of frame: Picture.Plane.Rectangle) -> Picture.Plane.Path {
        let (left, top, right, bottom) = (frame.llx.underlying, frame.lly.underlying, frame.urx.underlying, frame.ury.underlying)
        let corners: [Picture.Plane.Point<2>] = [.init([left, top]), .init([right, top]), .init([right, bottom]), .init([left, bottom])]
        let sides = zip(corners, corners.dropFirst() + corners.prefix(1)).map { start, end in
            Picture.Plane.Path.Segment.line(.init(start: start, end: end))
        }
        return Picture.Plane.Path(subpaths: [.init(startPoint: corners[0], segments: sides, isClosed: true)])
    }
}
