//
//  RenderNode.swift
//  PyNucleantUI
//
import NucleantVulkan
import CVulkan
import NucleantSkia
import NucleantThorVG
import NucleantShader

public typealias RenderEngine = VulkanRenderEngine<RenderNode>

public final class RenderNode: RenderContainerNode, @unchecked Sendable {
    
    
    public let id: Int
    
    public let context: Context
    
    public var needsRender: Bool = true
    
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
        }
    }
    
    public func getImageView() -> VkImageView? {
        switch context {
        case .thor(let node): node.imageView
        case .skia(let node): node.imageView
        case .pixel_buffer(let node): node.imageView
        }
    }
}


extension RenderNode {
    public enum Context: RenderNodeContext {
        case thor(ThorShaderNode<RenderNode>)
        case skia(SkiaShaderNode<RenderNode>)
        case pixel_buffer(PixelBufferShaderNode<RenderNode>)
    }
}
