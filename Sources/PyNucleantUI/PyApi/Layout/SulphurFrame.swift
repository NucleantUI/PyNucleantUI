//
//  SulphurFrame.swift
//  PyNucleantUI
//
//  Created by CodeBuilder on 16/07/2026.
//


@preconcurrency import PySwiftKit
import PySerializing
import PySwiftWrapper

import SulphurUI
import SulphurCore
import SulphurApplication
import SulphurVulkan
import Foundation
import Observation

/// Observable so in-place mutation (`frame.size = …`) reaches whoever
/// renders from it — a live node canvas tracks `size` and rebuilds its
/// render node on change (`PySulphurCanvasBase.observeFrame`). Replacing
/// the whole frame object still goes through the widget's `frame` setter.
@Observable
@PyClass
public final class SulphurFrame: FrameProtocol {
    
    @PyProperty
    public var pos: SIMD2<Double>
    
    @PyProperty
    public var size: SIMD2<Double>

    
    public init(pos: SIMD2<Double>, size: SIMD2<Double>) {
        self.pos = pos
        self.size = size
    }
    
    @PyInit
    init(x: Double, y: Double, w: Double, h: Double) {
        pos = .init(x, y)
        size = .init(w, h)
    }
}


extension SIMD2: PyDeserialize where Scalar: PyDeserialize {
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

extension SIMD2: PySerialize where Scalar: PySerialize {
    public func pyPointer() -> PyPointer {
        #PyTupleNew(x, y)
    }
}
