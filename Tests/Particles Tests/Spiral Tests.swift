import Numeric
import Particles
import Testing

extension `Particles Tests` {
    @Suite
    struct `A spiral turns and winds what it holds in polar form` {}
}

extension `Particles Tests`.`A spiral turns and winds what it holds in polar form` {
    typealias Tests = `Particles Tests`

    static let spiral = Particles.Spiral(arms: 3, inner: 0.4, reach: 5, concentration: 1.3, winding: Radian(2.5), width: 0.35, stray: 0.15, thickness: 0.3)

    static func polars() -> [(Particles.Draws, Particles.Spiral.Polar)] {
        Tests.population.particles.map { particle in
            let draws = Tests.population.draws(of: particle)
            return (draws, spiral.polar(draws))
        }
    }

    @Test
    func `Unturned and unwound, a polar form is its home, and it is the home's place in polar coordinates`() {
        for (draws, polar) in Self.polars() {
            let home = Self.spiral.home(draws).place
            #expect(Self.spiral.place(of: polar) == home)
            #expect(abs((home.x * home.x + home.y * home.y).squareRoot() - polar.distance) < 1e-12)
            #expect(home.z == polar.height)
            let angle = Self.spiral.angle(of: polar)
            let off = Double.atan2(home.y, home.x) - angle
            #expect(abs(off - 2 * Double.pi * (off / (2 * Double.pi)).rounded()) < 1e-9)
            #expect(polar.arm.rawValue < 3)
            #expect(abs(polar.aside) <= Double.pi)
        }
    }

    @Test
    func `A particle on an arm lies within the arm's width across it`() {
        let onArms = Particles.Spiral(arms: 2, inner: 0.4, reach: 5, winding: Radian(3), width: 0.35)
        for particle in Tests.population.particles {
            let polar = onArms.polar(Tests.population.draws(of: particle))
            #expect(abs(polar.aside) * Swift.max(polar.distance, 0.35) <= 0.35 + 1e-12)
        }
    }

    @Test
    func `A full turn brings every place back, and a wound leaves the inner radius and turns the reach by itself`() {
        let full = Radian(2 * Double.pi)
        for (_, polar) in Self.polars().prefix(200) {
            let home = Self.spiral.place(of: polar)
            let turned = Self.spiral.place(of: polar, turned: full)
            #expect(Tests.distance(turned, home) < 1e-12)
            let wound = Self.spiral.place(of: polar, turned: Radian(0.4), wound: Radian(1.1))
            #expect(abs(Tests.length(wound.x, wound.y, 0) - polar.distance) < 1e-12 && wound.z == polar.height)
        }
        let inner = Particles.Spiral.Polar(distance: 0.4, arm: 1, aside: 0.05, height: 0)
        #expect(Self.spiral.angle(of: inner, wound: Radian(1.1)) == Self.spiral.angle(of: inner))
        let rim = Particles.Spiral.Polar(distance: 5, arm: 2, aside: -0.02, height: 0)
        #expect(abs(Self.spiral.angle(of: rim, wound: Radian(1.1)) - Self.spiral.angle(of: rim) - 1.1) < 1e-12)
        #expect(abs(Self.spiral.angle(of: rim, turned: Radian(0.7)) - Self.spiral.angle(of: rim) - 0.7) < 1e-12)
        #expect(abs(Self.spiral.angle(of: rim, wound: Radian(-2.5)) - (Self.spiral.direction(of: 2) - 0.02)) < 1e-12)
    }
}
