//
//  CanvasBase.swift
//  SulphurXcodeDemo
//
import SulphurCore
import SulphurVulkan
import PySwiftKit
import CWgpu
import PySerializing
import PySwiftWrapper


/// The general canvas contract — the one thing a widget holds and drives.
/// A widget's `canvas` slot is `any PyCanvasBase`, so the same slot takes
/// the render-node canvas (`PySulphurCanvasBase`) or the scene one
/// (`PySulphurSceneBase`); the widget never knows which. Each
/// implementation decides what `attach` means: build/adopt a render node,
/// or hook a scene into the nearest canvas up the tree.
public protocol PyCanvasBase: PySerializable, PyClassProtocol, AnyObject {

    /// The widget holding this canvas. Canvases record their owner and
    /// widgets their parent — that chain is how nested scene canvases find
    /// the canvas they composite through.
    var owner: SulphurWidgetBase? { get set }

    /// Bind into the render pipeline. Node canvases build (or adopt
    /// `ownNode`) their render node here; scene canvases resolve the
    /// nearest ancestor canvas and add themselves to it — the engine
    /// context is theirs to ignore.
    func attach(
        engine:  VulkanRenderEngine,
        wgpu:    WgpuContext,
        ownNode: ThorShaderNode?,
        width:   Int,
        height:  Int
    )

    /// Undo `attach`: node canvases leave the composite list, scene
    /// canvases take their paint back off the host.
    func detach()

    /// Per-frame tick from the owning widget: flag for redraw and drive
    /// this canvas's own Python `update_canvas` hook if it has one.
    func on_render(dt: Double)

    /// Flag for redraw this frame.
    func markDirty()

    /// Add / remove 2D content. Canvas-level add on node canvases,
    /// scene-level add on scene canvases — this is what lets scenes nest
    /// through whichever canvas kind they land on.
    func add(paint: Tvg_Paint)
    func remove(paint: Tvg_Paint)
}


/// The canvas that talks to the render node. Owns the whole GPU side of
/// one widget's 2D content: the `ThorShaderNode` composited by the Vulkan
/// engine, the wgpu texture backing it, and any compute post shader.
/// Widgets never touch the render node — everything GPU-facing goes
/// through this object.
@PyClass(self_ref: true)
public final class PySulphurCanvasBase: PyCanvasBase, ThorGPUCanvas, PyCapsuleProtocol {

    public var base: Tvg_Canvas

    public private(set) var node: ThorShaderNode?
    private var thorTexture: WGPUTexture?

    public private(set) weak var engine: VulkanRenderEngine?
    public private(set) weak var wgpu: WgpuContext?

    /// Held strongly so the compiled pipeline survives even if Python
    /// drops its own reference.
    public var postShader: CanvasShader?

    public weak var owner: SulphurWidgetBase?

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

    public func attach(
        engine:  VulkanRenderEngine,
        wgpu:    WgpuContext,
        ownNode: ThorShaderNode?,
        width:   Int,
        height:  Int
    ) {
        self.engine = engine
        self.wgpu = wgpu
        if let ownNode {
            base = ownNode.canvas.base
            node = ownNode
        } else if node == nil {
            // The node adopts this canvas's own `base` — created at @PyInit —
            // so capsules Python took right after __init__ stay valid.
            guard let built = engine.makeWidgetNode(
                wgpu:     wgpu,
                width:    width,
                height:   height,
                adopting: base
            ) else {
                print("PySulphurCanvasBase: render node creation failed")
                return
            }
            node        = built.node
            thorTexture = built.texture
            engine.append(.node(built.node))
        }
        // A shader assigned before the node existed waits here — install it
        // now that there is something to install on.
        if let postShader, let node {
            do {
                try postShader.attach(
                    engine: engine,
                    node:   node
                )
            } catch {
                print("PySulphurCanvasBase: pending post shader install failed: \(error)")
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
        if let node, let engine {
            engine.remove(node)
        }
        node = nil
        thorTexture = nil
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
