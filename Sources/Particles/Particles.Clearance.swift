public import Picture

extension Particles {
    /// A rectangle of the picture that must stay readable: what comes into it is faded to a floor, and what
    /// comes near it fades smoothly over a feather.
    public struct Clearance: Sendable, Hashable {
        /// The rectangle to keep clear.
        public var region: Picture.Plane.Rectangle

        /// The opacity inside the rectangle, 0…1.
        public var floor: Double

        /// How far outside the rectangle the fade reaches.
        public var feather: Double

        /// A clearance of a rectangle.
        public init(region: Picture.Plane.Rectangle, floor: Double = 0, feather: Double) {
            self.region = region
            self.floor = floor
            self.feather = feather
        }
    }
}

extension Particles.Clearance {
    /// How far a point lies outside the rectangle, 0 inside it.
    public func distance(of point: Picture.Plane.Point<2>) -> Double {
        let across = Swift.max(region.llx.underlying - point[0], 0, point[0] - region.urx.underlying)
        let down = Swift.max(region.lly.underlying - point[1], 0, point[1] - region.ury.underlying)
        return (across * across + down * down).squareRoot()
    }

    /// The opacity of something of an extent around a point: the floor where it reaches the rectangle, 1 from
    /// a feather beyond it, and between them `3u² − 2u³` of the share u of the feather it lies beyond.
    public func opacity(at point: Picture.Plane.Point<2>, extent: Double = 0) -> Double {
        let gap = distance(of: point) - extent
        guard gap > 0 else { return floor }
        guard gap < feather else { return 1 }
        let share = gap / feather
        return floor + (1 - floor) * share * share * (3 - 2 * share)
    }

    /// The least opacity any of the clearances gives, 1 for none.
    public static func opacity(at point: Picture.Plane.Point<2>, extent: Double = 0, among clearances: some Swift.Sequence<Self>) -> Double {
        clearances.reduce(1) { Swift.min($0, $1.opacity(at: point, extent: extent)) }
    }
}
