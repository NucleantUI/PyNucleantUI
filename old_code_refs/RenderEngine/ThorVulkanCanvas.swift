//
//  ThorVulkanCanvas.swift
//  PyNucleantUI
//

import NucleantVulkan
import VulkanCore
import CVulkan
//import NucleantVulkan



/// Concrete ThorVG GPU canvas — wraps the raw `Tvg_Canvas` handle. A class,
/// not a struct: this is a reference to one live ThorVG canvas instance:
/// its lifetime and identity must never be duplicated by value-copy.
public final class ThorVulkanCanvas: ThorGPUCanvas {
    public var base: Tvg_Canvas
    public init(base: Tvg_Canvas) {
        self.base = base
    }
}
