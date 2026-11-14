import Particles
import Picture_CPU
import Standard_Library_Extensions
import Synchronization
import Testing

extension `Particles Tests` {
    @Suite
    struct `Light and cards are descriptions, drawn by the renderer that draws them` {}
}

extension `Particles Tests`.`Light and cards are descriptions, drawn by the renderer that draws them` {
    static func at(_ x: Double, _ y: Double) -> Picture.Plane.Point<2> { .init([x, y]) }

    static let frame = Picture.Plane.Rectangle(llx: 0, lly: 0, urx: 120, ury: 80)

    static func mote(_ index: Int) -> Particles.Mote {
        let t = Double(index)
        return Particles.Mote(
            position: at(7.3 + (t * 37.1).truncatingRemainder(dividingBy: 104), 5.9 + (t * 23.7).truncatingRemainder(dividingBy: 70)),
            radius: 0.4 + (t * 0.37).truncatingRemainder(dividingBy: 3),
            color: Picture.Color(red: 1, green: Float(0.3 + (t * 0.13).truncatingRemainder(dividingBy: 0.7)), blue: 0.4),
            strength: 0.5 + (t * 0.21).truncatingRemainder(dividingBy: 1.5),
            blur: (t * 0.31).truncatingRemainder(dividingBy: 2)
        )
    }

    static var light: Particles.Light {
        var light = Particles.Light(frame: frame, scale: 1.5)
        (0..<40).map(mote).forEach { light.add($0) }
        light.add(
            trail: (0..<6).map { step in
                var mote = mote(50)
                mote.position = at(20 + Double(step) * 9.5, 30 + Double(step) * 3.25)
                return mote
            },
            persistence: 0.5
        )
        light.add(trail: [mote(51), mote(52), mote(53), mote(54)])
        var other = Particles.Light(frame: frame, scale: 1.5, footprint: 2)
        (60..<70).map(mote).forEach { other.add($0) }
        do throws(Particles.Light.Error) {
            try light.add(other)
        } catch {
            preconditionFailure("the other light covers the same rectangle at the same scale")
        }
        return light
    }

    static var cards: Particles.Cards {
        var cards = Particles.Cards(frame: frame)
        for (index, t) in (0..<12).map(Double.init).enumerated() {
            let (x, y) = (9 - t * 0.5, t * 0.8)
            cards.add(
                Particles.Card(
                    center: at(10 + (t * 31.3).truncatingRemainder(dividingBy: 100), 8 + (t * 17.9).truncatingRemainder(dividingBy: 64)),
                    across: Vector(x: x, y: y),
                    along: Vector(x: -y * 0.45, y: x * 0.45),
                    cut: index.isMultiple(of: 3) ? .ellipse : .rectangle,
                    color: Picture.Color(red: Float(0.2 + (t * 0.17).truncatingRemainder(dividingBy: 0.8)), green: 0.5, blue: 0.9),
                    brightness: 0.6 + (t * 0.03),
                    blur: (t * 0.4).truncatingRemainder(dividingBy: 2),
                    distance: (t * 7.7).truncatingRemainder(dividingBy: 10)
                )
            )
        }
        return cards
    }

    /// FNV-1a of every component's bits, in row order.
    static func digest(_ raster: Raster<Picture.Pixel>) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for pixel in raster.pixels {
            for component in [pixel.color.red, pixel.color.green, pixel.color.blue, pixel.alpha] {
                let bits = component.bitPattern
                for byte in [bits & 0xff, bits >> 8 & 0xff, bits >> 16 & 0xff, bits >> 24] {
                    hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3
                }
            }
        }
        return hash
    }

    static func drawn(_ picture: Picture, threads: Cardinal) throws -> Raster<Picture.Pixel> {
        var raster = Raster<Picture.Pixel>(width: 120, height: 80, repeating: Picture.Color(red: 0.05, green: 0.05, blue: 0.1).pixel)
        try Picture.Renderer.cpu(threads: threads).render(picture, into: &raster)
        return raster
    }

    /// The digests of what was drawn before light and cards were descriptions.
    static let recorded: [String: UInt64] = [
        "bloomed": 8_711_241_658_518_571_594, "cards": 7_760_281_650_374_821_177, "cards drawn": 2_761_873_846_558_930_950,
        "light": 13_717_172_556_423_884_762, "light drawn": 17_933_981_487_474_538_351,
    ]

    @Test
    func `Light and cards draw the pixels they drew before they were descriptions`() throws {
        let light = Self.light
        let cards = Self.cards
        let drawn: [String: UInt64] = [
            "light": Self.digest(light.raster),
            "light drawn": Self.digest(try Self.drawn([light.element], threads: 1)),
            "cards": Self.digest(cards.raster),
            "cards drawn": Self.digest(try Self.drawn([cards.element], threads: 1)),
            "bloomed": Self.digest(try Self.drawn(Picture([cards.element, light.element]).bloom(in: Self.frame, deviation: 4), threads: 1)),
        ]
        #expect(drawn == Self.recorded, "\(drawn.sorted { $0.key < $1.key })")
    }

    @Test
    func `An element of light or cards names them and holds no pixels, and equal ones are equal and hash alike`() {
        let (light, other) = (Self.light, Self.light)
        var moved = Self.light
        moved.add(Self.mote(99))
        #expect(light == other && light.hashValue == other.hashValue && light != moved)
        #expect(light.element == other.element && light.element.hashValue == other.element.hashValue)
        #expect(light.element != moved.element)
        #expect(light.image.raster.isEmpty)
        #expect(light.image.source?.drawing(as: Particles.Light.self) == light)
        let (cards, again) = (Self.cards, Self.cards)
        #expect(cards.element == again.element && cards.element.hashValue == again.element.hashValue)
        #expect(cards.image.raster.isEmpty)
        #expect(cards.image.source?.drawing(as: Particles.Cards.self) == cards)
    }

    @Test(arguments: [1, 3, 8] as [Cardinal])
    func `A renderer draws a light's element as the image of its raster, bit for bit`(threads: Cardinal) throws {
        let light = Self.light
        let held = Picture.Image(light.raster, placement: Picture.Transform(rows: [[1 / 1.5, 0, 0], [0, 1 / 1.5, 0]]))
        let element = Picture.Element.layer(Picture.Layer([.fill(Self.area, .image(held))], operator: .lighter))
        #expect(try Self.drawn([light.element], threads: threads) == Self.drawn([element], threads: threads))
        let cards = Self.cards
        let laid = Picture.Element.fill(Self.area, .image(Picture.Image(cards.raster)))
        #expect(try Self.drawn([cards.element], threads: threads) == Self.drawn([laid], threads: threads))
    }

    /// How many times a light was drawn.
    final class Count: Sendable {
        let drawn = Mutex(0)
    }

    /// A light that counts how often it is drawn.
    struct Counted: Picture.Image.Drawing {
        let light: Particles.Light
        let count: Count

        static func == (first: Self, second: Self) -> Bool { first.light == second.light }

        func hash(into hasher: inout Hasher) { hasher.combine(light) }

        func raster(through renderer: Picture.Renderer) throws(Picture.Renderer.Error) -> Raster<Picture.Pixel> {
            count.drawn.withLock { $0 += 1 }
            return try light.raster(through: renderer)
        }
    }

    /// Three images of one counted light, placed apart.
    static func counted(_ count: Count) -> Picture {
        let placements = [0.0, 1, 2].map { shift in Picture.Transform(rows: [[1 / 1.5, 0, shift], [0, 1 / 1.5, 0]]) }
        return Picture(placements.map { placement in Picture.Element.fill(area, .image(Picture.Image(Counted(light: light, count: count), placement: placement))) })
    }

    @Test(arguments: [1, 3, 8] as [Cardinal])
    func `Building light draws nothing, and a renderer drawing it twice draws it once`(threads: Cardinal) throws {
        let count = Count()
        let picture = Self.counted(count)
        #expect(picture == Self.counted(count))
        #expect(count.drawn.withLock { $0 } == 0)
        let renderer = Picture.Renderer.cpu(threads: threads)
        var raster = Raster<Picture.Pixel>(width: 120, height: 80, repeating: .transparent)
        try renderer.render(picture, into: &raster)
        try renderer.render(picture, into: &raster)
        #expect(count.drawn.withLock { $0 } == 1)
    }

    @Test
    func `Every stored property of a light and a mote is written, and lights that differ are written apart`() throws {
        let labels = { (value: Any) in Mirror(reflecting: value).children.map { $0.label ?? "" } }
        #expect(labels(Self.light) == ["frame", "scale", "footprint", "width", "height", "additions"])
        #expect(labels(Self.mote(0)) == ["position", "radius", "color", "strength", "blur"])
        var moved = Self.light
        moved.add(Self.mote(99))
        var trailed = Self.light
        trailed.add(trail: [Self.mote(1), Self.mote(2)], persistence: 0.25)
        let lights = [Self.light, moved, trailed, Particles.Light(frame: Self.frame), Particles.Light(frame: Self.frame, scale: 2)]
        let bytes = try lights.map { try #require(Mirror.bytes(of: Picture([$0.element]))) }
        #expect(Set(bytes).count == lights.count)
        #expect(Mirror.bytes(of: Picture([Self.light.element])) == bytes[0])
    }

    /// The light's and the cards' rectangle.
    static var area: Picture.Plane.Path {
        let corners: [Picture.Plane.Point<2>] = [at(0, 0), at(120, 0), at(120, 80), at(0, 80)]
        let sides = zip(corners, corners.dropFirst() + corners.prefix(1)).map { Picture.Plane.Path.Segment.line(.init(start: $0, end: $1)) }
        return Picture.Plane.Path(subpaths: [.init(startPoint: corners[0], segments: sides, isClosed: true)])
    }
}
