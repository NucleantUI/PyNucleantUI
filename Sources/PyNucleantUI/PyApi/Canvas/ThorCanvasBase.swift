//
//  ThorCanvasBase.swift
//  PyNucleantUI
//
//import NucleantVulkan
import NucleantThorVG
import NucleantVulkan
import NucleantShader
import PySwiftKit
//import CWgpu
import PySerializing
import PySwiftWrapper
import Observation
import Dispatch
import Foundation



/// The canvas that talks to the render node. Owns the whole GPU side of
/// one widget's 2D content: the `ThorShaderNode` composited by the Vulkan
/// engine, the wgpu texture backing it, and any compute post shader.
/// Widgets never touch the render node — everything GPU-facing goes
/// through this object.
@PyClass(self_ref: true)
public final class ThorCanvasBase: PyCanvasBase, ThorHostCanvas ,ThorGPUCanvas, PyCapsuleProtocol {
    
    public var id: Int = UUID().hashValue

    public var base: Tvg_Canvas
    
    public typealias Node = ThorShaderNode<RenderNode>
    public private(set) var node: Node?
    //private var thorTexture: WGPUTexture?
    
    
    public private(set) weak var engine: RenderEngine?
    //public private(set) weak var wgpu: WgpuContext?

    /// Held strongly so the compiled pipeline survives even if Python
    /// drops its own reference.
    public var postShader: CanvasShader?
    
    private weak var _frame: NucleantFrame?
    public var frame: NucleantFrame? {
        get { _frame }
        set {
            _frame = newValue
            observeFrame()
            if let newValue {
                rebuildNode(width: Int(newValue.size.x), height: Int(newValue.size.y))
            }
        }
    }

    /// Invalidation token for frame observation. `withObservationTracking`
    /// registrations can't be cancelled — every (re)arm bumps this, and a
    /// stale onChange sees the mismatch and dies instead of acting on a
    /// frame this canvas no longer holds.
    private var frameObservationGeneration = 0

    /// Track in-place mutation of the frame (`frame.size = …`) — the
    /// path assignment doesn't cover. One registration fires once, so the
    /// handler re-arms after applying; nil frame just invalidates.
    private func observeFrame() {
        frameObservationGeneration &+= 1
        guard let frame = _frame else { return }
        let generation = frameObservationGeneration
        withObservationTracking {
            _ = frame.size
        } onChange: { [weak self] in
            // onChange fires at willSet — the new size isn't readable yet.
            // The main-queue hop reads it after the write lands and
            // coalesces a same-tick multi-field update into one rebuild.
            DispatchQueue.main.async {
                guard let self, generation == self.frameObservationGeneration else { return }
                if let frame = self._frame {
                    self.rebuildNode(width: Int(frame.size.x), height: Int(frame.size.y))
                }
                self.observeFrame()
            }
        }
    }

    private weak var _owner: PyWidgetBase?
    public var owner: PyWidgetBase? {
        get { _owner }
        set {
            _owner = newValue
            frame = newValue?.frame
        }
    }

    /// The frame-change path: replace the render node with one at the new
    /// size. The `base` canvas is adopted by the new node (ThorVG keeps
    /// its paints, Python-held capsules stay valid) and the post shader
    /// object survives — only its pipeline is rebuilt, since it points at
    /// the old node's image. Before `attach` this is a no-op: `attach`
    /// sizes the fresh node from the frame itself.
    private func rebuildNode(width: Int, height: Int) {
        // guard let engine, let wgpu, let oldNode = node else { return }
        // guard width > 0, height > 0,
        //       oldNode.width != UInt32(width) || oldNode.height != UInt32(height)
        // else { return }

        // // Build first — on failure the old node stays live and keeps
        // // drawing at the old size instead of the widget going dark.
        // guard let built = engine.makeWidgetNode(
        //     wgpu:     wgpu,
        //     width:    width,
        //     height:   height,
        //     adopting: base
        // ) else {
        //     print("PySulphurCanvasBase: node rebuild at \(width)x\(height) failed, keeping old size")
        //     return
        // }

        // // The shader object survives, but its pipeline points at the old
        // // node's image — take it down (drains the GPU with it) before the
        // // old node leaves the composite.
        // postShader?.detach()
        // // engine.replace(oldNode, with: built.node)
        // // ^ slots are id-keyed now: same canvas id, new node in the same
        // //   z-position.
        // engine.replace(id: id, with: .thor(built.node))

        // // makeWidgetNode retargeted `base` at the new texture, so the old
        // // texture and the old node's Vulkan image are only ours now.
        // engine.destroyResources(of: oldNode)
        // if let thorTexture {
        //     wgpu.release(texture: thorTexture)
        // }
        // node        = built.node
        // thorTexture = built.texture

        // if let postShader {
        //     do {
        //         try postShader.attach(engine: engine, node: built.node)
        //     } catch {
        //         print("PySulphurCanvasBase: post shader reinstall after resize failed: \(error)")
        //     }
        // }
        // markDirty()
    }



    /// This instance's Python identity — set once by tp_init; it *is*
    /// self, borrowed, never released.
    private var __self__: PyPointer

    /// Python draw hooks — the canvas is the Python-facing draw surface,
    /// so subclass hooks live here, not on the widget. nil when the
    /// subclass doesn't define them.
    let _on_canvas: PyPointer?
    let _update_canvas: PyPointer?

    /// A canvas starts with no render node. Assigning it to a widget's
    /// `canvas` attaches it — the widget hands the engine context through
    /// `attach`, which builds the node (or adopts the root's) then.
    @PyInit
    init(__self__: PyPointer) {
        self.base = tvg_wgcanvas_create(TVG_ENGINE_OPTION_DEFAULT)
        self.__self__ = __self__
        func optionalAttr(_ key: String) -> PyPointer? {
            PyObject_HasAttr(__self__, key) ? try? PyObject_GetAttr(__self__, key: key) : nil
        }
        _on_canvas = optionalAttr("on_canvas")
        _update_canvas = optionalAttr("update_canvas")
    }

    deinit {
        _on_canvas?.decRef()
        _update_canvas?.decRef()
    }

    @PyCall
    func on_canvas()

    @PyCall
    func update_canvas(dt: Double)

    public var width:  Int { node.map { Int($0.width)  } ?? 0 }
    public var height: Int { node.map { Int($0.height) } ?? 0 }

    /// The window (engine owner) supplies its engine here before handing the
    /// built node down through `attach` — same sanctioned handoff as the
    /// other canvases (post shader / detach only; never used to build a node).
    func bind(engine: RenderEngine) {
        self.engine = engine
    }



    /// Bind into the render pipeline. The canvas is a passive holder now:
    /// the render node is built by the engine-owning layer (the window) and
    /// handed down as `ownNode` — building it here was the engine's job in
    /// the old design and is deliberately gone (see rules: the canvas must
    /// not reach for the engine or webgpu to make a node).
    public func attach(
        ownNode: ThorShaderNode<RenderNode>?,
        width:   Int,
        height:  Int
    ) {
        // Re-resolve the owner's frame here — `owner` is usually set before
        // the widget is parented, so the pull at owner-set time couldn't
        // see frames inherited down the tree yet. Direct `_frame` write on
        // purpose (the setter's rebuild must not fire ahead of the ownNode
        // branch below), so observation is re-armed by hand.
        if let ownerFrame = owner?.frame {
            _frame = ownerFrame
            observeFrame()
        }
        if let ownNode {
            // Adopt the node the window handed down: take over its ThorVG
            // canvas so capsules Python took after __init__ stay valid.
            base = ownNode.canvas.base
            node = ownNode
        } else if node == nil {
            // TODO(refactor): no node yet, and creating one is not this
            // canvas's job — the window (which owns the engine) builds the
            // node and re-attaches with it as `ownNode`. Until that handoff
            // is wired the canvas simply waits with no node.
        } else if let frame = _frame {
            // Already-built node re-attaching under a frame that changed
            // while detached — same path as a live frame change.
            rebuildNode(width: Int(frame.size.x), height: Int(frame.size.y))
        }
        // A shader assigned before the node existed waits here — install it
        // once there is both a node and an engine to install through. The
        // engine reference is the window's to supply (post shaders are the
        // one place the canvas legitimately touches NucleantVulkan).
        if let postShader, let engine, let node {
            do {
                try postShader.attach(
                    engine: engine,
                    node:   node
                )
            } catch {
                print("ThorCanvasBase: pending post shader install failed: \(error)")
            }
        }
        if _on_canvas != nil {
            on_canvas()
        }
    }

    /// Pull the node out of the engine's composite list and drop the GPU
    /// resources — called when the owning widget leaves the tree, so a
    /// stale image doesn't keep drawing every frame.
    public func detach() {
        // Keep the shader object (it reinstalls on re-attach), but its
        // pipeline points at this node's image — tear that down with it.
        postShader?.detach()
        if node != nil, let engine {
            // engine.remove(node)
            engine.remove(id: id)
        }
        node = nil
        // thorTexture = nil // this belongs in the ShaderNode not here
        owner = nil
    }

    public func on_render(dt: Double) {
        markDirty()
        if _update_canvas != nil {
            update_canvas(dt: dt)
        }
    }

    /// Flag the node for redraw this frame.
    public func markDirty() {
        node?.dirty = true
    }

    public func add(paint: Tvg_Paint) {
        _ = add(shape: paint)
        markDirty()
    }

    public func remove(paint: Tvg_Paint) {
        _ = remove(shape: paint)
        markDirty()
    }

    public func asCapsule() -> PyPointer {
        return PyCapsule_New(.init(base), cString("Tvg_Canvas")) { object in
            //object?.deallocate()
        }
    }

    @PyMethod
    func tvg_canvas_capsule() -> PyPointer {
        asCapsule()
    }

    /// Install a post shader on this canvas's render node. Only one post
    /// shader is supported for now — `index` is accepted to match the
    /// Python `CanvasBase` protocol but ignored, and a second call
    /// replaces the first shader.
    @PyMethod
    func add_shader(index: Int, shader: PyPointer) throws {
        try setShader(shader)
    }

    /// Runtime replacement of the post pass: pass a `CanvasShader` to swap
    /// it in, or None to run the canvas bare again. Assigning before the
    /// canvas has its render node just stores the shader — `attach`
    /// installs it once the node exists.
    @PyMethod
    func update_shader(shader: PyPointer) throws {
        try setShader(shader)
    }

    /// One replacement path for both entry points: the outgoing shader is
    /// detached first (GPU drained, node's compute slots cleared) so its
    /// pipeline is never destroyed behind an in-flight command buffer.
    private func setShader(_ shader: PyPointer) throws {
        if shader == .None {
            postShader?.detach()
            postShader = nil
            return
        }
        let post: CanvasShader = try .casted(from: shader)
        if let old = postShader, old !== post {
            old.detach()
        }
        postShader = post
        guard let engine, let node else { return }
        try post.attach(
            engine: engine,
            node: node
        )
    }

    public func pyPointer() -> PyPointer {
        __self__.newRef
    }
}
