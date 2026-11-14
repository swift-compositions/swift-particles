@testable import Particles
import Testing

extension `Particles Tests` {
    @Suite
    struct `A swept disc spreads the same bits as the plain spreading` {}
}

extension `Particles Tests`.`A swept disc spreads the same bits as the plain spreading` {
    typealias Tests = `Particles Tests`

    /// The swept disc as it was first written: every weight appended to a growing array, read back by subscript.
    static func line(
        into values: inout [SIMD4<Float>],
        width: Int,
        height: Int,
        from start: (x: Double, y: Double),
        to end: (x: Double, y: Double),
        radius: Double,
        total: SIMD4<Float>
    ) {
        let (across, down) = (end.x - start.x, end.y - start.y)
        let length = (across * across + down * down).squareRoot()
        guard length.isFinite, start.x.isFinite, start.y.isFinite, radius.isFinite else { return }
        guard length > 1e-6 else {
            guard start.x.isFinite, start.y.isFinite, radius.isFinite else { return }
            let (x, y) = (start.x, start.y)
            let inverse = 1 / (radius * radius)
            let columns = (low: Int((x - radius - 0.5).rounded(.down)) + 1, high: Int((x + radius - 0.5).rounded(.up)) - 1)
            return deposit(
                into: &values,
                width: width,
                height: height,
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
        let direction = (x: across / length, y: down / length)
        let square = radius * radius
        let quartic = square * square
        deposit(
            into: &values,
            width: width,
            height: height,
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

    static func deposit(
        into values: inout [SIMD4<Float>],
        width: Int,
        height: Int,
        rows: (low: Int, high: Int),
        columns: (Int) -> (low: Int, high: Int),
        weight: (Int, Int) -> Double,
        total: SIMD4<Float>
    ) {
        guard rows.high >= 0, rows.low < height, rows.low <= rows.high else { return }
        var weights: [Double] = []
        var sum = 0.0
        for row in rows.low...rows.high {
            let span = columns(row)
            var column = span.low
            while column <= span.high {
                let part = weight(column, row)
                weights.append(part)
                sum += part
                column += 1
            }
        }
        guard sum > 0 else { return }
        let share = 1 / sum
        var index = 0
        for row in rows.low...rows.high {
            let span = columns(row)
            guard span.low <= span.high else { continue }
            if row >= 0, row < height {
                var column = Swift.max(span.low, 0)
                while column <= Swift.min(span.high, width - 1) {
                    let part = weights[index + column - span.low]
                    if part > 0 { values[row * width + column] += total * Float(part * share) }
                    column += 1
                }
            }
            index += span.high - span.low + 1
        }
    }

    @Test
    func `Lines across, along, outside and at the edges of the raster, one after another`() {
        let light = Particles.Light(frame: Tests.rectangle(0, 0, 120, 80))
        var sums = Particles.Light.Sums(light)
        var plain = sums.values
        let pieces: [(start: (x: Double, y: Double), end: (x: Double, y: Double), radius: Double)] = [
            ((10.3, 12.7), (54.9, 31.2), 1.25),
            ((60, 40.5), (90, 40.5), 3.5),
            ((33.25, 5), (33.25, 70), 2),
            ((-8, -6), (14.2, 9.9), 6.75),
            ((110.6, 75.1), (131, 88), 4.2),
            ((200, 200), (240, 260), 3),
            ((50.5, 50.5), (50.5 + 1e-8, 50.5), 2.4),
            ((0, 0), (0.1, 0.03), 1),
            ((119.9, 0.2), (0.4, 79.8), 9.5),
            ((70.123, 20.987), (70.623, 21.287), 1.25),
        ]
        for (index, piece) in pieces.enumerated() {
            let total = SIMD4<Float>(0.9, 0.55, 0.25, 0.8) * Float(index + 1)
            sums.line(from: piece.start, to: piece.end, radius: piece.radius, total: total)
            Self.line(
                into: &plain,
                width: 120,
                height: 80,
                from: piece.start,
                to: piece.end,
                radius: piece.radius,
                total: total
            )
        }
        #expect(sums.values.count == plain.count)
        var differ = 0
        for (fast, reference) in zip(sums.values, plain) {
            for lane in 0..<4 where fast[lane].bitPattern != reference[lane].bitPattern { differ += 1 }
        }
        #expect(differ == 0)
        #expect(plain.contains { $0 != .zero })
    }
}
