//
//  SkiaCanvasBase.swift
//  PyNucleantUI
//
import NucleantVulkan
import NucleantSkia
import PySwiftKit
import PySerializing
import PySwiftWrapper
import Observation
import Dispatch
import Foundation


/// The Skia counterpart of `ThorCanvasBase`: owns the widget-facing side of
/// one widget's Skia-drawn 2D content — the `SkiaShaderNode` composited by
/// the Vulkan engine and any compute post shader. Widgets never touch the
/// render node; everything GPU-facing goes through this object.
///
/// Like the thor canvas after the refactor this is a *passive* holder: the
/// render node (and the Ganesh context/surface behind it) is built by the
/// engine-owning layer — the window — and handed down as `ownNode`. Building
/// it here was the engine's job in the old design and is deliberately gone
/// (see rules: a canvas must not reach for the engine or webgpu to make a
/// node).
///
/// Python draws two ways: the basic draw/text methods here, or — the real
/// path — skia-python on the raw `SkSurface*` from `skia_surface_capsule()`.
/// The surface lives on the node's VkImage, so take the capsule inside
/// `on_canvas` or later, and re-take it after any resize.
@PyClass(self_ref: true)
public final class SkiaCanvasBase: PyCanvasBase, SkiaGPUCanvas, PyCapsuleProtocol {

    public var id: Int = UUID().hashValue

    public typealias Node = SkiaShaderNode<RenderNode>
    public private(set) var node: Node?

    /// The engine reference is the window's to supply — the one place a
    /// canvas legitimately touches NucleantVulkan is installing a compute
    /// post shader (ShaderCode part of the render api). nil until the window
    /// layer wires the handoff.
    public private(set) weak var engine: RenderEngine?

    /// Held strongly so the compiled pipeline survives even if Python drops
    /// its own reference — same contract as `ThorCanvasBase`.
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

    /// Invalidation token for frame observation — same scheme as
    /// `ThorCanvasBase`: registrations can't be cancelled, every (re)arm
    /// bumps this and a stale onChange dies on the mismatch.
    private var frameObservationGeneration = 0

    private func observeFrame() {
        frameObservationGeneration &+= 1
        guard let frame = _frame else { return }
        let generation = frameObservationGeneration
        withObservationTracking {
            _ = frame.size
        } onChange: { [weak self] in
            // onChange fires at willSet — read the new size after the
            // write lands, coalescing same-tick multi-field updates.
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

    /// The frame-change path. Rebuilding the render node at a new size is
    /// the window layer's job now (it owns the engine and the Ganesh
    /// context); this canvas only records the new frame and waits for the
    /// window to hand a resized node back down through `attach`.
    private func rebuildNode(width: Int, height: Int) {
        // TODO(refactor): node rebuild on resize belongs to the engine-owning
        // window layer, which re-attaches with the resized `ownNode`.
    }

    /// This instance's Python identity — set once by tp_init; it *is* self,
    /// borrowed, never released.
    private var __self__: PyPointer

    /// Python draw hooks — nil when the subclass doesn't define them.
    let _on_canvas: PyPointer?
    let _update_canvas: PyPointer?

    /// A canvas starts with no render node — and, unlike the thor canvas,
    /// no drawable surface either: Skia needs the node's VkImage, which only
    /// exists once the window hands a node down.
    @PyInit
    init(__self__: PyPointer) {
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
    /// built node down through `attach`. This is the one place a canvas
    /// legitimately holds a NucleantVulkan reference — it's needed to install
    /// a compute post shader and to pull the node out of the composite list
    /// on `detach`. The canvas never uses it to *build* a node.
    func bind(engine: RenderEngine) {
        self.engine = engine
    }

    /// Bind into the render pipeline. The render node is built by the
    /// window (which owns the engine and the Ganesh context) and handed
    /// down as `ownNode`.
    public func attach(
        ownNode: SkiaShaderNode<RenderNode>?,
        width:   Int,
        height:  Int
    ) {
        // Re-resolve the owner's frame — same reasoning as ThorCanvasBase.
        if let ownerFrame = owner?.frame {
            _frame = ownerFrame
            observeFrame()
        }
        if let ownNode {
            node = ownNode
        } else if node == nil {
            // TODO(refactor): no node yet, and creating one (plus its Ganesh
            // context) is the window's job — it re-attaches with `ownNode`.
        } else if let frame = _frame {
            rebuildNode(width: Int(frame.size.x), height: Int(frame.size.y))
        }
        // A shader assigned before the node existed waits here — install it
        // once there is both a node and an engine to install through.
        if let postShader, let engine, let node {
            do {
                try postShader.attach(engine: engine, node: node)
            } catch {
                print("SkiaCanvasBase: pending post shader install failed: \(error)")
            }
        }
        if _on_canvas != nil {
            on_canvas()
        }
    }

    /// Undo `attach`: drop the shader's pipeline, then take the node out of
    /// the engine's composite list — `remove(id:)` frees the node's GPU
    /// resources (surface, image/view/memory) on the way out.
    public func detach() {
        postShader?.detach()
        if node != nil, let engine {
            engine.remove(id: id)
        }
        node = nil
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

    // MARK: - Capsule handoff (skia-python)

    /// The raw `SkSurface*` as a PyCapsule named "SkSurface" — what the
    /// skia-python fork adopts to draw on this canvas from Python. Borrowed
    /// pointer, no destructor: the surface's lifetime belongs to the node,
    /// and a rebuild (resize) invalidates old capsules.
    public func asCapsule() -> PyPointer {
        guard let pointer = node?.canvas.surface?.skSurfacePointer() else {
            return .None
        }
        return PyCapsule_New(pointer, cString("SkSurface")) { _ in }
    }

    @PyMethod
    func skia_surface_capsule() -> PyPointer {
        asCapsule()
    }

    // MARK: - Basic draw (no skia-python needed)

    @PyMethod
    func clear(r: Double, g: Double, b: Double, a: Double) {
        node?.canvas.surface?.clear(r: Float(r), g: Float(g), b: Float(b), a: Float(a))
        markDirty()
    }

    @PyMethod
    func draw_rect(x: Double, y: Double, w: Double, h: Double, r: Double, g: Double, b: Double, a: Double) {
        node?.canvas.surface?.drawRect(
            x: Float(x), y: Float(y), width: Float(w), height: Float(h),
            r: Float(r), g: Float(g), b: Float(b), a: Float(a)
        )
        markDirty()
    }

    @PyMethod
    func draw_round_rect(x: Double, y: Double, w: Double, h: Double, radius: Double, r: Double, g: Double, b: Double, a: Double) {
        node?.canvas.surface?.drawRoundRect(
            x: Float(x), y: Float(y), width: Float(w), height: Float(h), radius: Float(radius),
            r: Float(r), g: Float(g), b: Float(b), a: Float(a)
        )
        markDirty()
    }

    @PyMethod
    func draw_circle(cx: Double, cy: Double, radius: Double, r: Double, g: Double, b: Double, a: Double) {
        node?.canvas.surface?.drawCircle(
            cx: Float(cx), cy: Float(cy), radius: Float(radius),
            r: Float(r), g: Float(g), b: Float(b), a: Float(a)
        )
        markDirty()
    }

    @PyMethod
    func draw_line(x0: Double, y0: Double, x1: Double, y1: Double, stroke_width: Double, r: Double, g: Double, b: Double, a: Double) {
        node?.canvas.surface?.drawLine(
            x0: Float(x0), y0: Float(y0), x1: Float(x1), y1: Float(y1), strokeWidth: Float(stroke_width),
            r: Float(r), g: Float(g), b: Float(b), a: Float(a)
        )
        markDirty()
    }

    @PyMethod
    func draw_text(text: String, x: Double, y: Double, size: Double, r: Double, g: Double, b: Double, a: Double) {
        node?.canvas.surface?.drawText(
            text, x: Float(x), y: Float(y), size: Float(size),
            r: Float(r), g: Float(g), b: Float(b), a: Float(a)
        )
        markDirty()
    }

    @PyMethod
    func text_width(text: String, size: Double) -> Double {
        Double(skiaTextWidth(text, size: Float(size)))
    }

    // MARK: - Post shader

    /// Install a post shader on this canvas's render node — same single slot
    /// + replacement semantics as `ThorCanvasBase.add_shader`.
    @PyMethod
    func add_shader(index: Int, shader: PyPointer) throws {
        try setShader(shader)
    }

    /// Runtime replacement of the post pass: a `CanvasShader` swaps it in,
    /// None runs the canvas bare again.
    @PyMethod
    func update_shader(shader: PyPointer) throws {
        try setShader(shader)
    }

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
        try post.attach(engine: engine, node: node)
    }

    public func pyPointer() -> PyPointer {
        __self__.newRef
    }
}
