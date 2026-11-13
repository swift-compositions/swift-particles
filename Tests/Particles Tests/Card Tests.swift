import Numeric
import Particles
import Testing

extension `Particles Tests` {
    @Suite
    struct `Cards are paper laid far to near` {}
}

extension `Particles Tests`.`Cards are paper laid far to near` {
    typealias Tests = `Particles Tests`

    static let frame = Tests.rectangle(0, 0, 100, 100)
    static let red = Picture.Color(red: 1, green: 0, blue: 0)
    static let blue = Picture.Color(red: 0, green: 0, blue: 1)

    static func coverage(_ cards: Particles.Cards) -> Double {
        cards.raster.pixels.reduce(0) { $0 + Double($1.alpha) }
    }

    @Test
    func `A card covers its area, sharp or blurred, turned or not`() {
        for blur in [0.0, 2.0, 7.0] {
            for cut in Particles.Card.Cut.allCases {
                var cards = Particles.Cards(frame: Self.frame)
                let (c, s) = (Double.cos(0.4), Double.sin(0.4))
                cards.add(Particles.Card(center: Tests.at(50.3, 49.6), across: Vector(x: 12 * c, y: 12 * s), along: Vector(x: -5 * s, y: 5 * c), cut: cut, color: Self.red, blur: blur))
                let area = cut == .rectangle ? 4 * 12 * 5.0 : Double.pi * 12 * 5
                #expect(abs(Self.coverage(cards) - area) < (cut == .rectangle ? 0.01 : 0.06) * area)
            }
        }
    }

    @Test
    func `A nearer card hides a farther one, whatever order they were added in`() {
        let far = Particles.Card(center: Tests.at(50, 50), across: Vector(x: 20, y: 0), along: Vector(x: 0, y: 20), color: Self.blue, distance: 9)
        let near = Particles.Card(center: Tests.at(50, 50), across: Vector(x: 10, y: 0), along: Vector(x: 0, y: 10), color: Self.red, distance: 4)
        for order in [[far, near], [near, far]] {
            var cards = Particles.Cards(frame: Self.frame)
            order.forEach { cards.add($0) }
            let middle = cards.raster[x: 50, y: 50]
            #expect(middle.color.red == 1 && middle.color.blue == 0 && middle.alpha == 1)
            #expect(cards.raster[x: 35, y: 50].color.blue == 1)
        }
    }

    @Test
    func `A piece turned edge-on to the eye is thin, and it is lit by how squarely it faces`() throws {
        let view = Particles.View(camera: try Tests.camera(), viewport: Tests.rectangle(0, 0, 1920, 1080))
        let place = Point<3, Double>(x: 0.3, y: -0.2, z: 0)
        let facing = Particles.Pose(place: place, across: Vector(x: 1, y: 0, z: 0), along: Vector(x: 0, y: 1, z: 0))
        let edge = Particles.Pose(place: place, across: Vector(x: 1, y: 0, z: 0), along: Vector(x: 0, y: 0, z: 1))
        let square = try #require(Particles.Card(facing, width: 1, height: 1, color: Self.red, shade: 0.5, through: view))
        let thin = try #require(Particles.Card(edge, width: 1, height: 1, color: Self.red, shade: 0.5, through: view))
        #expect(abs(square.brightness - 1) < 1e-3)
        #expect(thin.brightness < 0.52)
        let area = { (card: Particles.Card) in abs(card.across.x * card.along.y - card.across.y * card.along.x) }
        #expect(area(thin) < 0.05 * area(square))
    }

    @Test
    func `A piece glints where its normal halves the way between the light and the eye, from either side`() {
        let sheen = Particles.Sheen(toward: Vector(x: 0, y: 1, z: 1), sharpness: 30, strength: 0.9)
        let tilted = Vector<3, Double>(x: 0, y: Double.sin(Double.pi / 8), z: Double.cos(Double.pi / 8))
        let back = Vector<3, Double>(x: -tilted.x, y: -tilted.y, z: -tilted.z)
        #expect(abs(sheen.glint(normal: tilted) - 0.9) < 1e-9)
        #expect(sheen.glint(normal: back) == sheen.glint(normal: tilted))
        #expect(sheen.glint(normal: Vector(x: 0, y: 0, z: 1)) < 0.1)
        #expect(sheen.glint(normal: Vector(x: 1, y: 0, z: 0)) == 0)
    }

    @Test
    func `A piece without a sheen does not glint, and a full glint is the light's colour`() throws {
        let view = Particles.View(camera: try Tests.camera(), viewport: Tests.rectangle(0, 0, 1920, 1080))
        let pose = Particles.Pose(place: Point(x: 0.3, y: -0.2, z: 0), across: Vector(x: 1, y: 0, z: 0), along: Vector(x: 0, y: 1, z: 0))
        let plain = try #require(Particles.Card(pose, width: 1, height: 1, color: Self.red, through: view))
        #expect(plain.glint == 0)
        let eye = Particles.Sheen(toward: Vector(x: 0, y: 0, z: 1), sharpness: 1, strength: 1, color: Self.blue)
        let lit = try #require(Particles.Card(pose, width: 1, height: 1, color: Self.red, sheen: eye, through: view))
        #expect(lit.glint > 0.99)
        #expect(lit.shine == Self.blue)
        var cards = Particles.Cards(frame: Self.frame)
        cards.add(Particles.Card(center: Tests.at(50, 50), across: Vector(x: 10, y: 0), along: Vector(x: 0, y: 10), color: Self.red, glint: 1, shine: Self.blue))
        let middle = cards.raster[x: 50, y: 50]
        #expect(middle.color.red == 0 && middle.color.blue == 1 && middle.alpha == 1)
        var half = Particles.Cards(frame: Self.frame)
        half.add(Particles.Card(center: Tests.at(50, 50), across: Vector(x: 10, y: 0), along: Vector(x: 0, y: 10), color: Self.red.faded(by: 0.5), glint: 1, shine: Self.blue))
        #expect(abs(half.raster[x: 50, y: 50].color.blue - 0.5) < 1e-6)
    }

    @Test
    func `A card is drawn within its extent, and the disc of its reach holds that extent`() {
        let frame = Tests.rectangle(-40, -40, 180, 180)
        for scale in [1.0, 2.5] {
            for (index, particle) in Tests.population.particles.prefix(60).enumerated() {
                let draws = Tests.population.draws(of: particle)
                let angle = 2 * Double.pi * draws[0]
                let skew = 0.6 * (draws[1] - 0.5)
                let (c, s) = (Double.cos(angle), Double.sin(angle))
                let (u, v) = (Double.cos(angle + Double.pi / 2 + skew), Double.sin(angle + Double.pi / 2 + skew))
                let card = Particles.Card(
                    center: Tests.at(10 + 80 * draws[2], 10 + 80 * draws[3]),
                    across: Vector(x: 14 * draws[4] * c, y: 14 * draws[4] * s),
                    along: Vector(x: 9 * draws[5] * u, y: 9 * draws[5] * v),
                    cut: index % 2 == 0 ? .rectangle : .ellipse,
                    color: Self.red,
                    blur: 4 * draws[6] * draws[6]
                )
                var cards = Particles.Cards(frame: frame, scale: scale)
                cards.add(card)
                let extent = card.extent(scale: scale)
                let raster = cards.raster
                for row in 0..<Int(raster.height.rawValue) {
                    for column in 0..<Int(raster.width.rawValue) where raster[x: Ordinal(UInt(column)), y: Ordinal(UInt(row))].alpha > 0 {
                        let (x, y) = (-40 + (Double(column) + 0.5) / scale, -40 + (Double(row) + 0.5) / scale)
                        #expect(x >= extent.llx.underlying && x <= extent.urx.underlying && y >= extent.lly.underlying && y <= extent.ury.underlying)
                    }
                }
                let corner = Tests.at(extent.urx.underlying, extent.ury.underlying)
                let (dx, dy) = (corner[0] - card.center[0], corner[1] - card.center[1])
                #expect(abs((dx * dx + dy * dy).squareRoot() - card.reach(scale: scale)) < 1e-9)
                if card.cut == .rectangle {
                    let area = 4 * abs(card.across.x * card.along.y - card.across.y * card.along.x)
                    #expect(abs(Self.coverage(cards) / (scale * scale) - area) < 0.01 * area + 1e-6)
                }
            }
        }
    }

    @Test
    func `A faded card fades its paper and its glint alike`() {
        let card = Particles.Card(center: Tests.at(50, 50), across: Vector(x: 10, y: 0), along: Vector(x: 0, y: 10), color: Self.red, glint: 0.5, shine: Self.blue)
        #expect(card.faded(by: 1) == card)
        var cards = Particles.Cards(frame: Self.frame)
        cards.add(card.faded(by: 0.25))
        var whole = Particles.Cards(frame: Self.frame)
        whole.add(card)
        let (faded, full) = (cards.raster[x: 50, y: 50], whole.raster[x: 50, y: 50])
        #expect(abs(faded.alpha - 0.25) < 1e-6)
        #expect(abs(faded.color.red - 0.25 * full.color.red) < 1e-6 && abs(faded.color.blue - 0.25 * full.color.blue) < 1e-6)
    }
}
