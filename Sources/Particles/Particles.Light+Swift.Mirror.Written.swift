public import Standard_Library_Extensions

/// A light of many motes writes itself for `Swift.Mirror.bytes(of:)`, which keys a picture holding it, where
/// reflection costs about a microsecond a part. Every stored property is written, in order; a test lists the stored
/// properties of a light and a mote by `Mirror` and fails when one is added, and the `switch` is exhaustive.
extension Particles.Light: Swift.Mirror.Written {
    public func write(into writer: Swift.Mirror.Writer) -> Bool {
        guard writer.write(frame) else { return false }
        writer.float(scale)
        writer.float(footprint)
        writer.number(UInt64(Int(clamping: width)))
        writer.number(UInt64(Int(clamping: height)))
        writer.number(UInt64(additions.count))
        for addition in additions {
            switch addition {
            case .mote(let mote):
                writer.number(0)
                Self.write(mote, into: writer)

            case .trail(let motes, let persistence):
                writer.number(1)
                writer.number(UInt64(motes.count))
                for mote in motes { Self.write(mote, into: writer) }
                writer.float(persistence)

            case .light(let other):
                writer.number(2)
                guard other.write(into: writer) else { return false }
            }
        }
        return true
    }

    /// A mote: its position's two coordinates, its radius, its colour's four components, its strength and its blur.
    static func write(_ mote: Particles.Mote, into writer: Swift.Mirror.Writer) {
        writer.float(mote.position[0])
        writer.float(mote.position[1])
        writer.float(mote.radius)
        writer.float(Double(mote.color.red))
        writer.float(Double(mote.color.green))
        writer.float(Double(mote.color.blue))
        writer.float(Double(mote.color.alpha))
        writer.float(mote.strength)
        writer.float(mote.blur)
    }
}
