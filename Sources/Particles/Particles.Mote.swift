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

extension Particles.Mote {
    /// This mote part of the way to another, the share held to 0…1: its position along the straight line to
    /// the other's, or along the way a passage bends (`Passage.place(from:to:share:)` in the picture's plane);
    /// its radius, strength and blur each `self × (1 − s) + other × s`; and its colour `mixed(inSRGBTo:at:)`.
    /// At 0 it is this mote and at 1 the other, exactly.
    public func mixed(to other: Self, at share: Double, through passage: Particles.Passage? = nil) -> Self {
        guard share > 0 else { return self }
        guard share < 1 else { return other }
        let rest = 1 - share
        let position: Picture.Plane.Point<2>
        if let passage {
            let place = passage.place(
                from: Point(x: self.position[0], y: self.position[1], z: 0),
                to: Point(x: other.position[0], y: other.position[1], z: 0),
                share: share
            )
            position = Picture.Plane.Point<2>([place.x, place.y])
        } else {
            position = Picture.Plane.Point<2>([
                self.position[0] * rest + other.position[0] * share,
                self.position[1] * rest + other.position[1] * share,
            ])
        }
        return Self(
            position: position,
            radius: radius * rest + other.radius * share,
            color: color.interpolated(inSRGBTo: other.color, at: share),
            strength: strength * rest + other.strength * share,
            blur: blur * rest + other.blur * share
        )
    }
}
