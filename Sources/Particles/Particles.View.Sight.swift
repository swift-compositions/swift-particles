public import Picture

extension Particles.View {
    /// A place as a view sees it: where in the picture, how deep, how far ahead of the eye, how many picture
    /// units a unit of the world spans there, and how much the focus blurs it.
    public struct Sight: Sendable, Hashable {
        /// Where in the picture.
        public var position: Picture.Plane.Point<2>

        /// The normalised depth, lower for nearer places.
        public var depth: Double

        /// How far ahead of the eye.
        public var distance: Double

        /// How many picture units a unit of the world across the line of sight spans at the place.
        public var scale: Double

        /// The blur radius in picture units, 0 without a focus.
        public var blur: Double

        /// A sight of a place.
        public init(position: Picture.Plane.Point<2>, depth: Double, distance: Double, scale: Double, blur: Double) {
            self.position = position
            self.depth = depth
            self.distance = distance
            self.scale = scale
            self.blur = blur
        }
    }
}
