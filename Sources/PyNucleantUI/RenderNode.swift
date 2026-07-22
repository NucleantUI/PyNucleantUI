//
//  RenderNode.swift
//  PyNucleantUI
//
import NucleantVulkan
import CVulkan
import NucleantSkia
import NucleantThorVG

public typealias RenderEngine = VulkanRenderEngine<RenderNode>

public final class RenderNode: RenderContainerNode {
    
    
    public var id: Int
    
    public var context: Context
    
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
        }
    }
    
    public func update(engine: Engine, cmd: VkCommandBuffer) {
        guard needsRender else { return }
        switch context {
        case .thor(let node):
            node.update(engine, slot: self, cmd: cmd)
        case .skia(let node):
            node.update(engine, slot: self, cmd: cmd)
        }
    }
    
    public func recordComposite(engine: Engine, cmd: VkCommandBuffer, viewport: VkViewport, scissor: VkRect2D) {
        fatalError()
    }
    
    public func destroyResources(engine: Engine) {
        switch context {
        case .thor(let node):
            break
        case .skia(let node):
            break
        }
    }
    
    public func getImageView() -> VkImageView? {
        switch context {
        case .thor(let thorShaderNode):
            thorShaderNode.imageView
        case .skia(let skiaShaderNode):
            skiaShaderNode.imageView
        }
    }
}


extension RenderNode {
    public enum Context: RenderNodeContext {
        case thor(ThorShaderNode<RenderNode>)
        case skia(SkiaShaderNode<RenderNode>)
    }
}
