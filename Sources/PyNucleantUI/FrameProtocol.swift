//
//  FrameProtocol.swift
//  ThorUI
//

import simd

public protocol FrameProtocol {

    var pos: SIMD2<Double> { get }
    var size: SIMD2<Double> { get }

    var x: Double { get }
    var y: Double { get }
    var width: Double { get }
    var height: Double { get }

    var bottom: Double { get }
    var top: Double { get }

    /// Per-axis flexibility: a flexible axis has no fixed extent of its own,
    /// so a stack layout supplies the size there — splitting the leftover
    /// length along the stack axis, filling the container across it. This is
    /// the same treatment a `nil` child gets, but expressible one axis at a
    /// time. Defaults to non-flexible so plain frame types (e.g. `SIMD4`)
    /// stay fixed-size.
    var flexibleWidth: Bool { get }
    var flexibleHeight: Bool { get }
}

// default fillout for types that dont have x,y,width,height,top, bottom
// can be "overriden" but in a more static way.
extension FrameProtocol {

    public var x: Double { pos.x }
    public var y: Double { pos.y }
    public var width: Double { size.x }
    public var height: Double { size.y }

    public var top: Double { pos.x + size.y }
    public var bottom: Double { pos.x }

    public var flexibleWidth: Bool { false }
    public var flexibleHeight: Bool { false }

}

// make SIMD4 Double conform to FrameProtocol as default type for Frame.
extension SIMD4: FrameProtocol where Scalar == Double {
    public var pos: SIMD2<Double> { .init(x, y) }
    public var size: SIMD2<Double> { .init(z, w) }
    public var width: Double { z }
    public var height: Double { w }
}
