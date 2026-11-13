import Numeric
public import Picture

extension Particles {
    /// Light added up over a rectangle of the picture, mote by mote, into a raster of its own that is handed
    /// to a renderer as one image: many soft sprites for the price of one image, since light adds and needs no
    /// depth order.
    ///
    /// A mote's whole light is spread over a soft disc of the radius `spread`, at least `footprint` pixels, by
    /// the weights `(1 − d²/R²)²` at the pixels' centres divided by their sum, so the light it adds to the
    /// raster is its whole light exactly, wherever it falls between pixel centres: a particle that moves less
    /// than a pixel neither flickers nor dims. A trail of motes read across a shutter spreads the same light
    /// along the way it travelled: each straight piece between two motes takes an equal share, spread by the
    /// soft disc swept along the piece, the integral in closed form, again divided by the weights' sum. A
    /// persistence brightens a streak by a power of how much its length dims it, up to keeping the still mote's
    /// brightness along the whole way.
    public struct Light: Sendable {
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

        /// The light so far, premultiplied red, green, blue and alpha, row by row.
        var sums: [SIMD4<Float>]

        /// The weights of the footprint being spread, kept between footprints so that it is not made anew.
        var scratch: [Double]

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
            self.sums = Array(repeating: .zero, count: Int(across * down))
            self.scratch = []
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

    /// Adds a mote's light at its position.
    public mutating func add(_ mote: Particles.Mote) {
        let total = total(of: mote)
        guard total != .zero else { return }
        let at = pixel(of: mote.position)
        point(x: at.x, y: at.y, radius: Swift.max(mote.spread * scale, footprint), total: total)
    }

    /// Adds the light of a particle read at evenly spaced instants across a shutter: the mean of the motes'
    /// whole light, times `gain(of:persistence:)`, spread along the way from each mote to the next, each piece
    /// of the way taking an equal share. Pieces shorter together than a quarter of a pixel are spread as one
    /// straight piece with their shares together, which keeps the light and saves spreading a disc for each.
    /// With no persistence a trail of equal motes is that mote, one mote is itself, and a streak keeps the
    /// still mote's whole light, as a camera's shutter does; a persistence of 1 keeps its brightness instead.
    public mutating func add(trail motes: some Swift.Collection<Particles.Mote>, persistence: Double = 0) {
        guard let first = motes.first else { return }
        guard motes.contains(where: { $0 != first }) else { return add(first) }
        let share = 0.5 / Float(motes.count - 1) * Float(gain(of: motes, persistence: persistence))
        var run = (start: pixel(of: first.position), total: SIMD4<Float>.zero, spread: 0.0, pieces: 0.0)
        var previous = (mote: first, total: total(of: first))
        for (index, mote) in motes.dropFirst().enumerated() {
            let total = self.total(of: mote)
            let at = pixel(of: mote.position)
            run.total += (previous.total + total) * share
            run.spread += (previous.mote.spread + mote.spread) / 2
            run.pieces += 1
            previous = (mote, total)
            let (across, down) = (at.x - run.start.x, at.y - run.start.y)
            guard across * across + down * down >= 0.0625 || index == motes.count - 2 else { continue }
            if run.total != .zero {
                line(from: run.start, to: at, radius: Swift.max(run.spread / run.pieces * scale, footprint), total: run.total)
            }
            run = (at, .zero, 0, 0)
        }
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

    /// Adds the light of another over the same rectangle at the same scale, pixel by pixel, so that parts of a
    /// population spread on several threads add up to the whole; added in a fixed order they give the same
    /// raster whatever the number of threads. Light over another rectangle or scale is refused.
    public mutating func add(_ other: Self) throws(Particles.Light.Error) {
        guard other.frame == frame, other.scale == scale, other.sums.count == sums.count else { throw .mismatch }
        sums = zip(sums, other.sums).map { $0 + $1 }
    }

    /// Spreads light over a soft disc at a point of the raster.
    mutating func point(x: Double, y: Double, radius: Double, total: SIMD4<Float>) {
        guard x.isFinite, y.isFinite, radius.isFinite else { return }
        let inverse = 1 / (radius * radius)
        let columns = (low: Int((x - radius - 0.5).rounded(.down)) + 1, high: Int((x + radius - 0.5).rounded(.up)) - 1)
        deposit(
            rows: (Int((y - radius - 0.5).rounded(.down)) + 1, Int((y + radius - 0.5).rounded(.up)) - 1),
            columns: { _ in columns },
            weight: { column, row in
                let (across, down) = (Double(column) + 0.5 - x, Double(row) + 0.5 - y)
                let rest = 1 - (across * across + down * down) * inverse
                return rest > 0 ? rest * rest : 0
            },
            total: total
        )
    }

    /// Spreads light over a soft disc swept from one point of the raster to another: at each pixel centre the
    /// integral along the piece of `(1 − d²/R²)²`, which for a centre at a distance a across the piece and t
    /// along it is the antiderivative `c²t − 2ct³/3R² + t⁵/5R⁴`, c = 1 − a²/R², taken over the part of the
    /// piece within the radius.
    mutating func line(from start: (x: Double, y: Double), to end: (x: Double, y: Double), radius: Double, total: SIMD4<Float>) {
        let (across, down) = (end.x - start.x, end.y - start.y)
        let length = (across * across + down * down).squareRoot()
        guard length.isFinite, start.x.isFinite, start.y.isFinite, radius.isFinite else { return }
        guard length > 1e-6 else { return point(x: start.x, y: start.y, radius: radius, total: total) }
        let direction = (x: across / length, y: down / length)
        let square = radius * radius
        let quartic = square * square
        deposit(
            rows: (
                Int((Swift.min(start.y, end.y) - radius - 0.5).rounded(.down)) + 1,
                Int((Swift.max(start.y, end.y) + radius - 0.5).rounded(.up)) - 1
            ),
            columns: { row in
                let center = Double(row) + 0.5
                var (first, last) = (0.0, length)
                if Swift.abs(direction.y) > 1e-12 {
                    let a = (center - radius - start.y) / direction.y
                    let b = (center + radius - start.y) / direction.y
                    (first, last) = (Swift.max(Swift.min(a, b), 0), Swift.min(Swift.max(a, b), length))
                    guard first <= last else { return (1, 0) }
                } else if Swift.abs(center - start.y) >= radius {
                    return (1, 0)
                }
                let xs = (start.x + first * direction.x, start.x + last * direction.x)
                return (
                    Int((Swift.min(xs.0, xs.1) - radius - 0.5).rounded(.down)) + 1,
                    Int((Swift.max(xs.0, xs.1) + radius - 0.5).rounded(.up)) - 1
                )
            },
            weight: { column, row in
                let (x, y) = (Double(column) + 0.5 - start.x, Double(row) + 0.5 - start.y)
                let along = x * direction.x + y * direction.y
                let aside = x * x + y * y - along * along
                let rest = 1 - aside / square
                guard rest > 0 else { return 0 }
                let half = radius * rest.squareRoot()
                let low = Swift.max(-along, -half)
                let high = Swift.min(length - along, half)
                guard high > low else { return 0 }
                let (low2, high2) = (low * low, high * high)
                let upper = high * (rest * rest - (2.0 / 3.0) * rest * high2 / square + high2 * high2 / (5 * quartic))
                let lower = low * (rest * rest - (2.0 / 3.0) * rest * low2 / square + low2 * low2 / (5 * quartic))
                return upper - lower
            },
            total: total
        )
    }

    /// Spreads a whole light over the pixels of rows, each row over its span of columns, in proportion to the
    /// weights: the weights are found once for every pixel, those outside the raster too, so that their sum is
    /// the whole footprint's wherever it lies, and each pixel inside the raster then takes its share.
    @inline(__always)
    mutating func deposit(
        rows: (low: Int, high: Int),
        columns: (Int) -> (low: Int, high: Int),
        weight: (Int, Int) -> Double,
        total: SIMD4<Float>
    ) {
        let width = Int(self.width.rawValue)
        let height = Int(self.height.rawValue)
        guard rows.high >= 0, rows.low < height, rows.low <= rows.high else { return }
        scratch.removeAll(keepingCapacity: true)
        var sum = 0.0
        var row = rows.low
        while row <= rows.high {
            let span = columns(row)
            var column = span.low
            while column <= span.high {
                let part = weight(column, row)
                scratch.append(part)
                sum += part
                column += 1
            }
            row += 1
        }
        guard sum > 0 else { return }
        let share = 1 / sum
        let weights = scratch
        sums.withUnsafeMutableBufferPointer { pixels in
            var index = 0
            var row = rows.low
            while row <= rows.high {
                let span = columns(row)
                guard span.low <= span.high else {
                    row += 1
                    continue
                }
                if row >= 0, row < height {
                    let base = row * width
                    var column = Swift.max(span.low, 0)
                    let last = Swift.min(span.high, width - 1)
                    while column <= last {
                        let part = weights[index + column - span.low]
                        if part > 0 { unsafe pixels[base + column] += total * Float(part * share) }
                        column += 1
                    }
                }
                index += span.high - span.low + 1
                row += 1
            }
        }
    }
}

extension Particles.Light {
    /// The light as working pixels: each pixel's sums, alpha held to at most 1. Colour is not held, so light
    /// brighter than white stays for a bloom or a threshold to find.
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

    /// The light as an image placed over its rectangle, one pixel a part in `scale` of a unit.
    public var image: Picture.Image {
        Picture.Image(raster, placement: Particles.placement(of: frame, scale: scale))
    }

    /// The light as an element: its rectangle filled with the image in a layer under `lighter`, so it adds to
    /// what is behind.
    public var element: Picture.Element {
        .layer(Picture.Layer([.fill(Particles.path(of: frame), .image(image))], operator: .lighter))
    }

    /// The light added up over every pixel, premultiplied red, green, blue and alpha.
    public var sum: SIMD4<Float> {
        sums.reduce(.zero, +)
    }
}
