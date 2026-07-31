//
//  RenderNode.swift
//  PyNucleantUI
//
import NucleantVulkan
import CVulkan
import NucleantSkia
import NucleantThorVG
import NucleantShader
import PyNucleantBuffer

//public typealias RenderEngine = VulkanRenderEngine<RenderNode>

public final class RenderNode<Frame: FrameProtocol & AnyObject>: RenderContainerNode, @unchecked Sendable {
    
    
    public let id: Int
    
    public let context: Context
    
    public var needsRender: Bool = true

    /// The owning widget's frame. The composite reads it live every frame, so
    /// a layout change (position or size) repositions the slot with no rebind.
    public weak var frame: Frame?

    /// Where this slot composites — the live widget frame (x, y, w, h);
    /// nil fills the window.
    public var compositeRect: SIMD4<Double>? {
        frame.map { SIMD4($0.pos.x, $0.pos.y, $0.size.x, $0.size.y) }
    }

    public init(id: Int, context: Context) {
        self.context = context
        self.id = id
    }
    
    public func observeContext() {
        switch context {
        case .thor(let thorShaderNode):
            observe(thorShaderNode)
        case .skia(let skiaShaderNode):
            observe(skiaShaderNode)
        case .pixel_buffer(let pixelBufferShaderNode):
            observe(pixelBufferShaderNode)
        case .py_buffer(let pyBufferShaderNode):
            observe(pyBufferShaderNode)
        }
    }
    
    public func update(engine: Engine, cmd: VkCommandBuffer) {
        guard needsRender else { return }
        switch context {
        case .thor(let node):
            node.update(engine, slot: self, cmd: cmd)
        case .skia(let node):
            node.update(engine, slot: self, cmd: cmd)
        case .pixel_buffer(let node):
            node.update(engine, slot: self, cmd: cmd)
        case .py_buffer(let node):
            node.update(engine, slot: self, cmd: cmd)
        }
    }
    
    public func destroyResources(engine: Engine) {
        // Each node kind frees exactly what it owns (see
        // VulkanRenderNode.destroyResources). The window layer calls this
        // when a slot is dropped (detach/resize) once the node handoff is
        // wired; the slot just routes to its node.
        
        switch context {
        case .thor(let node):
            node.destroyResources(engine)
        case .skia(let node):
            node.destroyResources(engine)
        case .pixel_buffer(let node):
            node.destroyResources(engine)
        case .py_buffer(let node):
            node.destroyResources(engine)
        }
    }
    
    public func getImageView() -> VkImageView? {
        switch context {
        case .thor(let node): node.imageView
        case .skia(let node): node.imageView
        case .pixel_buffer(let node): node.imageView
        case .py_buffer(let node): node.imageView
        }
    }
}


extension RenderNode {
    public enum Context: RenderNodeContext {
        case thor(ThorShaderNode<RenderNode>)
        case skia(SkiaShaderNode<RenderNode>)
        case pixel_buffer(PixelBufferShaderNode<RenderNode>)
        case py_buffer(PyBufferShaderNode<RenderNode>)
    }
}


