//
//  PyAppRenderTarget.swift
//  SulphurXcodeDemo
//
import AppKit
import SulphurCore
import SulphurApplication
import SulphurVulkan


extension PyApp {

    /// Presentation stack for the root widget: the Vulkan engine attached to
    /// the window's SulphurNSView, the ThorVG node whose canvas the root
    /// widget draws into, and the wgpu context/texture backing that canvas.
    struct RootRenderTarget {
        let engine:        VulkanRenderEngine
        let node:          ThorShaderNode
        let wgpu:          WgpuContext
        let targetTexture: WGPUTexture
    }

    /// Build the engine on the window's metal layer, bootstrap wgpu, and
    /// create a ThorVG GPU canvas targeted at a real WGPUTexture. That same
    /// texture's underlying `id<MTLTexture>` is then imported as the node's
    /// VkImage (VK_EXT_metal_objects) — so the Vulkan composite pass reads
    /// the exact memory ThorVG rendered into, not a second, disconnected
    /// image. Zero-copy, no CPU involvement anywhere in the frame.
    static func makeRootRenderTarget() -> RootRenderTarget? {
        guard
            let view = NSApplication.shared.windows
                .compactMap({ $0.contentView as? SulphurNSView })
                .first
        else {
            print("PyApp: no SulphurNSView found to attach the render engine")
            return nil
        }

        guard let engine = try? VulkanRenderEngine(metalLayer: view.metalLayer) else {
            print("PyApp: VulkanRenderEngine creation failed")
            return nil
        }

        let drawable = view.metalLayer.drawableSize
        let width  = max(Int(drawable.width),  1)
        let height = max(Int(drawable.height), 1)

        guard let wgpu = WgpuContext() else {
            print("PyApp: wgpu bootstrap failed")
            return nil
        }

        guard let built = engine.makeWidgetNode(wgpu: wgpu, width: width, height: height) else {
            print("PyApp: root ThorVG render node creation failed")
            return nil
        }

        engine.append(.node(built.node))

        return RootRenderTarget(
            engine: engine,
            node: built.node,
            wgpu: wgpu,
            targetTexture: built.texture
        )
    }
}
