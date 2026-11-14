public import Matrix
public import Picture
public import Vector

extension Particles {
    /// How a population is seen: through a `Picture.Scene.Camera` of swift-picture into a viewport of the
    /// picture, with the world placed by a model matrix and an optional focus. It makes the camera's products
    /// once, so a place is seen for the price of one matrix applied to it, and gives exactly the position and
    /// distance the camera's own `sight(of:in:viewport:)` gives.
    public struct View: Sendable {
        /// The camera.
        public let camera: Picture.Scene.Camera

        /// The rectangle of the picture the camera's normalised coordinates fill.
        public let viewport: Picture.Plane.Rectangle

        /// What takes the population's world into the camera's world.
        public let model: Matrix<4, 4, Double>

        /// The depth of field, if any.
        public let focus: Particles.Focus?

        /// Projection times view times model.
        let map: Matrix<4, 4, Double>

        /// View times model.
        let eye: Matrix<4, 4, Double>

        /// Picture units across the viewport's height per unit of normalised y, times the projection's y scale.
        let reach: Double

        /// A view through a camera into a viewport.
        public init(
            camera: Picture.Scene.Camera,
            viewport: Picture.Plane.Rectangle,
            model: Matrix<4, 4, Double> = .identity,
            focus: Particles.Focus? = nil
        ) {
            self.camera = camera
            self.viewport = viewport
            self.model = model
            self.focus = focus
            self.map = camera.map(of: model)
            self.eye = camera.eye(of: model)
            let lens = Picture.Scene.Camera(projection: camera.projection).map(of: .identity)
            self.reach = lens[1, 1] * (viewport.ury.underlying - viewport.lly.underlying) / 2
        }
    }
}

extension Particles.View {
    /// A place as this view sees it; nil, as the camera's sight is, for a place in the plane of the eye or
    /// behind it, and also for one in front of the near plane, which a scene does not draw.
    public func sight(of place: Point<3, Double>) -> Sight? {
        let clip = Picture.Scene.Camera.clip(place, through: map)
        guard clip[3] > 0 else { return nil }
        let normalized = Point<3, Double>([clip[0] / clip[3], clip[1] / clip[3], clip[2] / clip[3]])
        guard normalized[2] >= camera.projection.depth.range.lowerBound else { return nil }
        let distance = Picture.Scene.Camera.distance(of: place, through: eye)
        return Sight(
            position: Picture.Scene.Position(normalized, in: viewport).point,
            depth: normalized[2],
            distance: distance,
            scale: reach / clip[3],
            blur: focus?.blur(at: distance) ?? 0
        )
    }

    /// A direction of the world in eye space at unit length, as the camera gives it.
    public func direction(_ vector: Vector<3, Double>) -> Vector<3, Double> {
        Picture.Scene.Camera.direction(vector, through: eye)
    }
}
