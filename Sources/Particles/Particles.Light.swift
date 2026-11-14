import Numeric
public import Picture

extension Particles {
    /// Light added up over a rectangle of the picture, mote by mote, and handed to a renderer as one image: many
    /// soft sprites for the price of one image, since light adds and needs no depth order.
    ///
    /// A light is a description: its rectangle, its scale and footprint, and what was added to it, in order. It
    /// is drawn into a raster of its own only when its pixels are asked for, by `raster`, `sum`, or a renderer
    /// drawing a picture that holds its `image`, which names the light as its source; so building a light,
    /// comparing two and hashing one cost what the motes cost, never what the raster does.
    ///
    /// A mote's whole light is spread over a soft disc of the radius `spread`, at least `footprint` pixels, by
    /// the weights `(1 − d²/R²)²` at the pixels' centres divided by their sum, so the light it adds to the
    /// raster is its whole light exactly, wherever it falls between pixel centres: a particle that moves less
    /// than a pixel neither flickers nor dims. A trail of motes read across a shutter spreads the same light
    /// along the way it travelled: each straight piece between two motes takes an equal share, spread by the
    /// soft disc swept along the piece, the integral in closed form, again divided by the weights' sum. A
    /// persistence brightens a streak by a power of how much its length dims it, up to keeping the still mote's
    /// brightness along the whole way.
    public struct Light: Sendable, Hashable {
        /// The rectangle of the picture the raster covers.
        public let frame: Picture.Plane.Rectangle

        /// Pixels of the raster to a unit of the picture.
        public let scale: Double

        /// The least radius, in pixels, light is spread over; at least 1, so a disc always holds a pixel centre.
        public let footprint: Double

        /// The raster's width in pixels.
        public let width: Cardinal

        /// The raster's height in pixels.
        public let height: Cardinal

        /// What was added, in the order it was added.
        var additions: [Addition]

        /// No light yet over a rectangle, at a scale, spreading light over at least a footprint.
        public init(frame: Picture.Plane.Rectangle, scale: Double = 1, footprint: Double = 1.25) {
            let scale = scale > 0 && scale.isFinite ? scale : 1
            let across = Swift.max(((frame.urx.underlying - frame.llx.underlying) * scale).rounded(.up), 0)
            let down = Swift.max(((frame.ury.underlying - frame.lly.underlying) * scale).rounded(.up), 0)
            self.frame = frame
            self.scale = scale
            self.footprint = Swift.max(footprint, 1)
            self.width = Cardinal(UInt(across))
            self.height = Cardinal(UInt(down))
            self.additions = []
        }
    }
}

extension Particles.Light {
    /// A mote's whole light: its colour's pixel times its strength times `π × radius² / 3`, the radius in pixels.
    public func total(of mote: Particles.Mote) -> SIMD4<Float> {
        let radius = mote.radius * scale
        let amount = Float(mote.strength * Double.pi * radius * radius / 3)
        let pixel = mote.color.pixel
        let light = SIMD4<Float>(pixel.color.red, pixel.color.green, pixel.color.blue, pixel.alpha) * amount
        return amount.isFinite && light.x.isFinite && light.y.isFinite && light.z.isFinite && light.w.isFinite ? light : .zero
    }

    /// A position of the picture in the raster's pixels.
    func pixel(of position: Picture.Plane.Point<2>) -> (x: Double, y: Double) {
        ((position[0] - frame.llx.underlying) * scale, (position[1] - frame.lly.underlying) * scale)
    }

    /// How many times its whole light a trail is drawn with: `g^persistence`, where g is how much a streak of
    /// the trail's length L dims the middle of its way below the centre of the still mote, both spread over the
    /// soft disc of the motes' mean spread R in pixels, at least the footprint: `g = L / 2F(min(L/2, R))`,
    /// F(x) = `x − 2x³/3R² + x⁵/5R⁴` the profile's integral out to x, so g is 1 for a still mote and
    /// `15L / 16R` once the streak is longer than the disc. A persistence of 0 keeps the trail's light, 1 keeps
    /// the brightness of its middle, and between them a long streak keeps a part of each.
    public func gain(of trail: some Swift.Collection<Particles.Mote>, persistence: Double) -> Double {
        guard persistence != 0, persistence.isFinite, let first = trail.first else { return 1 }
        var length = 0.0
        var spread = 0.0
        var previous = pixel(of: first.position)
        for mote in trail {
            let at = pixel(of: mote.position)
            let (across, down) = (at.x - previous.x, at.y - previous.y)
            length += (across * across + down * down).squareRoot()
            spread += mote.spread
            previous = at
        }
        let radius = Swift.max(spread / Double(trail.count) * scale, footprint)
        let half = Swift.min(length / 2, radius)
        let (square, quartic) = (radius * radius, radius * radius * radius * radius)
        let core = half - 2 * half * half * half / (3 * square) + half * half * half * half * half / (5 * quartic)
        guard length > 0, core > 0, length.isFinite else { return 1 }
        let gain = Double.exp(persistence * Double.log(length / (2 * core)))
        return gain.isFinite ? gain : 1
    }
}

extension Particles.Light {
    /// Adds a mote's light at its position.
    public mutating func add(_ mote: Particles.Mote) {
        additions.append(.mote(mote))
    }

    /// Adds the light of a particle read at evenly spaced instants across a shutter: the mean of the motes'
    /// whole light, times `gain(of:persistence:)`, spread along the way from each mote to the next, each piece
    /// of the way taking an equal share. Pieces shorter together than a quarter of a pixel are spread as one
    /// straight piece with their shares together, which keeps the light and saves spreading a disc for each.
    /// With no persistence a trail of equal motes is that mote, one mote is itself, and a streak keeps the
    /// still mote's whole light, as a camera's shutter does; a persistence of 1 keeps its brightness instead.
    public mutating func add(trail motes: some Swift.Collection<Particles.Mote>, persistence: Double = 0) {
        let motes = Array(motes)
        guard let first = motes.first else { return }
        guard motes.contains(where: { $0 != first }) else { return add(first) }
        additions.append(.trail(motes, persistence: persistence))
    }

    /// Adds the light of another over the same rectangle at the same scale, pixel by pixel, so that parts of a
    /// population spread on several threads add up to the whole; added in a fixed order they give the same
    /// raster whatever the number of threads. Light over another rectangle or scale is refused.
    public mutating func add(_ other: Self) throws(Particles.Light.Error) {
        guard other.frame == frame, other.scale == scale, other.width == width, other.height == height else { throw .mismatch }
        additions.append(.light(other))
    }
}

extension Particles.Light {
    /// The light drawn now as working pixels: each pixel's sums, alpha held to at most 1. Colour is not held, so
    /// light brighter than white stays for a bloom or a threshold to find.
    public var raster: Raster<Picture.Pixel> {
        let pixels = sums.map { sum in
            Picture.Pixel(color: .init(red: sum.x, green: sum.y, blue: sum.z), alpha: Swift.min(sum.w, 1))
        }
        do throws(Raster<Picture.Pixel>.Error) {
            return try Raster(width: width, height: height, pixels: pixels)
        } catch {
            preconditionFailure("the light holds a pixel for every place of its raster")
        }
    }

    /// The light as an image placed over its rectangle, one pixel a part in `scale` of a unit. The image names
    /// the light as its source and holds no pixels: the renderer that draws it draws the light, once, and may keep
    /// the raster for the next picture that holds an equal light.
    public var image: Picture.Image {
        Picture.Image(self, placement: Particles.placement(of: frame, scale: scale))
    }

    /// The light as an element: its rectangle filled with the image in a layer under `lighter`, so it adds to
    /// what is behind.
    public var element: Picture.Element {
        .layer(Picture.Layer([.fill(Particles.path(of: frame), .image(image))], operator: .lighter))
    }

    /// The light drawn now and added up over every pixel, premultiplied red, green, blue and alpha.
    public var sum: SIMD4<Float> {
        sums.reduce(.zero, +)
    }
}

extension Particles.Light: Picture.Image.Drawing {
    /// The light drawn, as `raster` draws it; it draws nothing through the renderer.
    public func raster(through renderer: Picture.Renderer) throws(Picture.Renderer.Error) -> Raster<Picture.Pixel> {
        raster
    }
}
