import Numeric
import Particles
import Testing

extension `Particles Tests` {
    @Suite
    struct `A view sees a place as its camera does` {}
}

extension `Particles Tests`.`A view sees a place as its camera does` {
    typealias Tests = `Particles Tests`

    static let viewport = Tests.rectangle(0, 0, 1920, 1080)

    @Test
    func `Position and distance are the camera's sight, bit for bit`() throws {
        let camera = try Tests.camera()
        let model = Matrix<4, 4, Double>.rotation(aboutX: -0.8)
        let view = Particles.View(camera: camera, viewport: Self.viewport, model: model)
        for particle in Tests.population.particles.prefix(300) {
            let place = Particles.Box(center: Point(x: 0, y: 0, z: 0), size: Vector(x: 8, y: 8, z: 8)).home(Tests.population.draws(of: particle)).place
            let sight = try #require(view.sight(of: place))
            let camera = try #require(camera.sight(of: place, in: model, viewport: Self.viewport))
            #expect(sight.position == camera.position.point)
            #expect(sight.depth == camera.position.depth)
            #expect(sight.distance == camera.distance)
        }
        #expect(view.sight(of: Point(x: 0.3, y: -0.2, z: 20)) == nil)
    }

    @Test
    func `Scale is how many picture units a unit across the line of sight spans, falling with distance`() throws {
        let camera = try Picture.Scene.Camera(
            projection: .perspective(fieldOfView: Radian(0.6), aspect: 16 / 9, near: 0.5, far: 100, depth: .unit),
            at: Point(x: 0, y: 0, z: 0)
        )
        let view = Particles.View(camera: camera, viewport: Self.viewport)
        for distance in [2.0, 5.0, 30.0] {
            let middle = try #require(view.sight(of: Point(x: 0, y: 0, z: -distance)))
            let above = try #require(view.sight(of: Point(x: 0, y: 0.01, z: -distance)))
            #expect(abs((middle.position[1] - above.position[1]) / 0.01 - middle.scale) < 1e-6 * middle.scale)
            #expect(abs(middle.scale * distance - 540 / Double.tan(0.3)) < 1e-6)
        }
    }

    @Test
    func `A focus blurs by the circle of confusion, nothing at its distance`() throws {
        let focus = Particles.Focus(distance: 10, aperture: 8)
        #expect(focus.blur(at: 10) == 0)
        #expect(focus.blur(at: 20) == 4)
        #expect(focus.blur(at: 5) == 8)
        let view = Particles.View(camera: try Tests.camera(), viewport: Self.viewport, focus: focus)
        let sight = try #require(view.sight(of: Point(x: 0, y: 0, z: -11)))
        #expect(sight.blur == focus.blur(at: sight.distance))
    }

    @Test
    func `A clearance fades to its floor inside and to nothing beyond its feather`() {
        let clearance = Particles.Clearance(region: Tests.rectangle(100, 100, 200, 50), floor: 0.1, feather: 40)
        #expect(clearance.opacity(at: Tests.at(150, 120)) == 0.1)
        #expect(clearance.opacity(at: Tests.at(350, 120)) == 1)
        #expect(clearance.opacity(at: Tests.at(320, 120)) == 0.1 + 0.9 * 0.5)
        #expect(clearance.opacity(at: Tests.at(330, 120), extent: 30) == 0.1)
        let shares = stride(from: 300.0, through: 345, by: 1).map { clearance.opacity(at: Tests.at($0, 120)) }
        #expect(zip(shares, shares.dropFirst()).allSatisfy { $0 <= $1 })
        #expect(Particles.Clearance.opacity(at: Tests.at(150, 120), among: [clearance, clearance]) == 0.1)
        #expect(Particles.Clearance.opacity(at: Tests.at(150, 120), among: [Particles.Clearance]()) == 1)
    }
}
