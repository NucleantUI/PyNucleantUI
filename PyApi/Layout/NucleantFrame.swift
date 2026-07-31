//
//  SulphurFrame.swift
//  PyNucleantUI
//
//  Created by CodeBuilder on 16/07/2026.
//


@preconcurrency import PySwiftKit
import PySerializing
import PySwiftWrapper

//import SulphurUI
//import NucleantVulkan
//import SulphurApplication
import NucleantVulkan
import PyNucleantUI
import Foundation
import Observation

/// Observable so in-place mutation (`frame.size = …`) reaches whoever
/// renders from it — a live node canvas tracks `size` and rebuilds its
/// render node on change (`PySulphurCanvasBase.observeFrame`). Replacing
/// the whole frame object still goes through the widget's `frame` setter.
@Observable
@PyClass(self_ref: true)
public final class NucleantFrame: FrameProtocol, PySerialize, PyDeserialize, @unchecked Sendable {
    
    
    @PyProperty
    public var pos: SIMD2<Double>
    
    @PyProperty
    public var size: SIMD2<Double>
    
    @PyProperty
    public var flexible_width: Bool = false

    @PyProperty
    public var flexible_height: Bool = false

    @PyProperty
    public var x: Double {
        get { pos.x }
        set { pos.x = newValue }
    }

    /// Bridge the Python-facing snake_case flags onto `FrameProtocol`, so the
    /// layout maths read flexibility the same way for every frame type.
    public var flexibleWidth: Bool { flexible_width }
    public var flexibleHeight: Bool { flexible_height }
    
    var __self__: PyPointer?

    public init(pos: SIMD2<Double>, size: SIMD2<Double>) {
        self.pos = pos
        self.size = size
    }

    @PyInit
    init(__self__: PyPointer, x: Double, y: Double, w: Double, h: Double) {
        pos = .init(x, y)
        size = .init(w, h)
        self.__self__ = __self__
    }

    /// The concrete stand-in for a `nil` child: no fixed extent on either
    /// axis, so a stack layout resolves its position and size. Absent a
    /// layout its `size` stays whatever it was seeded with (defaults to the
    /// nearest ancestor's size when the widget hands its own frame down).
    public convenience init(
        flexible pos: SIMD2<Double> = .zero,
        size: SIMD2<Double> = .zero
    ) {
        self.init(pos: pos, size: size)
        flexible_width = true
        flexible_height = true
    }
    
    public func pyPointer() -> PyPointer {
        __self__?.newRef ?? .None //?? Self.asPyPointer(unretained: self)
    }
}


extension SIMD2: PySerializing.PyDeserialize where Scalar: PyDeserialize {
    public static func casted(from object: PySwiftKit.PyPointer) throws -> SIMD2<Scalar> {
        .init(
            try PyTuple_GetItem(object, index: 0),
            try PyTuple_GetItem(object, index: 1)
        )
    }
    
    public static func casted(unsafe object: PySwiftKit.PyPointer) throws -> SIMD2<Scalar> {
        .init(
            try PyTuple_GetItem(object, index: 0),
            try PyTuple_GetItem(object, index: 1)
        )
    }
}

extension SIMD2: PySerializing.PySerialize where Scalar: PySerialize {
    public func pyPointer() -> PyPointer {
        #PyTupleNew(x, y)
    }
}
