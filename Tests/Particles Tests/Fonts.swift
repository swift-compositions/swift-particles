import Particles

/// A font of two glyphs of straight contours, "A" a triangle and "V" a wedge, made in memory.
enum Fonts {
    static func be16(_ value: Int) -> [UInt8] {
        [UInt8(truncatingIfNeeded: value >> 8), UInt8(truncatingIfNeeded: value)]
    }

    static func glyph(_ contours: [[(x: Int, y: Int)]]) -> [UInt8] {
        guard !contours.isEmpty else { return [] }
        let points = contours.flatMap { $0 }
        var ends: [UInt8] = []
        var last = -1
        contours.forEach { contour in
            last += contour.count
            ends += be16(last)
        }
        var xs: [UInt8] = []
        var ys: [UInt8] = []
        var previous = (x: 0, y: 0)
        points.forEach { point in
            xs += be16(point.x - previous.x)
            ys += be16(point.y - previous.y)
            previous = point
        }
        let header = be16(contours.count) + be16(0) + be16(0) + be16(0) + be16(0)
        return header + ends + be16(0) + points.map { _ in 1 } + xs + ys
    }

    static func font() -> ISO_14496_22.FontFile {
        let glyphs = [
            glyph([[(0, 0), (400, 0), (400, 700), (0, 700)]]),
            glyph([[(0, 0), (500, 0), (250, 700)]]),
            glyph([[(0, 700), (250, 0), (500, 700)]]),
        ]
        let advances: [UInt16] = [500, 600, 600]
        let offsets = glyphs.reduce(into: [UInt32(0)]) { $0.append(($0.last ?? 0) + UInt32($1.count)) }
        return ISO_14496_22.FontFile(
            data: [],
            head: ISO_14496_22.HeadTable(unitsPerEm: 1000),
            hhea: ISO_14496_22.HheaTable(ascender: 800, descender: -200, lineGap: 100, advanceWidthMax: 600, numberOfHMetrics: 3),
            hmtx: ISO_14496_22.HmtxTable(
                hMetrics: advances.map { ISO_14496_22.LongHorMetric(advanceWidth: $0, leftSideBearing: 0) },
                leftSideBearings: [],
                numberOfHMetrics: 3
            ),
            maxp: ISO_14496_22.MaxpTable(numGlyphs: 3),
            cmap: ISO_14496_22.CmapTable(version: 0, encodingRecords: [], unicodeMapping: [0x41: 1, 0x56: 2]),
            name: ISO_14496_22.NameTable(format: 0, nameRecords: [], strings: [:]),
            post: ISO_14496_22.PostTable(
                version: ISO_14496_22.Fixed(integer: 3, fraction: 0),
                italicAngle: 0,
                underlinePosition: -100,
                underlineThickness: 50,
                isFixedPitch: false
            ),
            loca: ISO_14496_22.LocaTable(offsets: offsets),
            glyf: ISO_14496_22.GlyfTable(data: glyphs.flatMap { $0 }.map(Byte.init(_:)), tableOffset: 0),
            kern: nil
        )
    }
}
