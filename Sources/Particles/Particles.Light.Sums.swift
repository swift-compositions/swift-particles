import Numeric
import Picture

extension Particles.Light {
    /// A light being drawn: the sums of its pixels, premultiplied red, green, blue and alpha, row by row, and the
    /// weights of the footprint being spread, kept between footprints so that they are not made anew.
    struct Sums {
        let light: Particles.Light
        var values: [SIMD4<Float>]
        var scratch: [Double]

        init(_ light: Particles.Light) {
            self.light = light
            self.values = Array(repeating: .zero, count: Int(clamping: light.width) * Int(clamping: light.height))
            self.scratch = []
        }
    }
}

extension Particles.Light.Sums {
    var scale: Double { light.scale }
    var footprint: Double { light.footprint }
    var width: Cardinal { light.width }
    var height: Cardinal { light.height }

    func total(of mote: Particles.Mote) -> SIMD4<Float> { light.total(of: mote) }
    func pixel(of position: Picture.Plane.Point<2>) -> (x: Double, y: Double) { light.pixel(of: position) }
    func gain(of trail: [Particles.Mote], persistence: Double) -> Double { light.gain(of: trail, persistence: persistence) }
}

extension Particles.Light {
    /// The light drawn: every addition spread in the order it was added.
    var sums: [SIMD4<Float>] {
        var sums = Sums(self)
        for addition in additions {
            switch addition {
            case .mote(let mote): sums.add(mote)
            case .trail(let motes, let persistence): sums.add(trail: motes, persistence: persistence)
            case .light(let other): sums.values = zip(sums.values, other.sums).map { $0 + $1 }
            }
        }
        return sums.values
    }
}

extension Particles.Light.Sums {
    /// Spreads a mote's light at its position.
    mutating func add(_ mote: Particles.Mote) {
        let total = total(of: mote)
        guard total != .zero else { return }
        let at = pixel(of: mote.position)
        point(x: at.x, y: at.y, radius: Swift.max(mote.spread * scale, footprint), total: total)
    }

    /// Spreads the light of a trail, as `Particles.Light.add(trail:persistence:)` describes it.
    mutating func add(trail motes: [Particles.Mote], persistence: Double) {
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
        values.withUnsafeMutableBufferPointer { pixels in
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
