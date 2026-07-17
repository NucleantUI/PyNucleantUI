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
public final class SulphurFrame: FrameProtocol {
    public var pos: SIMD2<Double>

    public var size: SIMD2<Double>

    public init(pos: SIMD2<Double>, size: SIMD2<Double>) {
        self.pos = pos
        self.size = size
    }
}