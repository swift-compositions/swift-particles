public import Picture

extension Particles {
    /// Cards laid over a rectangle of the picture far to near into a raster of their own, handed to a renderer
    /// as one image. Cards are a description until their pixels are asked for, by `raster` or by a renderer
    /// drawing their `image`, which names them as its source. Paper hides what is behind it, so cards are sorted by distance, farthest first and, at
    /// equal distances, in the order they were added, and each is put over what is drawn so far.
    public struct Cards: Sendable, Hashable {
        /// The rectangle of the picture the raster covers.
        public let frame: Picture.Plane.Rectangle

        /// Pixels of the raster to a unit of the picture.
        public let scale: Double

        /// The cards so far.
        public private(set) var cards: [Particles.Card]

        /// No cards yet over a rectangle at a scale.
        public init(frame: Picture.Plane.Rectangle, scale: Double = 1) {
            self.frame = frame
            self.scale = scale > 0 && scale.isFinite ? scale : 1
            self.cards = []
        }
    }
}

extension Particles.Cards {
    /// Adds a card.
    public mutating func add(_ card: Particles.Card) {
        cards.append(card)
    }

    /// The raster's width and height in pixels.
    var size: (width: Int, height: Int) {
        (
            Int(Swift.max(((frame.urx.underlying - frame.llx.underlying) * scale).rounded(.up), 0)),
            Int(Swift.max(((frame.ury.underlying - frame.lly.underlying) * scale).rounded(.up), 0))
        )
    }

    /// The cards drawn now, far to near, as working pixels.
    public var raster: Raster<Picture.Pixel> {
        let (width, height) = size
        var pixels = [SIMD4<Float>](repeating: .zero, count: width * height)
        let order = cards.indices.sorted { cards[$0].distance > cards[$1].distance || (cards[$0].distance == cards[$1].distance && $0 < $1) }
        for index in order {
            draw(cards[index], into: &pixels, width: width, height: height)
        }
        let raster: Raster<Picture.Pixel>
        do throws(Raster<Picture.Pixel>.Error) {
            raster = try Raster(
                width: Cardinal(UInt(width)),
                height: Cardinal(UInt(height)),
                pixels: pixels.map { Picture.Pixel(color: .init(red: $0.x, green: $0.y, blue: $0.z), alpha: $0.w) }
            )
        } catch {
            preconditionFailure("the cards hold a pixel for every place of their raster")
        }
        return raster
    }

    /// One card put over the pixels whose centres lie within its extent.
    func draw(_ card: Particles.Card, into pixels: inout [SIMD4<Float>], width: Int, height: Int) {
        let center = ((card.center[0] - frame.llx.underlying) * scale, (card.center[1] - frame.lly.underlying) * scale)
        let across = (card.across.x * scale, card.across.y * scale)
        let along = (card.along.x * scale, card.along.y * scale)
        let half = card.softness(scale: scale) * scale
        func slab(_ edge: (Double, Double), _ other: (Double, Double)) -> (x: Double, y: Double, width: Double)? {
            let length = (edge.0 * edge.0 + edge.1 * edge.1).squareRoot()
            guard length > 1e-12, length.isFinite else { return nil }
            let normal = (-edge.1 / length, edge.0 / length)
            return (normal.0, normal.1, Swift.abs(normal.0 * other.0 + normal.1 * other.1))
        }
        guard let first = slab(across, along), let second = slab(along, across), center.0.isFinite, center.1.isFinite else { return }
        let extent = card.extent(scale: scale)
        let low = ((extent.llx.underlying - frame.llx.underlying) * scale, (extent.lly.underlying - frame.lly.underlying) * scale)
        let high = ((extent.urx.underlying - frame.llx.underlying) * scale, (extent.ury.underlying - frame.lly.underlying) * scale)
        guard low.0.isFinite, low.1.isFinite, high.0.isFinite, high.1.isFinite else { return }
        func index(_ place: Double, _ rounding: FloatingPointRoundingRule, below count: Int) -> Int {
            Int(Swift.min(Swift.max((place - 0.5).rounded(rounding), -1), Double(count)))
        }
        let columns = (low: Swift.max(index(low.0, .up, below: width), 0), high: Swift.min(index(high.0, .down, below: width), width - 1))
        let rows = (low: Swift.max(index(low.1, .up, below: height), 0), high: Swift.min(index(high.1, .down, below: height), height - 1))
        guard columns.low <= columns.high, rows.low <= rows.high else { return }
        let paper = card.color.pixel
        let brightness = Float(Swift.min(Swift.max(card.brightness, 0), 1))
        let glint = Float(card.glint.isFinite ? Swift.min(Swift.max(card.glint, 0), 1) : 0)
        let light = card.shine.with(alpha: 1).pixel.color
        let lit =
            SIMD3<Float>(paper.color.red, paper.color.green, paper.color.blue) * brightness * (1 - glint)
            + SIMD3<Float>(light.red, light.green, light.blue) * paper.alpha * glint
        let source = SIMD4<Float>(lit.x, lit.y, lit.z, paper.alpha)
        var row = rows.low
        while row <= rows.high {
            var column = columns.low
            while column <= columns.high {
                let covered = Particles.Card.coverage(
                    at: (Double(column) + 0.5, Double(row) + 0.5),
                    center: center,
                    across: across,
                    along: along,
                    cut: card.cut,
                    half: half,
                    slabs: (first, second)
                )
                if covered > 0 {
                    let index = row * width + column
                    let top = source * Float(covered)
                    pixels[index] = top + pixels[index] * (1 - top.w)
                }
                column += 1
            }
            row += 1
        }
    }

    /// The cards as an image placed over their rectangle, naming the cards as its source: the renderer that
    /// draws it lays them, once.
    public var image: Picture.Image {
        Picture.Image(self, placement: Particles.placement(of: frame, scale: scale))
    }

    /// The cards as an element: their rectangle filled with the image, over what is behind.
    public var element: Picture.Element {
        .fill(Particles.path(of: frame), .image(image))
    }
}

extension Particles.Cards: Picture.Image.Drawing {
    /// The cards drawn, as `raster` draws them; they draw nothing through the renderer.
    public func raster(through renderer: Picture.Renderer) throws(Picture.Renderer.Error) -> Raster<Picture.Pixel> {
        raster
    }
}
