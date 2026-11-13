import Particles
import Testing

enum `Particles Tests` {}

extension `Particles Tests` {
    static let population = Particles.Population(seed: Threefry.Key(11, 29), count: 2000)

    static func seconds(_ thousandths: Int) -> Rational {
        do throws(Rational.Error) {
            return try Rational(numerator: Integer(thousandths), denominator: 1000)
        } catch {
            preconditionFailure("a thousandth has a denominator")
        }
    }

    static func length(_ x: Double, _ y: Double, _ z: Double) -> Double {
        (x * x + y * y + z * z).squareRoot()
    }

    static func distance(_ a: Point<3, Double>, _ b: Point<3, Double>) -> Double {
        length(a.x - b.x, a.y - b.y, a.z - b.z)
    }

    static func rectangle(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Picture.Plane.Rectangle {
        Picture.Plane.Rectangle(llx: .init(x), lly: .init(y), urx: .init(x + width), ury: .init(y + height))
    }

    static func at(_ x: Double, _ y: Double) -> Picture.Plane.Point<2> { .init([x, y]) }

    static func camera() throws -> Picture.Scene.Camera {
        try Picture.Scene.Camera(
            projection: .perspective(fieldOfView: Radian(0.6), aspect: 16 / 9, near: 0.5, far: 100, depth: .unit),
            at: Point(x: 0.3, y: -0.2, z: 9),
            yaw: Radian(0.05),
            pitch: Radian(-0.03)
        )
    }
}
