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
    
}

// make SIMD4 Double conform to FrameProtocol as default type for Frame.
extension SIMD4: FrameProtocol where Scalar == Double {
    public var pos: SIMD2<Double> { .init(x, y) }
    public var size: SIMD2<Double> { .init(z, w) }
    public var width: Double { z }
    public var height: Double { w }
}
