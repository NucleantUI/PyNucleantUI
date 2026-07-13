//
//  CanvasShader.swift
//  SulphurXcodeDemo
//
//  Python-facing post shader for a widget's ThorVG canvas.
//
//  `frag_code` holds fragment-style GLSL that is wrapped into a compute
//  shader, compiled to SPIR-V (shaderc via `VKShaderCompiler`), and installed
//  into the node's existing compute post-process slot
//  (`ThorShaderNode.computePipeline/-Layout/-DescriptorSet`). The engine's
//  per-frame `update(_:cmd:)` then runs it in place on the canvas VkImage —
//  ThorVG draws the 2D content, the shader post-processes that exact GPU
//  memory before the composite pass samples it.
//
//  User contract (fragment-style): `frag_code` defines
//
//      vec4 post_process(vec4 color, vec2 uv)
//
//  where `color` is the canvas pixel and `uv` is in [0, 1]. Escape hatch:
//  source starting with `#version` is compiled as a complete compute shader
//  and must declare `local_size_x = 8, local_size_y = 8` (the engine
//  dispatches (w+7)/8 × (h+7)/8 workgroups) plus its own bindings matching
//  the set layout below (binding 0 sampler2D input, binding 1 rgba8 image
//  output).
//
import Foundation
import CVulkan
import VulkanCore
import SulphurVulkan
import SulphurShader
import PySwiftKit
import PySerializing
import PySwiftWrapper

enum CanvasShaderError: Error {
    case notStorageCapable
    case compileFailed
    case vulkan(String)
}

@PyClass
public final class CanvasShader: PyDeserialize {

    @PyProperty
    var id: Int = UUID().hashValue

    @PyProperty
    var frag_code: String? {
        didSet { rebuild() }
    }

    private weak var engine: VulkanRenderEngine?
    private var node: ThorShaderNode?
    private var post: CanvasPostPipeline?

    @PyInit
    init(frag_code: String?) {
        self.frag_code = frag_code
    }

    /// Bind this shader to a live render node — called by
    /// `SulphurCanvasBase.add_shader` once the canvas has its node.
    func attach(engine: VulkanRenderEngine, node: ThorShaderNode) throws {
        self.engine = engine
        self.node = node
        try rebuildOrThrow()
    }

    /// The inverse of `attach`: tear the installed pipeline off the node and
    /// forget it, leaving the node running with no post pass. Safe to call
    /// when nothing is installed. The shader object itself stays reusable —
    /// `attach` it again (same node or another) to reinstall.
    func detach() {
        if post != nil, let engine {
            vkDeviceWaitIdle(engine.device)
        }
        node?.computePipeline      = nil
        node?.computeLayout        = nil
        node?.computeDescriptorSet = nil
        node?.dirty                = true
        post?.destroy()
        post   = nil
        node   = nil
        engine = nil
    }

    /// Recompile + reinstall after a `frag_code` change. Property observers
    /// can't throw, so this path only logs; `attach` (the Python
    /// `add_shader` call) uses the throwing variant and surfaces errors as
    /// Python exceptions.
    private func rebuild() {
        do {
            try rebuildOrThrow()
        } catch {
            print("CanvasShader: rebuild failed: \(error)")
        }
    }

    private func rebuildOrThrow() throws {
        guard let engine, let node else { return }

        // Tear down the previous pipeline first. The old pipeline may still
        // be referenced by an in-flight command buffer, so drain the GPU
        // before destroying it.
        if post != nil {
            vkDeviceWaitIdle(engine.device)
            node.computePipeline      = nil
            node.computeLayout        = nil
            node.computeDescriptorSet = nil
            post?.destroy()
            post = nil
        }

        guard let source = frag_code, !source.isEmpty else { return }
        guard node.storageCapable else {
            throw CanvasShaderError.notStorageCapable
        }

        let built = try CanvasPostPipeline(
            device:    engine.device,
            imageView: node.imageView,
            source:    Self.computeSource(from: source)
        )
        node.computePipeline      = built.pipeline
        node.computeLayout        = built.pipelineLayout
        node.computeDescriptorSet = built.descriptorSet
        node.dirty                = true
        post = built
        print("CanvasShader: post shader installed on node \(node.width)x\(node.height)")
    }

    /// Wrap fragment-style user code into the engine's compute contract.
    /// Local size 8×8 matches the engine's `(w+7)/8` dispatch exactly.
    static func computeSource(from fragCode: String) -> String {
        if fragCode.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("#version") {
            return fragCode
        }
        return """
        #version 450

        layout(local_size_x = 8, local_size_y = 8) in;
        layout(binding = 0) uniform sampler2D uCanvas;
        layout(binding = 1, rgba8) uniform writeonly image2D uOutput;

        \(fragCode)

        void main() {
            ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
            ivec2 size = imageSize(uOutput);
            if (pixel.x >= size.x || pixel.y >= size.y) { return; }
            vec2 uv = (vec2(pixel) + 0.5) / vec2(size);
            vec4 color = texture(uCanvas, uv);
            imageStore(uOutput, pixel, post_process(color, uv));
        }
        """
    }
}


// MARK: - Vulkan pipeline

/// Owns every Vulkan object behind one canvas post shader: compute pipeline,
/// its layout, and a dedicated descriptor pool/set pointed at the node's
/// image. The set binds the same image twice — sampled input (binding 0) and
/// storage output (binding 1) — both in GENERAL layout, which is exactly
/// where the engine's pre-dispatch barrier puts the image. Reading through a
/// sampler and writing through a write-only storage image sidesteps Metal's
/// read_write texture-tier restriction on BGRA8Unorm: each binding needs
/// only shaderRead resp. shaderWrite usage.
///
/// A dedicated one-set pool per shader for the same reason the engine gives
/// each composite node its own pool: MoltenVK packing multiple same-layout
/// sets into one pool misaligns Metal argument-buffer offsets.
final class CanvasPostPipeline {

    private let device: VkDevice

    private(set) var pipeline:       VkPipeline?
    private(set) var pipelineLayout: VkPipelineLayout?
    private(set) var descriptorSet:  VkDescriptorSet?

    private var setLayout:      VkDescriptorSetLayout?
    private var shaderModule:   VkShaderModule?
    private var descriptorPool: VkDescriptorPool?
    private var sampler:        VkSampler?

    init(device: VkDevice, imageView: VkImageView, source: String) throws {
        self.device = device

        guard let spirv = VKShaderCompiler.shared.tryCompileCompute(source) else {
            throw CanvasShaderError.compileFailed
        }

        do {
            try createSetLayout()
            try createPipelineLayout()
            shaderModule = try ShaderModuleLoader.load(device: device, spirv: spirv)
            try createPipeline()
            try createSampler()
            try createDescriptorSet(imageView: imageView)
        } catch {
            destroy()
            throw error
        }
    }

    deinit {
        destroy()
    }

    /// Idempotent teardown. The caller is responsible for making sure no
    /// in-flight command buffer still references these objects
    /// (`vkDeviceWaitIdle` before rebuilds).
    func destroy() {
        if let pipeline       { vkDestroyPipeline(device, pipeline, nil) }
        if let pipelineLayout { vkDestroyPipelineLayout(device, pipelineLayout, nil) }
        if let shaderModule   { vkDestroyShaderModule(device, shaderModule, nil) }
        if let setLayout      { vkDestroyDescriptorSetLayout(device, setLayout, nil) }
        if let sampler        { vkDestroySampler(device, sampler, nil) }
        if let descriptorPool { vkDestroyDescriptorPool(device, descriptorPool, nil) }
        pipeline       = nil
        pipelineLayout = nil
        shaderModule   = nil
        setLayout      = nil
        sampler        = nil
        descriptorPool = nil
        descriptorSet  = nil
    }

    // MARK: Creation steps

    private func createSetLayout() throws {
        var input = VkDescriptorSetLayoutBinding()
        input.binding         = 0
        input.descriptorType  = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
        input.descriptorCount = 1
        input.stageFlags      = VkShaderStageFlags(VK_SHADER_STAGE_COMPUTE_BIT.rawValue)

        var output = VkDescriptorSetLayoutBinding()
        output.binding         = 1
        output.descriptorType  = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE
        output.descriptorCount = 1
        output.stageFlags      = VkShaderStageFlags(VK_SHADER_STAGE_COMPUTE_BIT.rawValue)

        let bindings = [input, output]
        let result = bindings.withUnsafeBufferPointer { buf -> VkResult in
            var info = VkDescriptorSetLayoutCreateInfo()
            info.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO
            info.bindingCount = UInt32(buf.count)
            info.pBindings = buf.baseAddress
            return vkCreateDescriptorSetLayout(device, &info, nil, &setLayout)
        }
        guard result == VK_SUCCESS else {
            throw CanvasShaderError.vulkan("vkCreateDescriptorSetLayout failed: \(result.rawValue)")
        }
    }

    private func createPipelineLayout() throws {
        let result = withUnsafePointer(to: setLayout) { layoutPtr -> VkResult in
            var info = VkPipelineLayoutCreateInfo()
            info.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO
            info.setLayoutCount = 1
            info.pSetLayouts = layoutPtr
            return vkCreatePipelineLayout(device, &info, nil, &pipelineLayout)
        }
        guard result == VK_SUCCESS else {
            throw CanvasShaderError.vulkan("vkCreatePipelineLayout failed: \(result.rawValue)")
        }
    }

    private func createPipeline() throws {
        let result = "main".withCString { entry -> VkResult in
            var stage = VkPipelineShaderStageCreateInfo()
            stage.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO
            stage.stage = VK_SHADER_STAGE_COMPUTE_BIT
            stage.module = shaderModule
            stage.pName = entry

            var info = VkComputePipelineCreateInfo()
            info.sType = VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO
            info.stage = stage
            info.layout = pipelineLayout
            info.basePipelineIndex = -1
            return vkCreateComputePipelines(device, nil, 1, &info, nil, &pipeline)
        }
        guard result == VK_SUCCESS else {
            throw CanvasShaderError.vulkan("vkCreateComputePipelines failed: \(result.rawValue)")
        }
    }

    private func createSampler() throws {
        var info = VkSamplerCreateInfo()
        info.sType        = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO
        info.magFilter    = VK_FILTER_LINEAR
        info.minFilter    = VK_FILTER_LINEAR
        info.addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE
        info.addressModeV = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE
        info.addressModeW = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE
        let result = vkCreateSampler(device, &info, nil, &sampler)
        guard result == VK_SUCCESS else {
            throw CanvasShaderError.vulkan("vkCreateSampler failed: \(result.rawValue)")
        }
    }

    private func createDescriptorSet(imageView: VkImageView) throws {
        let sizes = [
            VkDescriptorPoolSize(type: VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER, descriptorCount: 1),
            VkDescriptorPoolSize(type: VK_DESCRIPTOR_TYPE_STORAGE_IMAGE,          descriptorCount: 1),
        ]
        let poolResult = sizes.withUnsafeBufferPointer { buf -> VkResult in
            var info = VkDescriptorPoolCreateInfo()
            info.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO
            info.maxSets = 1
            info.poolSizeCount = UInt32(buf.count)
            info.pPoolSizes = buf.baseAddress
            return vkCreateDescriptorPool(device, &info, nil, &descriptorPool)
        }
        guard poolResult == VK_SUCCESS else {
            throw CanvasShaderError.vulkan("vkCreateDescriptorPool failed: \(poolResult.rawValue)")
        }

        var set: VkDescriptorSet?
        let allocResult = withUnsafePointer(to: setLayout) { layoutPtr -> VkResult in
            var info = VkDescriptorSetAllocateInfo()
            info.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO
            info.descriptorPool = descriptorPool
            info.descriptorSetCount = 1
            info.pSetLayouts = layoutPtr
            return vkAllocateDescriptorSets(device, &info, &set)
        }
        guard allocResult == VK_SUCCESS, let set else {
            throw CanvasShaderError.vulkan("vkAllocateDescriptorSets failed: \(allocResult.rawValue)")
        }
        descriptorSet = set

        // Both bindings point at the node's canvas image, in GENERAL — the
        // layout the engine's pre-dispatch barrier moves the image into.
        var inputInfo = VkDescriptorImageInfo()
        inputInfo.sampler     = sampler
        inputInfo.imageView   = imageView
        inputInfo.imageLayout = VK_IMAGE_LAYOUT_GENERAL

        var outputInfo = VkDescriptorImageInfo()
        outputInfo.imageView   = imageView
        outputInfo.imageLayout = VK_IMAGE_LAYOUT_GENERAL

        withUnsafePointer(to: &inputInfo) { inputPtr in
            withUnsafePointer(to: &outputInfo) { outputPtr in
                var writeInput = VkWriteDescriptorSet()
                writeInput.sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET
                writeInput.dstSet = set
                writeInput.dstBinding = 0
                writeInput.descriptorCount = 1
                writeInput.descriptorType = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER
                writeInput.pImageInfo = inputPtr

                var writeOutput = VkWriteDescriptorSet()
                writeOutput.sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET
                writeOutput.dstSet = set
                writeOutput.dstBinding = 1
                writeOutput.descriptorCount = 1
                writeOutput.descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_IMAGE
                writeOutput.pImageInfo = outputPtr

                var writes = [writeInput, writeOutput]
                vkUpdateDescriptorSets(device, 2, &writes, 0, nil)
            }
        }
    }
}
