public import Picture

extension Particles {
    /// One particle as light in the picture: a soft disc at a position, of a radius, a colour and a strength,
    /// spread further by a blur. Its whole light is the colour's pixel times the strength times `π × radius² / 3`,
    /// what a `Picture.Sprites.Sprite` of that colour and radius adds under the soft profile; a blur spreads
    /// it wider without changing it.
    public struct Mote: Sendable, Hashable {
        /// Where in the picture.
        public var position: Picture.Plane.Point<2>

        /// The radius of the soft disc in picture units.
        public var radius: Double

        /// The colour; its alpha scales the light as the strength does.
        public var color: Picture.Color

        /// How strong the light is, 1 for the colour itself at the centre of a sharp disc.
        public var strength: Double

        /// The blur radius in picture units.
        public var blur: Double

        /// A mote at a position.
        public init(position: Picture.Plane.Point<2>, radius: Double, color: Picture.Color, strength: Double = 1, blur: Double = 0) {
            self.position = position
            self.radius = radius
            self.color = color
            self.strength = strength
            self.blur = blur
        }
    }
}

extension Particles.Mote {
    /// A particle of a size in the world, seen: its position, its radius the size times the sight's scale, so
    /// that its whole light falls as the square of its distance, and the sight's blur.
    public init(_ sight: Particles.View.Sight, size: Double, color: Picture.Color, strength: Double = 1) {
        self.init(position: sight.position, radius: size * sight.scale, color: color, strength: strength, blur: sight.blur)
    }

    /// The radius its light is spread over in picture units: the root of the sum of the squares of the radius
    /// and the blur.
    public var spread: Double {
        (radius * radius + blur * blur).squareRoot()
    }

    /// The mote with its strength multiplied by an opacity.
    public func faded(by opacity: Double) -> Self {
        var mote = self
        mote.strength *= opacity
        return mote
    }
}
