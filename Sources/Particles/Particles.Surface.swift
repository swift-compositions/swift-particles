public import Mesh
import Picture
public import Vector

extension Particles {
    /// The surface of a mesh, every part of it as likely as its share of the area, by `Mesh.Sampler` of
    /// swift-mesh. A home's normal is the mesh's vertex normals, `normals(per: .vertex)`, interpolated there
    /// and brought to unit length.
    public struct Surface: Sendable {
        /// The sampler over the mesh.
        public let sampler: Mesh<Point<3, Double>>.Sampler<Double>

        /// The mesh's normal at each vertex.
        public let normals: [Vector<3, Double>]

        /// The surface of a mesh; nil for a mesh with no area.
        public init?(_ mesh: Mesh<Point<3, Double>>) {
            guard let sampler = Mesh<Point<3, Double>>.Sampler<Double>(mesh) else { return nil }
            self.sampler = sampler
            self.normals = mesh.normals(per: .vertex)
        }
    }
}

extension Particles.Surface: Particles.Shape {
    /// A particle's home: draws 0, 1 and 2 as the sampler's point of the unit cube.
    public func home(_ draws: Particles.Draws) -> Particles.Home {
        let pair = draws.pair(0)
        let location = sampler.location(pair.first, pair.second, draws[2])
        let normal = sampler.interpolate(normals, at: location)
        let length = (normal.x * normal.x + normal.y * normal.y + normal.z * normal.z).squareRoot()
        return Particles.Home(
            place: sampler.position(of: location),
            normal: length > 0 && length.isFinite ? Vector(x: normal.x / length, y: normal.y / length, z: normal.z / length) : nil
        )
    }
}
