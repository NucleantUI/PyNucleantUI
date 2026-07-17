//
//  WgpuContext.swift
//  SulphurXcodeDemo
//
//  Bootstraps wgpu-native (instance → adapter → device, Metal backend
//  forced) and creates the WGPUTexture ThorVG's wg backend renders into.
//  ThorVG requires real wgpu handles: passing nil device/instance to
//  tvg_wgcanvas_set_target makes WgRenderer::target release the context
//  and report success, which leaves every draw() failing with
//  TVG_RESULT_INSUFFICIENT_CONDITION.
//
//  The target texture is exported as its underlying MTLTexture
//  (wgpuTextureGetNativeMetalTexture) so VulkanRenderEngine can import
//  that same GPU memory as a VkImage via VK_EXT_metal_objects. ThorVG and
//  the Vulkan composite pass then read/write the exact same texture —
//  zero-copy, no CPU involvement.
//
import Foundation
import Metal
import SulphurCore
import CWgpu

public final class WgpuContext {

    /// One wgpu context for the whole process. Unlike the render engine —
    /// which is bound to one window's CAMetalLayer surface and therefore
    /// per-window — this context only bootstraps a device and mints target
    /// textures, so every window's nodes can share it: each engine imports
    /// the textures' Metal memory independently. nil when wgpu bootstrap
    /// failed (logged by init).
    public static let shared: WgpuContext? = WgpuContext()

    let instance: WGPUInstance
    let adapter:  WGPUAdapter
    let device:   WGPUDevice
    let queue:    WGPUQueue

    /// True when the adapter granted BGRA8UnormStorage, i.e. target textures
    /// carry StorageBinding usage (Metal shaderWrite) and canvas post
    /// shaders can imageStore into them. Compute post-processing is simply
    /// unavailable when this is false.
    let canvasStorageCapable: Bool

    init?() {
        var extras = WGPUInstanceExtras()
        extras.chain.sType = WGPUSType(rawValue: WGPUSType_InstanceExtras.rawValue)
        extras.backends = WGPUInstanceBackend_Metal

        var descriptor = WGPUInstanceDescriptor()
        let createdInstance: WGPUInstance? = withUnsafeMutablePointer(to: &extras.chain) { chainPtr in
            descriptor.nextInChain = chainPtr
            return wgpuCreateInstance(&descriptor)
        }
        guard let instance = createdInstance else {
            print("WgpuContext: wgpuCreateInstance failed")
            return nil
        }

        var adapterResult: WGPUAdapter? = nil
        withUnsafeMutablePointer(to: &adapterResult) { slot in
            var callbackInfo = WGPURequestAdapterCallbackInfo()
            callbackInfo.mode = WGPUCallbackMode_AllowSpontaneous
            callbackInfo.callback = { status, adapter, _, userdata1, _ in
                guard status == WGPURequestAdapterStatus_Success else { return }
                userdata1?.assumingMemoryBound(to: WGPUAdapter?.self).pointee = adapter
            }
            callbackInfo.userdata1 = UnsafeMutableRawPointer(slot)

            var options = WGPURequestAdapterOptions()
            options.powerPreference = WGPUPowerPreference_HighPerformance
            options.backendType = WGPUBackendType_Metal

            // wgpu-native invokes request callbacks synchronously; its
            // wgpuInstanceWaitAny is unimplemented (panics), so don't wait.
            _ = wgpuInstanceRequestAdapter(
                instance,
                &options,
                callbackInfo
            )
        }
        guard let adapter = adapterResult else {
            print("WgpuContext: wgpuInstanceRequestAdapter failed")
            return nil
        }

        // BGRA8Unorm textures only accept STORAGE_BINDING (Metal shaderWrite,
        // what canvas post shaders imageStore through) when the device is
        // created with the BGRA8UnormStorage feature — it's never on by
        // default, so it must be requested here at device creation.
        let bgraStorage = wgpuAdapterHasFeature(adapter, WGPUFeatureName_BGRA8UnormStorage) != 0

        var deviceResult: WGPUDevice? = nil
        withUnsafeMutablePointer(to: &deviceResult) { slot in
            var callbackInfo = WGPURequestDeviceCallbackInfo()
            callbackInfo.mode = WGPUCallbackMode_AllowSpontaneous
            callbackInfo.callback = { status, device, _, userdata1, _ in
                guard status == WGPURequestDeviceStatus_Success else { return }
                userdata1?.assumingMemoryBound(to: WGPUDevice?.self).pointee = device
            }
            callbackInfo.userdata1 = UnsafeMutableRawPointer(slot)

            if bgraStorage {
                var requiredFeatures: [WGPUFeatureName] = [WGPUFeatureName_BGRA8UnormStorage]
                requiredFeatures.withUnsafeBufferPointer { featPtr in
                    var descriptor = WGPUDeviceDescriptor()
                    descriptor.requiredFeatureCount = featPtr.count
                    descriptor.requiredFeatures = featPtr.baseAddress
                    _ = wgpuAdapterRequestDevice(
                        adapter,
                        &descriptor,
                        callbackInfo
                    )
                }
            } else {
                _ = wgpuAdapterRequestDevice(
                    adapter,
                    nil,
                    callbackInfo
                )
            }
        }
        guard let device = deviceResult else {
            print("WgpuContext: wgpuAdapterRequestDevice failed")
            return nil
        }

        self.instance = instance
        self.adapter  = adapter
        self.device   = device
        self.queue    = wgpuDeviceGetQueue(device)
        self.canvasStorageCapable = bgraStorage
    }

    /// BGRA8Unorm render target for the wg canvas. ThorVG's wg backend
    /// hardcodes its final "blit" pipeline to WgContext::format, which
    /// defaults to WGPUTextureFormat_BGRA8Unorm and is never reassigned —
    /// so the target texture must be BGRA8Unorm or the blit pipeline's
    /// render pass is format-incompatible and wgpu-native aborts.
    func makeTargetTexture(width: Int, height: Int) -> WGPUTexture? {
        var descriptor = WGPUTextureDescriptor()
        descriptor.usage = WGPUTextureUsage_RenderAttachment
            | WGPUTextureUsage_TextureBinding
            | WGPUTextureUsage_CopySrc
            | WGPUTextureUsage_CopyDst
        if canvasStorageCapable {
            // Metal shaderWrite on the underlying MTLTexture — required for
            // canvas post shaders to imageStore through the imported VkImage.
            descriptor.usage |= WGPUTextureUsage_StorageBinding
        }
        descriptor.dimension = WGPUTextureDimension_2D
        descriptor.size = WGPUExtent3D(
            width: UInt32(width),
            height: UInt32(height),
            depthOrArrayLayers: 1
        )
        descriptor.format = WGPUTextureFormat_BGRA8Unorm
        descriptor.mipLevelCount = 1
        descriptor.sampleCount = 1
        return wgpuDeviceCreateTexture(device, &descriptor)
    }

    /// The raw `id<MTLTexture>` backing a WGPUTexture created by this
    /// (Metal-backend) context — the same GPU memory ThorVG renders into.
    func nativeMetalTexture(of texture: WGPUTexture) -> UnsafeMutableRawPointer? {
        wgpuTextureGetNativeMetalTexture(texture)
    }

    /// Drop our reference to a `makeTargetTexture` texture. wgpu refcounts
    /// it and keeps it alive through any in-flight submission, but ThorVG
    /// holds its own reference while the texture is still a canvas's
    /// render target — retarget the canvas first or the memory stays.
    func release(texture: WGPUTexture) {
        wgpuTextureRelease(texture)
    }

    /// Blocks until every command previously submitted to this queue has
    /// actually finished on the GPU — not just been queued.
    /// `wgpuQueueSubmit` (used internally by ThorVG's wg backend to flush
    /// its blit) is fire-and-forget; `tvg_canvas_sync()` returning success
    /// only proves the work was queued, not completed, and `wgpuDevicePoll`
    /// isn't a dependable completion signal on the Metal backend (Metal
    /// advances via its own completion handlers, not polling). Metal
    /// command queues execute strictly in submission order, so committing
    /// a trivial buffer here and waiting on *it* is a standard fence:
    /// its completion guarantees everything submitted before it — Thor's
    /// blit included — has also completed.
    func waitForGPUCompletion() {
        // The fence below only proves completion — it never lets wgpu_core
        // run its maintain pass. wgpuQueueSubmit parks per-submission
        // tracking data (command-buffer/encoder allocations, textures
        // pending destruction) on the device, and ONLY wgpuDevicePoll
        // reclaims it once the submission is done. Nothing else in this
        // process ever polls, so skipping this leaks ~3.4 KB per canvas
        // draw — hundreds of MB per minute across all live canvases. The
        // non-blocking poll after the fence reclaims everything at once.
        defer { _ = wgpuDevicePoll(device, 0 /* don't block */, nil) }
        guard let rawQueue = wgpuQueueGetNativeMetalCommandQueue(queue) else { return }
        let mtlQueue = Unmanaged<AnyObject>.fromOpaque(rawQueue).takeUnretainedValue() as! MTLCommandQueue
        guard let fence = mtlQueue.makeCommandBuffer() else { return }
        fence.commit()
        fence.waitUntilCompleted()
    }
}
