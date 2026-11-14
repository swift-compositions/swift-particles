public import Picture
public import Threefry
public import Vector

extension Particles {
    /// A finite set of places, each as likely as any other, such as points spread over the letters of a text.
    public struct Points: Sendable, Hashable {
        /// The places, at least one.
        public let places: [Point<3, Double>]

        /// The normal every home has, if any.
        public let normal: Vector<3, Double>?

        /// Points at places, nil for none.
        public init?(_ places: [Point<3, Double>], normal: Vector<3, Double>? = nil) {
            guard !places.isEmpty else { return nil }
            self.places = places
            self.normal = normal
        }
    }
}

extension Particles.Points {
    /// The letters of a text as points: `Picture.Text.points(spacing:seed:)`, a lattice of cells `spacing`
    /// wide over the text with a point in every cell whose point lies inside a glyph, laid in the world's plane
    /// z = 0 with picture y turned up and the middle of their box at the origin. The normal is +z. Nil when
    /// no cell's point lies inside a glyph.
    public init?(_ text: Picture.Text, spacing: Double, seed: Threefry.Key? = nil) {
        let points = text.points(spacing: spacing, seed: seed)
        let middle = Particles.middle(of: points)
        self.init(points.map { Particles.place(of: $0, around: middle) }, normal: Vector(x: 0, y: 0, z: 1))
    }
}

extension Particles.Points: Particles.Shape {
    /// A particle's home: draw 0 picks one of the places, each with an equal share.
    public func home(_ draws: Particles.Draws) -> Particles.Home {
        let index = Swift.min(Int(draws[0] * Double(places.count)), places.count - 1)
        return Particles.Home(place: places[index], normal: normal)
    }
}
