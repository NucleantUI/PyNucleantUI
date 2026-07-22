//
//  VulkanCanvasRenderNode.swift
//  SulphurXcodeDemo
//

import NucleantVulkan
import VulkanCore
import CVulkan
//import NucleantVulkan

public protocol VulkanThorRenderNode: VulkanRenderNode {
    associatedtype CanvasSurface: ThorGPUCanvas
    var canvas: CanvasSurface { get }
    var width:  UInt32        { get }
    var height: UInt32        { get }
}


public protocol SkiaGPUCanvas {
    
}

public protocol VulkanSkiaRenderNode: VulkanRenderNode {
    associatedtype CanvasSurface: SkiaGPUCanvas
    var canvas: CanvasSurface { get }
    var width:  UInt32        { get }
    var height: UInt32        { get }
}
