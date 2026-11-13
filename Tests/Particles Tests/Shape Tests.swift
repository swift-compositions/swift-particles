import Numeric
import Particles
import Testing

extension `Particles Tests` {
    @Suite
    struct `Homes lie on their shapes` {}
}

extension `Particles Tests`.`Homes lie on their shapes` {
    typealias Tests = `Particles Tests`

    static func homes(_ shape: some Particles.Shape) -> [Particles.Home] {
        Tests.population.particles.map { shape.home(Tests.population.draws(of: $0)) }
    }

    @Test
    func `A spiral's homes lie between its radii, within its thickness, near an arm unless they stray`() {
        let spiral = Particles.Spiral(arms: 3, inner: 0.5, reach: 4, concentration: 1.5, winding: Radian(3), width: 0.2, stray: 0, thickness: 0.4)
        for home in Self.homes(spiral) {
            let distance = (home.place.x * home.place.x + home.place.y * home.place.y).squareRoot()
            #expect(distance >= 0.5 - 1e-9 && distance <= 4 + 1e-9)
            #expect(abs(home.place.z) <= 0.2 + 1e-12)
            let arm = (Double.atan2(home.place.y, home.place.x) - spiral.turn(at: distance)) / (2 * Double.pi / 3)
            let aside = abs(arm - arm.rounded()) * (2 * Double.pi / 3) * distance
            #expect(aside <= 0.2 + 1e-9)
            #expect(home.normal == Vector(x: 0, y: 0, z: 1))
        }
    }

    @Test
    func `A disc's homes lie in its plane within its radius, a box's within its extent`() {
        let center = Point<3, Double>(x: 1, y: -2, z: 3)
        for home in Self.homes(Particles.Disc(center: center, radius: 2)) {
            #expect(home.place.z == 3)
            #expect(Tests.distance(home.place, center) <= 2 + 1e-12)
        }
        for home in Self.homes(Particles.Box(center: center, size: Vector(x: 2, y: 4, z: 6))) {
            #expect(abs(home.place.x - 1) <= 1 && abs(home.place.y + 2) <= 2 && abs(home.place.z - 3) <= 3)
            #expect(home.normal == nil)
        }
    }

    @Test
    func `A mesh's homes lie on its faces, each with a unit normal`() throws {
        let mesh = Mesh<Point<3, Double>>.box(lower: Point(x: -1, y: -1, z: -1), upper: Point(x: 1, y: 1, z: 1))
        let surface = try #require(Particles.Surface(mesh))
        for home in Self.homes(surface) {
            let (x, y, z) = (abs(home.place.x), abs(home.place.y), abs(home.place.z))
            #expect(abs(max(x, y, z) - 1) < 1e-9)
            let normal = try #require(home.normal)
            #expect(abs(Tests.length(normal.x, normal.y, normal.z) - 1) < 1e-9)
        }
    }

    @Test
    func `A trace's homes lie on its line`() throws {
        let corners: [Picture.Plane.Point<2>] = [Tests.at(0, 0), Tests.at(4, 0), Tests.at(4, 2)]
        let sides = zip(corners, corners.dropFirst()).map { Picture.Plane.Path.Segment.line(.init(start: $0, end: $1)) }
        let path = Picture.Plane.Path(subpaths: [.init(startPoint: corners[0], segments: sides, isClosed: false)])
        let trace = try #require(Particles.Trace(path, tolerance: 0.01))
        #expect(abs(trace.length - 6) < 1e-12)
        let homes = Self.homes(trace)
        for home in homes {
            let (x, y) = (home.place.x, home.place.y)
            let onBottom = abs(y - 1) < 1e-9 && x >= -2 - 1e-9 && x <= 2 + 1e-9
            let onSide = abs(x - 2) < 1e-9 && y >= -1 - 1e-9 && y <= 1 + 1e-9
            #expect(onBottom || onSide)
            #expect(home.place.z == 0)
        }
        let share = Double(homes.filter { abs($0.place.y - 1) < 1e-9 }.count) / Double(homes.count)
        #expect(abs(share - 2.0 / 3.0) < 0.04)
    }

    @Test
    func `A text's homes lie inside its letters`() throws {
        let text = try Picture.Text("AV", font: Fonts.font(), size: 100)
        let points = try #require(Particles.Points(text, spacing: 3))
        let lattice = text.points(spacing: 3)
        let xs = lattice.map { $0[0] }
        let ys = lattice.map { $0[1] }
        let middle = ((xs.min()! + xs.max()!) / 2, (ys.min()! + ys.max()!) / 2)
        for home in Self.homes(points) {
            let point = Tests.at(home.place.x + middle.0, middle.1 - home.place.y)
            #expect(text.path.contains(point, rule: .nonzero))
            #expect(home.normal == Vector(x: 0, y: 0, z: 1))
        }
        #expect(Particles.Points([]) == nil)
    }
}
