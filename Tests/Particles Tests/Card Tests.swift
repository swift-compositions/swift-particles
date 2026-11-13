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
}
