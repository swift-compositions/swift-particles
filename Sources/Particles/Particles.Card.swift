public import Picture

extension Particles {
    /// A flat piece of paper as the picture sees it, such as a piece of confetti: a parallelogram or the ellipse
    /// inside it, around a centre with two half-axes in picture units, of a colour, lit by how squarely it faces
    /// the eye from either side, blurred by its distance from the focus, and kept with its distance so that
    /// cards are drawn far to near.
    public struct Card: Sendable, Hashable {
        /// The centre in the picture.
        public var center: Picture.Plane.Point<2>

        /// Half the card's width, as a direction and length in the picture.
        public var across: Vector<2, Double>

        /// Half the card's height, as a direction and length in the picture.
        public var along: Vector<2, Double>

        /// The rectangle or the ellipse.
        public var cut: Cut

        /// The colour of the paper.
        public var color: Picture.Color

        /// How much light the paper gives back, 0…1, a factor on its colour.
        public var brightness: Double

        /// How much of a light it gives back as a glint, 0…1: the share of the way from the lit paper to the
        /// light's colour.
        public var glint: Double

        /// The colour of the light it glints with.
        public var shine: Picture.Color

        /// The blur radius in picture units.
        public var blur: Double

        /// How far ahead of the eye it lies.
        public var distance: Double

        /// A card around a centre.
        public init(
            center: Picture.Plane.Point<2>,
            across: Vector<2, Double>,
            along: Vector<2, Double>,
            cut: Cut = .rectangle,
            color: Picture.Color,
            brightness: Double = 1,
            glint: Double = 0,
            shine: Picture.Color = .white,
            blur: Double = 0,
            distance: Double = 0
        ) {
            self.center = center
            self.across = across
            self.along = along
            self.cut = cut
            self.color = color
            self.brightness = brightness
            self.glint = glint
            self.shine = shine
            self.blur = blur
            self.distance = distance
        }
    }
}

extension Particles.Card {
    /// A flat piece of a width and a height in the world, in a pose, seen: its centre and the ends of its two
    /// half-axes put through the view, so a piece far away is small and one turned edge-on is thin; its
    /// brightness `1 − shade × (1 − f)` for f how squarely it faces the eye, from either side; the sight's blur
    /// and distance; and, under a sheen, the glint its normal catches. Nil when the view does not see its centre or
    /// the end of a half-axis.
    public init?(
        _ pose: Particles.Pose,
        width: Double,
        height: Double,
        cut: Cut = .rectangle,
        color: Picture.Color,
        shade: Double = 0.5,
        sheen: Particles.Sheen? = nil,
        through view: Particles.View
    ) {
        func end(_ axis: Vector<3, Double>, _ length: Double) -> Point<3, Double> {
            Point(x: pose.place.x + axis.x * length, y: pose.place.y + axis.y * length, z: pose.place.z + axis.z * length)
        }
        guard
            let middle = view.sight(of: pose.place),
            let side = view.sight(of: end(pose.across, width / 2)),
            let top = view.sight(of: end(pose.along, height / 2))
        else { return nil }
        let normal = view.direction(pose.normal)
        let facing = Swift.abs(normal.z)
        self.init(
            center: middle.position,
            across: Vector(x: side.position[0] - middle.position[0], y: side.position[1] - middle.position[1]),
            along: Vector(x: top.position[0] - middle.position[0], y: top.position[1] - middle.position[1]),
            cut: cut,
            color: color,
            brightness: 1 - shade * (1 - facing),
            glint: sheen?.glint(normal: normal) ?? 0,
            shine: sheen?.color ?? .white,
            blur: middle.blur,
            distance: middle.distance
        )
    }

    /// The share of a pixel the card covers at a point of a raster, the card's centre, axes and blur already in
    /// the raster's pixels: the card filtered by a box `2h` wide, h the blur and at least half a pixel. For the
    /// rectangle it is, for each pair of opposite sides, the share of the stretch `2h` long across them around
    /// the point that lies between them, and the product of the two, so its whole area is kept however wide the
    /// blur; for the ellipse it is the same smoothing across its edge, thinned as the rectangle's would be.
    static func coverage(
        at point: (x: Double, y: Double),
        center: (x: Double, y: Double),
        across: (x: Double, y: Double),
        along: (x: Double, y: Double),
        cut: Cut,
        half: Double,
        slabs: (first: (x: Double, y: Double, width: Double), second: (x: Double, y: Double, width: Double))
    ) -> Double {
        let offset = (x: point.x - center.x, y: point.y - center.y)
        func share(_ slab: (x: Double, y: Double, width: Double)) -> Double {
            let place = offset.x * slab.x + offset.y * slab.y
            let low = Swift.max(place - half, -slab.width)
            let high = Swift.min(place + half, slab.width)
            return high > low ? (high - low) / (2 * half) : 0
        }
        switch cut {
        case .rectangle:
            return share(slabs.first) * share(slabs.second)

        case .ellipse:
            let determinant = across.x * along.y - along.x * across.y
            guard Swift.abs(determinant) > 1e-12 else { return 0 }
            let u = (offset.x * along.y - offset.y * along.x) / determinant
            let v = (across.x * offset.y - across.y * offset.x) / determinant
            let radius = (u * u + v * v).squareRoot()
            let thin = Swift.min(1, Swift.min(slabs.first.width, slabs.second.width) / half)
            guard radius > 1e-12 else { return thin }
            let gradient = (
                x: (along.y * u - across.y * v) / (determinant * radius),
                y: (-along.x * u + across.x * v) / (determinant * radius)
            )
            let steep = (gradient.x * gradient.x + gradient.y * gradient.y).squareRoot()
            let distance = (radius - 1) / Swift.max(steep, 1e-12)
            return Swift.min(Swift.max(0.5 - distance / (2 * half), 0), 1) * thin
        }
    }
}
