//
//  SkiaCanvasBase.swift
//  PyNucleantUI
//
//  Created by CodeBuilder on 19/07/2026.
//
import SulphurCore
import SulphurVulkan
import PySwiftKit
import PySerializing
import PySwiftWrapper
import SkiaCore
import Observation
import Dispatch
import Foundation


/// The Skia counterpart of `ThorCanvasBase`: owns the whole GPU side of
/// one widget's Skia-drawn 2D content — the `SkiaShaderNode` composited
/// by the Vulkan engine, the Ganesh context/surface behind it, and any
/// compute post shader. Widgets never touch the render node; everything
/// GPU-facing goes through this object.
///
/// Python draws two ways: the basic draw/text methods here, or — the
/// real path — skia-python on the raw `SkSurface*` from
/// `skia_surface_capsule()`. The surface only exists once the canvas is
/// attached (it wraps the render node's VkImage), so take the capsule
/// inside `on_canvas` or later, and re-take it after any resize — the
/// node rebuild replaces the surface.
@PyClass(self_ref: true)
public final class SkiaCanvasBase: PyCanvasBase, SkiaGPUCanvas, PyCapsuleProtocol {

    public var id: Int = UUID().hashValue

    /// One Ganesh context per canvas, created lazily at first attach and
    /// kept across node rebuilds (only the surface tracks the VkImage).
    public private(set) var context: SkiaVulkanContext?

    public private(set) var node: SkiaShaderNode?

    public private(set) weak var engine: VulkanRenderEngine?

    /// Held strongly so the compiled pipeline survives even if Python
    /// drops its own reference — same contract as `ThorCanvasBase`.
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

    private weak var _owner: NucleantWidgetBase?
    public var owner: NucleantWidgetBase? {
        get { _owner }
        set {
            _owner = newValue
            frame = newValue?.frame
        }
    }

    /// The frame-change path: replace the render node with one at the new
    /// size. The Ganesh context survives; the surface does not — it wraps
    /// the old node's VkImage, so Python must re-take its capsule after a
    /// resize. Before `attach` this is a no-op: `attach` sizes the fresh
    /// node from the frame itself.
    private func rebuildNode(width: Int, height: Int) {
        guard let engine, let context, let oldNode = node else { return }
        guard width > 0, height > 0,
              oldNode.width != UInt32(width) || oldNode.height != UInt32(height)
        else { return }

        // Build first — on failure the old node stays live and keeps
        // drawing at the old size instead of the widget going dark.
        guard let built = engine.makeSkiaWidgetNode(
            context: context,
            width:   width,
            height:  height
        ) else {
            print("SkiaCanvasBase: node rebuild at \(width)x\(height) failed, keeping old size")
            return
        }

        // The shader object survives, but its pipeline points at the old
        // node's image — take it down (drains the GPU with it) before the
        // old node leaves the composite.
        postShader?.detach()
        engine.replace(id: id, with: .skia(built))
        engine.destroyResources(of: oldNode)
        node = built

        if let postShader {
            do {
                try postShader.attach(engine: engine, node: built)
            } catch {
                print("SkiaCanvasBase: post shader reinstall after resize failed: \(error)")
            }
        }
        if _on_canvas != nil {
            // The old surface (and everything Python drew on it) is gone —
            // give the Python side its redraw hook on the fresh surface.
            on_canvas()
        }
        markDirty()
    }

    /// This instance's Python identity — set once by tp_init; it *is*
    /// self, borrowed, never released.
    private var __self__: PyPointer

    /// Python draw hooks — nil when the subclass doesn't define them.
    let _on_canvas: PyPointer?
    let _update_canvas: PyPointer?

    /// A canvas starts with no render node — and, unlike the thor canvas,
    /// no drawable surface either: Skia needs the node's VkImage, which
    /// only exists after `attach`.
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

    /// Explicit witness for the `VulkanRenderNode?`-erased requirement:
    /// without this, `PyCanvasBase`'s generic default (`ownNode as? Node`)
    /// resolves back to itself instead of this concrete overload —
    /// infinite recursion, stack overflow, no error printed. `ThorCanvasBase`
    /// carries the same override for the same reason.
    public func attach(
        engine:  VulkanRenderEngine,
        wgpu:    WgpuContext,
        ownNode: VulkanRenderNode?,
        width:   Int,
        height:  Int
    ) {
        attach(engine: engine, wgpu: wgpu, ownNode: ownNode as? SkiaShaderNode, width: width, height: height)
    }

    public func attach(
        engine:  VulkanRenderEngine,
        wgpu:    WgpuContext,
        ownNode: SkiaShaderNode?,
        width:   Int,
        height:  Int
    ) {
        self.engine = engine
        // wgpu and the root's thor node are deliberately ignored — a Skia
        // canvas renders on the engine's own device/queue, nothing wgpu.
        if let ownerFrame = owner?.frame {
            // Same re-resolve as ThorCanvasBase.attach: direct `_frame`
            // write so the setter's rebuild can't fire before the node
            // exists; observation re-armed by hand.
            _frame = ownerFrame
            observeFrame()
        }
        if context == nil {
            do {
                context = try engine.makeSkiaContext()
            } catch {
                print("SkiaCanvasBase: skia context creation failed: \(error)")
                return
            }
        }
        if node == nil, let context {
            // The frame wins over the tree-attach size; without one the
            // canvas keeps adapting to the nearest parent size.
            let width  = _frame.map { Int($0.size.x) } ?? width
            let height = _frame.map { Int($0.size.y) } ?? height
            guard let built = engine.makeSkiaWidgetNode(
                context: context,
                width:   width,
                height:  height
            ) else {
                print("SkiaCanvasBase: render node creation failed")
                return
            }
            node = built
            engine.append(.init(id: id, context: .skia(built)))
        } else if let frame = _frame {
            // Already-built node re-attaching under a frame that changed
            // while detached — same path as a live frame change.
            rebuildNode(width: Int(frame.size.x), height: Int(frame.size.y))
        }
        // A shader assigned before the node existed waits here — install
        // it now that there is something to install on.
        if let postShader, let node {
            do {
                try postShader.attach(
                    engine: engine,
                    node:   node
                )
            } catch {
                print("SkiaCanvasBase: pending post shader install failed: \(error)")
            }
        }
        if _on_canvas != nil {
            on_canvas()
        }
    }

    /// Pull the node out of the engine's composite list and drop the GPU
    /// resources — the surface first (Skia's views onto the VkImage),
    /// then image/view/memory. The Ganesh context stays for re-attach.
    public func detach() {
        postShader?.detach()
        if let node, let engine {
            engine.remove(id: id)
            engine.destroyResources(of: node)
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

    /// A Skia canvas carries no ThorVG layer — paints have nowhere to
    /// land. Part of the `PyCanvasBase` contract, so scene canvases that
    /// resolve their host up the tree fail loudly instead of silently.
    public func add(paint: Tvg_Paint) {
        print("SkiaCanvasBase: add(paint:) ignored — no ThorVG layer on a skia canvas")
    }

    public func remove(paint: Tvg_Paint) {
        // Nothing was ever added; nothing to remove.
    }

    // MARK: - Capsule handoff (skia-python)

    /// The raw `SkSurface*` as a PyCapsule named "SkSurface" — what the
    /// skia-python fork adopts to draw on this canvas from Python.
    /// Borrowed pointer, no destructor: the surface's lifetime belongs to
    /// this canvas, and a rebuild (resize) invalidates old capsules.
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
        node?.canvas.surface?.clear(
            r: Float(r),
            g: Float(g),
            b: Float(b),
            a: Float(a)
        )
        markDirty()
    }

    @PyMethod
    func draw_rect(x: Double, y: Double, w: Double, h: Double, r: Double, g: Double, b: Double, a: Double) {
        node?.canvas.surface?.drawRect(
            x: Float(x),
            y: Float(y),
            width: Float(w),
            height: Float(h),
            r: Float(r),
            g: Float(g),
            b: Float(b),
            a: Float(a)
        )
        markDirty()
    }

    @PyMethod
    func draw_round_rect(x: Double, y: Double, w: Double, h: Double, radius: Double, r: Double, g: Double, b: Double, a: Double) {
        node?.canvas.surface?.drawRoundRect(
            x: Float(x),
            y: Float(y),
            width: Float(w),
            height: Float(h),
            radius: Float(radius),
            r: Float(r),
            g: Float(g),
            b: Float(b),
            a: Float(a)
        )
        markDirty()
    }

    @PyMethod
    func draw_circle(cx: Double, cy: Double, radius: Double, r: Double, g: Double, b: Double, a: Double) {
        node?.canvas.surface?.drawCircle(
            cx: Float(cx),
            cy: Float(cy),
            radius: Float(radius),
            r: Float(r),
            g: Float(g),
            b: Float(b),
            a: Float(a)
        )
        markDirty()
    }

    @PyMethod
    func draw_line(x0: Double, y0: Double, x1: Double, y1: Double, stroke_width: Double, r: Double, g: Double, b: Double, a: Double) {
        node?.canvas.surface?.drawLine(
            x0: Float(x0),
            y0: Float(y0),
            x1: Float(x1),
            y1: Float(y1),
            strokeWidth: Float(stroke_width),
            r: Float(r),
            g: Float(g),
            b: Float(b),
            a: Float(a)
        )
        markDirty()
    }

    @PyMethod
    func draw_text(text: String, x: Double, y: Double, size: Double, r: Double, g: Double, b: Double, a: Double) {
        node?.canvas.surface?.drawText(
            text,
            x: Float(x),
            y: Float(y),
            size: Float(size),
            r: Float(r),
            g: Float(g),
            b: Float(b),
            a: Float(a)
        )
        markDirty()
    }

    @PyMethod
    func text_width(text: String, size: Double) -> Double {
        Double(skiaTextWidth(
            text,
            size: Float(size)
        ))
    }

    // MARK: - Post shader

    /// Install a post shader on this canvas's render node — same single
    /// slot + replacement semantics as `ThorCanvasBase.add_shader`.
    @PyMethod
    func add_shader(index: Int, shader: PyPointer) throws {
        try setShader(shader)
    }

    /// Runtime replacement of the post pass: a `CanvasShader` swaps it
    /// in, None runs the canvas bare again.
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
        try post.attach(
            engine: engine,
            node: node
        )
    }

    public func pyPointer() -> PyPointer {
        __self__.newRef
    }
}
