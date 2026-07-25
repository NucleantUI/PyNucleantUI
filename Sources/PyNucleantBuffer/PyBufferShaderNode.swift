//
//  PyBufferShaderNode.swift
//  PyNucleantBuffer
//
//  A render node fed straight from Python's buffer protocol. Its own
//  target, and outside the engine, for the reason in refactor-plan.md:
//  shader-node code doesn't belong in VulkanRenderEngine unless it's
//  generic, and this one is anything but — it speaks CPython.
//
//  Where `PixelBufferShaderNode` takes bytes Swift already holds, this
//  takes the producer object itself and reads it through
//  `PyObject_GetBuffer`. That accepts `bytes`, `bytearray`, `memoryview`,
//  numpy, ctypes, `array.array`, and — the point of it — any extension
//  type carrying a `bf_getbuffer` slot of its own, e.g. a
//  `nucleant.nes.NesLayer`. Deserializing to `Data` cannot: `Data.casted`
//  switches on the concrete Python type and rejects everything else, so a
//  producer that *is* a buffer has to be wrapped in `memoryview()` first.
//
import NucleantVulkan
import VulkanCore
import CVulkan
@preconcurrency import PySwiftKit
import Observation

/// A Python-fed render node: the content is whatever buffer-protocol
/// object a Python producer hands to `write` each frame, uploaded into the
/// node's VkImage through a persistently-mapped staging buffer — plus the
/// same compute post-shader slot the other nodes carry, so a
/// `CanvasShader` runs on the uploaded pixels before the composite pass
/// samples them.
///
/// The Vulkan choreography below deliberately mirrors
/// `PixelBufferShaderNode`: same barriers, same optional scale blit, same
/// staging-slice-per-frame-in-flight contract. Only the source of the
/// bytes differs, and that is the whole reason this is a separate node
/// kind rather than another argument on that one.
///
/// `@Observable` for the same reason as the other nodes: the owning slot
/// tracks `dirty` / the compute trio, so a `write` or a pipeline swap
/// re-renders on its own.
///
/// Threading contract: `write` and the engine's frame loop share a thread
/// (everything runs on main today). `write` only touches the CPU-side
/// backing store — the copy into the staging slice happens at record time,
/// after the frame fence proved the GPU is done with that slice, so the
/// producer can never scribble over pixels the GPU is still reading.
@Observable
public final class PyBufferShaderNode<ContainerNode: RenderContainerNode>: VulkanRenderNode, @unchecked Sendable {

    public typealias Engine = VulkanRenderEngine<ContainerNode>

    /// Size of `image` — the surface shaders and the composite see.
    /// This is `sourceWidth/Height × scale`.
    public var width:  UInt32
    public var height: UInt32

    /// Content resolution the producer writes (e.g. 256×240 for a NES).
    /// With `scale` > 1 the upload path nearest-blits these pixels up into
    /// the scale×-larger `image`, so the producer never pays for the
    /// magnification — a post shader gets real subpixels for free.
    public let sourceWidth:  UInt32
    public let sourceHeight: UInt32
    public let scale:        UInt32

    public var image:     VkImage
    public var imageView: VkImageView
    /// The allocation backing `image` — carried for whoever tears the node
    /// down, same contract as the other nodes' `memory`.
    public var memory:    VkDeviceMemory?

    /// Intermediate upload target at source resolution — the blit source
    /// feeding `image`. Nil at scale 1, where staging copies straight into
    /// `image`.
    public let uploadImage:  VkImage?
    public let uploadMemory: VkDeviceMemory?
    /// Vulkan-tracked layout of `uploadImage`, same stale-oldLayout
    /// contract as `currentLayout`.
    var uploadLayout: VkImageLayout = VK_IMAGE_LAYOUT_UNDEFINED

    /// Host-visible upload buffer, one slice per frame-in-flight so the
    /// CPU never rewrites bytes an in-flight copy still reads. Mapped once
    /// at creation and unmapped only at teardown.
    public let stagingBuffer: VkBuffer
    public let stagingMemory: VkDeviceMemory
    let stagingPointer:       UnsafeMutableRawPointer
    /// Bytes of one full *source* frame (sourceWidth × sourceHeight × 4,
    /// tightly packed RGBA8) — staging and `write` deal in source pixels.
    public let bytesPerFrame: Int
    let stagingSliceCount:    Int

    public var computePipeline:      VkPipeline?
    public var computeLayout:        VkPipelineLayout?
    public var computeDescriptorSet: VkDescriptorSet?
    public var dirty:                Bool = true

    /// The image is engine-owned RGBA8 with STORAGE usage — a compute post
    /// shader may always bind it as its output image.
    public let storageCapable: Bool = true

    /// The image's actual current Vulkan-tracked layout — same
    /// stale-oldLayout contract as the other nodes. Starts UNDEFINED:
    /// nothing has ever been uploaded, and the first upload overwrites
    /// every texel, so discarding is fine.
    var currentLayout: VkImageLayout = VK_IMAGE_LAYOUT_UNDEFINED

    /// False until the first successful `write` — the engine keeps the
    /// node out of the composite until there are real pixels.
    public private(set) var hasContent: Bool = false

    /// CPU-side backing store the producer's bytes land in. Ignored by
    /// Observation on purpose: a 240p frame is ~61k pixels a frame, and
    /// `dirty` already carries the change signal.
    @ObservationIgnored
    private var pixels: [UInt8]

    init(
        sourceWidth:    UInt32,
        sourceHeight:   UInt32,
        scale:          UInt32,
        image:          VkImage,
        imageView:      VkImageView,
        memory:         VkDeviceMemory?,
        uploadImage:    VkImage?,
        uploadMemory:   VkDeviceMemory?,
        stagingBuffer:  VkBuffer,
        stagingMemory:  VkDeviceMemory,
        stagingPointer: UnsafeMutableRawPointer,
        sliceCount:     Int
    ) {
        self.sourceWidth       = sourceWidth
        self.sourceHeight      = sourceHeight
        self.scale             = max(scale, 1)
        self.width             = sourceWidth  * self.scale
        self.height            = sourceHeight * self.scale
        self.image             = image
        self.imageView         = imageView
        self.memory            = memory
        self.uploadImage       = uploadImage
        self.uploadMemory      = uploadMemory
        self.stagingBuffer     = stagingBuffer
        self.stagingMemory     = stagingMemory
        self.stagingPointer    = stagingPointer
        self.bytesPerFrame     = Int(sourceWidth) * Int(sourceHeight) * 4
        self.stagingSliceCount = max(sliceCount, 1)
        self.pixels            = [UInt8](repeating: 0, count: self.bytesPerFrame)
    }

    // MARK: Python-fed write

    /// Read a frame of tightly-packed RGBA8 out of any buffer-protocol
    /// object. Short input fills what it covers; excess bytes are ignored.
    /// Returns false if the object doesn't export a buffer — the caller
    /// raises, the node keeps its last frame.
    ///
    /// The view is acquired and released inside this call, on purpose:
    /// `PyBuffer_Release` needs the GIL, and the only place it is certainly
    /// held is here, inside the Python call. Holding the view open until
    /// record time would save the copy into `pixels` but would mean
    /// releasing it from the engine's frame loop, where the GIL state isn't
    /// ours to assume.
    @discardableResult
    public func write(buffer: PyPointer) -> Bool {
        var view = Py_buffer()
        guard PyObject_GetBuffer(buffer, &view, Int32(PyBUF_SIMPLE)) == 0 else {
            return false
        }
        defer { PyBuffer_Release(&view) }
        guard let base = view.buf, view.len > 0 else { return false }
        let count = min(Int(view.len), bytesPerFrame)
        pixels.withUnsafeMutableBytes { destination in
            destination.baseAddress!.copyMemory(from: base, byteCount: count)
        }
        hasContent = true
        dirty = true
        return true
    }

    // MARK: Engine-side upload

    /// Byte offset of a frame slice inside `stagingBuffer`.
    func stagingOffset(of slice: Int) -> Int {
        (slice % stagingSliceCount) * bytesPerFrame
    }

    /// Copy the CPU backing store into a staging slice. Only the engine
    /// calls this, after the slice's frame fence signalled — that fence is
    /// the proof no in-flight copy still reads these bytes.
    func stage(into slice: Int) {
        pixels.withUnsafeBytes { source in
            stagingPointer
                .advanced(by: stagingOffset(of: slice))
                .copyMemory(from: source.baseAddress!, byteCount: bytesPerFrame)
        }
    }
}

extension PyBufferShaderNode {

    /// Staged pixels are copied into the node's image (nearest-blitted up
    /// when scaled), then optionally run through the compute post shader —
    /// TRANSFER standing in for the canvas draw the thor/skia nodes do.
    /// Without a first successful `write` the node has no content and stays
    /// unpublished.
    public func update(_ engine: Engine, slot: ContainerNode, cmd: VkCommandBuffer) {
        guard slot.needsRender, hasContent else { return }

        // This frame slot's fence was waited at the top of drawFrame — the
        // staging slice indexed by it is provably idle, so the CPU copy
        // here can't race the previous frame's GPU read.
        stage(into: engine.frameIndex)

        // First upload ever: the image is still UNDEFINED and fully
        // overwritten by the copy, so discarding is correct. Afterwards the
        // real prior state is "composite sampled it last frame".
        let firstUpload = currentLayout == VK_IMAGE_LAYOUT_UNDEFINED
        engineImageBarrier(
            cmd,
            image:     image,
            srcLayout: currentLayout,
            srcAccess: firstUpload ? 0 : VkAccessFlags(VK_ACCESS_SHADER_READ_BIT.rawValue),
            srcStage:  firstUpload ? VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT : VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
            dstLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            dstAccess: VkAccessFlags(VK_ACCESS_TRANSFER_WRITE_BIT.rawValue),
            dstStage:  VK_PIPELINE_STAGE_TRANSFER_BIT
        )

        let colorLayers = VkImageSubresourceLayers(
            aspectMask:     VkImageAspectFlags(VK_IMAGE_ASPECT_COLOR_BIT.rawValue),
            mipLevel:       0,
            baseArrayLayer: 0,
            layerCount:     1
        )
        var region = VkBufferImageCopy()
        region.bufferOffset = VkDeviceSize(stagingOffset(of: engine.frameIndex))
        // bufferRowLength/bufferImageHeight 0 = tightly packed.
        region.imageSubresource = colorLayers
        region.imageExtent = VkExtent3D(width: sourceWidth, height: sourceHeight, depth: 1)

        if let uploadImage {
            // Scaled path: staging lands in the source-sized upload image,
            // then a nearest blit stretches it into the scale×-larger node
            // image — the GPU does the pixel replication the producer no
            // longer pays for. After the first frame the upload image's
            // prior state is "blit read it", hence TRANSFER_SRC.
            let firstSmall = uploadLayout == VK_IMAGE_LAYOUT_UNDEFINED
            engineImageBarrier(
                cmd,
                image:     uploadImage,
                srcLayout: uploadLayout,
                srcAccess: firstSmall ? 0 : VkAccessFlags(VK_ACCESS_TRANSFER_READ_BIT.rawValue),
                srcStage:  VK_PIPELINE_STAGE_TRANSFER_BIT,
                dstLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                dstAccess: VkAccessFlags(VK_ACCESS_TRANSFER_WRITE_BIT.rawValue),
                dstStage:  VK_PIPELINE_STAGE_TRANSFER_BIT
            )
            vkCmdCopyBufferToImage(
                cmd,
                stagingBuffer,
                uploadImage,
                VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                1,
                &region
            )
            engineImageBarrier(
                cmd,
                image:     uploadImage,
                srcLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                srcAccess: VkAccessFlags(VK_ACCESS_TRANSFER_WRITE_BIT.rawValue),
                srcStage:  VK_PIPELINE_STAGE_TRANSFER_BIT,
                dstLayout: VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                dstAccess: VkAccessFlags(VK_ACCESS_TRANSFER_READ_BIT.rawValue),
                dstStage:  VK_PIPELINE_STAGE_TRANSFER_BIT
            )
            uploadLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL

            var blit = VkImageBlit()
            blit.srcSubresource = colorLayers
            blit.srcOffsets.1   = VkOffset3D(x: Int32(sourceWidth), y: Int32(sourceHeight), z: 1)
            blit.dstSubresource = colorLayers
            blit.dstOffsets.1   = VkOffset3D(x: Int32(width), y: Int32(height), z: 1)
            vkCmdBlitImage(
                cmd,
                uploadImage,
                VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                image,
                VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                1,
                &blit,
                VK_FILTER_NEAREST
            )
        } else {
            vkCmdCopyBufferToImage(
                cmd,
                stagingBuffer,
                image,
                VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                1,
                &region
            )
        }

        if let pipeline = computePipeline,
           let layout   = computeLayout,
           let ds       = computeDescriptorSet {

            engineImageBarrier(
                cmd,
                image:     image,
                srcLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                srcAccess: VkAccessFlags(VK_ACCESS_TRANSFER_WRITE_BIT.rawValue),
                srcStage:  VK_PIPELINE_STAGE_TRANSFER_BIT,
                dstLayout: VK_IMAGE_LAYOUT_GENERAL,
                dstAccess: VkAccessFlags(VK_ACCESS_SHADER_READ_BIT.rawValue) | VkAccessFlags(VK_ACCESS_SHADER_WRITE_BIT.rawValue),
                dstStage:  VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT
            )
            vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, pipeline)
            var descSet: VkDescriptorSet? = ds
            vkCmdBindDescriptorSets(cmd, VK_PIPELINE_BIND_POINT_COMPUTE, layout, 0, 1, &descSet, 0, nil)
            vkCmdDispatch(cmd, (width + 7) / 8, (height + 7) / 8, 1)
            engineImageBarrier(
                cmd,
                image:     image,
                srcLayout: VK_IMAGE_LAYOUT_GENERAL,
                srcAccess: VkAccessFlags(VK_ACCESS_SHADER_WRITE_BIT.rawValue),
                srcStage:  VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,
                dstLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                dstAccess: VkAccessFlags(VK_ACCESS_SHADER_READ_BIT.rawValue),
                dstStage:  VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT
            )
        } else {
            engineImageBarrier(
                cmd,
                image:     image,
                srcLayout: VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                srcAccess: VkAccessFlags(VK_ACCESS_TRANSFER_WRITE_BIT.rawValue),
                srcStage:  VK_PIPELINE_STAGE_TRANSFER_BIT,
                dstLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
                dstAccess: VkAccessFlags(VK_ACCESS_SHADER_READ_BIT.rawValue),
                dstStage:  VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT
            )
        }
        currentLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
        engine.readable.insert(slot.id)
        // slot.needsRender deliberately not cleared — same steady-state as
        // the other node updates.
    }

    /// Free everything this node owns after draining the device: the
    /// persistently-mapped staging buffer (unmapped before its free), the
    /// image/view/memory, and — when scaling — the source-sized upload
    /// image and its memory.
    public func destroyResources(_ engine: Engine) {
        vkDeviceWaitIdle(engine.device)
        vkUnmapMemory(engine.device, stagingMemory)
        vkDestroyBuffer(engine.device, stagingBuffer, nil)
        vkFreeMemory(engine.device, stagingMemory, nil)
        vkDestroyImageView(engine.device, imageView, nil)
        vkDestroyImage(engine.device, image, nil)
        if let memory {
            vkFreeMemory(engine.device, memory, nil)
        }
        if let uploadImage {
            vkDestroyImage(engine.device, uploadImage, nil)
        }
        if let uploadMemory {
            vkFreeMemory(engine.device, uploadMemory, nil)
        }
    }
}
