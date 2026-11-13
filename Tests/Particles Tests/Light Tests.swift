import Particles
import Picture_CPU
import Testing

extension `Particles Tests` {
    @Suite
    struct `Light adds every mote's whole light` {}
}

extension `Particles Tests`.`Light adds every mote's whole light` {
    typealias Tests = `Particles Tests`

    static let frame = Tests.rectangle(0, 0, 120, 80)
    static let color = Picture.Color(red: 1, green: 0.6, blue: 0.3)

    static func close(_ a: SIMD4<Float>, _ b: SIMD4<Float>, within tolerance: Float = 1e-4) -> Bool {
        let scale = Swift.max(abs(b.x), abs(b.y), abs(b.z), abs(b.w), 1e-6)
        return abs(a.x - b.x) <= tolerance * scale && abs(a.y - b.y) <= tolerance * scale
            && abs(a.z - b.z) <= tolerance * scale && abs(a.w - b.w) <= tolerance * scale
    }

    @Test
    func `A mote adds its whole light wherever it falls between pixel centres, of any size`() {
        for radius in [0.2, 0.7, 1.5, 6.0] {
            let mote = Particles.Mote(position: Tests.at(40, 30), radius: radius, color: Self.color, strength: 0.8)
            let whole = Particles.Light(frame: Self.frame).total(of: mote)
            for offset in [0.0, 0.13, 0.5, 0.77] {
                var light = Particles.Light(frame: Self.frame)
                var moved = mote
                moved.position = Tests.at(40 + offset, 30 + offset / 3)
                light.add(moved)
                #expect(Self.close(light.sum, whole))
            }
        }
        let mote = Particles.Mote(position: Tests.at(40, 30), radius: 2, color: Self.color)
        let pixel = Self.color.pixel
        let expected = SIMD4<Float>(pixel.color.red, pixel.color.green, pixel.color.blue, pixel.alpha) * Float(Double.pi * 4 / 3)
        #expect(Self.close(Particles.Light(frame: Self.frame).total(of: mote), expected, within: 1e-6))
    }

    @Test
    func `A sharp mote is about as bright at its centre as the sprite it stands for`() {
        var light = Particles.Light(frame: Self.frame)
        light.add(Particles.Mote(position: Tests.at(40.5, 30.5), radius: 8, color: Self.color))
        let center = light.raster[x: 40, y: 30]
        #expect(abs(center.color.red - Self.color.pixel.color.red) < 0.03 * Self.color.pixel.color.red)
    }

    @Test
    func `A blur spreads a mote's light without changing it`() {
        var sharp = Particles.Light(frame: Self.frame)
        var blurred = Particles.Light(frame: Self.frame)
        let mote = Particles.Mote(position: Tests.at(60, 40), radius: 1, color: Self.color)
        sharp.add(mote)
        var wide = mote
        wide.blur = 9
        blurred.add(wide)
        #expect(Self.close(sharp.sum, blurred.sum))
        #expect(blurred.raster[x: 60, y: 40].color.red < sharp.raster[x: 60, y: 40].color.red / 10)
    }

    @Test
    func `A streak spreads the light of its trail along the way and keeps it`() {
        let start = Particles.Mote(position: Tests.at(20.3, 20.1), radius: 1.2, color: Self.color, strength: 1.5)
        for end in [Tests.at(90.7, 61.2), Tests.at(21, 20.1), Tests.at(20.3, 70), Tests.at(100, 20.1)] {
            var finish = start
            finish.position = end
            let trail = (0...6).map { step in
                var mote = start
                let share = Double(step) / 6
                mote.position = Tests.at(start.position[0] + (end[0] - start.position[0]) * share, start.position[1] + (end[1] - start.position[1]) * share)
                return mote
            }
            var streak = Particles.Light(frame: Self.frame)
            streak.add(trail: trail)
            var still = Particles.Light(frame: Self.frame)
            still.add(start)
            #expect(Self.close(streak.sum, still.sum))
        }
    }

    @Test
    func `A long streak shows no dashes along its way`() {
        let start = Particles.Mote(position: Tests.at(10, 40.5), radius: 0.6, color: Self.color)
        var end = start
        end.position = Tests.at(110, 40.5)
        var light = Particles.Light(frame: Self.frame)
        light.add(trail: [start, end])
        let row = (20...100).map { light.raster[x: Ordinal(UInt($0)), y: 40].color.red }
        let mean = row.reduce(0, +) / Float(row.count)
        #expect(row.allSatisfy { abs($0 - mean) < 0.01 * mean })
    }

    @Test
    func `A still particle draws as a point`() {
        let mote = Particles.Mote(position: Tests.at(33.4, 21.9), radius: 1.1, color: Self.color, strength: 0.7, blur: 0.4)
        var point = Particles.Light(frame: Self.frame)
        point.add(mote)
        var trail = Particles.Light(frame: Self.frame)
        trail.add(trail: Array(repeating: mote, count: 6))
        #expect(point.raster == trail.raster)
    }

    @Test
    func `Light is the same raster whatever the renderer's thread count`() throws {
        var light = Particles.Light(frame: Self.frame)
        for particle in Tests.population.particles {
            let draws = Tests.population.draws(of: particle)
            let at = Tests.at(120 * draws[0], 80 * draws[1])
            var end = Particles.Mote(position: at, radius: 0.3 + 2 * draws[2], color: Self.color, strength: 0.2)
            let start = end
            end.position = Tests.at(at[0] + 10 * (draws[3] - 0.5), at[1] + 10 * (draws[4] - 0.5))
            light.add(trail: [start, end])
        }
        let picture: Picture = [light.element]
        let rasters = try [1, 2, 3, 4, 7].map { threads in
            var raster = Raster<Picture.Pixel>(width: 120, height: 80, repeating: Picture.Pixel(color: .init(red: 0.01, green: 0.02, blue: 0.03), alpha: 1))
            try Picture.Renderer.cpu(threads: Cardinal(UInt(threads))).render(picture, into: &raster)
            return raster
        }
        #expect(rasters.allSatisfy { $0 == rasters[0] })
        let lit = rasters[0][x: 60, y: 40]
        #expect(lit.alpha == 1)
    }

    @Test
    func `Light drawn into a picture adds to what is behind`() throws {
        var light = Particles.Light(frame: Self.frame)
        light.add(Particles.Mote(position: Tests.at(60.5, 40.5), radius: 5, color: Self.color))
        let backdrop = Picture.Pixel(color: .init(red: 0.1, green: 0.1, blue: 0.1), alpha: 1)
        var raster = Raster<Picture.Pixel>(width: 120, height: 80, repeating: backdrop)
        try Picture.Renderer.cpu.render([light.element], into: &raster)
        let own = light.raster[x: 60, y: 40]
        let drawn = raster[x: 60, y: 40]
        #expect(abs(drawn.color.red - (0.1 + own.color.red)) < 1e-5)
        #expect(raster[x: 5, y: 5] == backdrop)
    }
}

extension `Particles Tests`.`Light adds every mote's whole light` {
    @Test
    func `Light spread in parts adds up to the light spread at once`() throws {
        let motes = Tests.population.particles.map { particle in
            let draws = Tests.population.draws(of: particle)
            return Particles.Mote(position: Tests.at(120 * draws[0], 80 * draws[1]), radius: 2 * draws[2], color: Self.color)
        }
        var whole = Particles.Light(frame: Self.frame)
        motes.forEach { whole.add($0) }
        var parts = Particles.Light(frame: Self.frame)
        for chunk in stride(from: 0, to: motes.count, by: 300) {
            var part = Particles.Light(frame: Self.frame)
            motes[chunk..<min(chunk + 300, motes.count)].forEach { part.add($0) }
            try parts.add(part)
        }
        #expect(Self.close(parts.sum, whole.sum))
        #expect(throws: Particles.Light.Error.mismatch) { try parts.add(Particles.Light(frame: Tests.rectangle(0, 0, 10, 10))) }
    }
}
