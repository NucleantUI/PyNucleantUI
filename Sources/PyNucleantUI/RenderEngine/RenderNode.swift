//
//  RenderNode.swift
//  PyNucleantUI
//


import QuartzCore
import SulphurVulkan
import VulkanCore
import CVulkan
import SulphurCore
import SulphurShader
import CWgpu
import Observation
#if canImport(SulphurApplication)
import SulphurApplication
#endif


// MARK: - Node type

// public struct RenderNode {
// ^ promoted to a class: the slot carries mutable engine-facing state
//   (`needsRender`) fed by Observation tracking, which a value copy would
//   silently fork.

/// One composite slot in the engine's `nodes` list. `id` is the stable
/// identity shared with the canvas side (the owning `PyCanvasBase.id`,
/// a `UUID().hashValue`) — every engine-internal map (descriptor sets,
/// readable state, warn-once markers) is keyed by it.
///
/// The slot watches its shader node through the Observation framework:
/// canvas code mutates its own node (`dirty`, compute pipeline swap) and
/// `needsRender` flips here, so neither the canvas nor the shader node
/// ever needs a reference back to the slot or the engine's list.
public final class RenderNode {
    public let id: Int

    public let context: Context

    /// Consumed by the engine: checked at the top of the per-frame node
    /// update and cleared after a successful draw. Starts `true` so a
    /// fresh slot renders its first frame unprompted.
    var needsRender: Bool = true

    init(id: Int, context: Context) {
        self.id = id
        self.context = context
        observeContext()
    }

    private func observeContext() {
        switch context {
        case .thor(let node):
            observe(node)
        case .skia(let node):
            observe(node)
        case .shader(let node):
            observe(node)
        case .group, .texture_group:
            // No observable payload of their own — a group's children are
            // RenderNodes tracking themselves, and texture groups aren't
            // driven by anything yet.
            break
        }
    }

    /// Arm one observation over the node's render-affecting state. A
    /// registration fires exactly once, so `onChange` re-arms; `node` is
    /// captured weakly because the node's registrar holds this closure —
    /// a strong capture would be a self-retain-cycle on the node.
    private func observe<Node: VulkanRenderNode & Observable>(_ node: Node) {
        withObservationTracking { [weak node] in
            guard let node else { return }
            _ = node.dirty
            _ = node.computePipeline
            _ = node.computeLayout
            _ = node.computeDescriptorSet
        } onChange: { [weak self, weak node] in
            guard let self, let node else { return }
            self.needsRender = true
            self.observe(node)
        }
    }
}
