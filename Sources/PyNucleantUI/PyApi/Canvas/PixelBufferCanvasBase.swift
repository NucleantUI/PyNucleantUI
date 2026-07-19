//
//  PixelBufferCanvasBase.swift
//  PyNucleantUI
//
import SulphurCore
import SulphurVulkan
import PySwiftKit
import PySerializing
import PySwiftWrapper
import Foundation


/// The canvas over a CPU-fed `PixelBufferShaderNode`: a fixed-resolution
/// pixel surface some producer (the NES PPU, any software renderer)
/// fills every frame, with the same post-shader slot as the thor canvas.
/// Deliberately NES-free — the emulator side connects through `onFrame`,
/// keeping this module free of any emulator dependency (the widget's
/// canvas dispatch can only name types from this module, so the canvas
/// kind must live here; see `NucleantWidgetBase.canvas`).
///
/// Unlike `ThorCanvasBase`, the node never resizes with the widget frame:
/// the content resolution is intrinsic (256×240 for a NES), and the
/// composite pass scales the image to the window. Frame changes are
/// recorded but don't rebuild anything.
@PyClass(self_ref: true)
public final class PixelBufferCanvasBase: PyCanvasBase {

    public var id: Int = UUID().hashValue

    /// Fixed content resolution, set at `__init__` — the size the
    /// producer writes, not the widget's on-screen size.
    public let contentWidth:  Int
    public let contentHeight: Int

    /// Integer up-scale of the node's image over the content size. The
    /// producer still writes contentWidth×contentHeight; the upload path
    /// nearest-blits up on the GPU, so a post shader sees a scale×-larger
    /// surface with real subpixels. 1 = the plain old direct-copy path.
    public let contentScale: Int

    public private(set) var node: PixelBufferShaderNode?
    public private(set) weak var engine: VulkanRenderEngine?

    /// Held strongly so the compiled pipeline survives even if Python
    /// drops its own reference — same contract as `ThorCanvasBase`.
    public var postShader: CanvasShader?

    /// The producer hook, called once per rendered frame with the live
    /// node: step your machine, `write` your pixels. Installed Swift-side
    /// (e.g. `NesEmulator.connect`) — Python content goes through the
    /// `update_canvas` hook instead.
    public var onFrame: ((PixelBufferShaderNode, Double) -> Void)?

    /// Recorded only — a pixel canvas never resizes its node from the
    /// frame, so unlike `ThorCanvasBase` there is nothing to observe.
    private weak var _frame: NucleantFrame?
    public var frame: NucleantFrame? {
        get { _frame }
        set { _frame = newValue }
    }

    private weak var _owner: NucleantWidgetBase?
    public var owner: NucleantWidgetBase? {
        get { _owner }
        set {
            _owner = newValue
            frame = newValue?.frame
        }
    }

    /// This instance's Python identity — set once by tp_init; it *is*
    /// self, borrowed, never released.
    private var __self__: PyPointer

    /// Python hooks, mirroring `ThorCanvasBase`: nil when the subclass
    /// doesn't define them.
    let _on_canvas: PyPointer?
    let _update_canvas: PyPointer?

    @PyInit
    init(__self__: PyPointer, width: Int, height: Int, scale: Int) {
        self.__self__ = __self__
        self.contentWidth  = width
        self.contentHeight = height
        self.contentScale  = max(scale, 1)
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

    public var width:  Int { contentWidth }
    public var height: Int { contentHeight }

    public func attach(
        engine:  VulkanRenderEngine,
        wgpu:    WgpuContext,
        ownNode: ThorShaderNode?,
        width:   Int,
        height:  Int
    ) {
        self.engine = engine
        // ownNode is the window root's thor node — a pixel canvas can't
        // adopt it, so it is deliberately ignored; wgpu likewise (no
        // ThorVG texture behind this canvas).
        if node == nil {
            guard let built = try? engine.makePixelBufferNode(
                width:  contentWidth,
                height: contentHeight,
                scale:  contentScale
            ) else {
                print("PixelBufferCanvasBase: render node creation failed")
                return
            }
            node = built
            engine.append(.init(id: id, context: .pixel_buffer(built)))
        }
        if let postShader, let node {
            do {
                try postShader.attach(engine: engine, node: node)
            } catch {
                print("PixelBufferCanvasBase: pending post shader install failed: \(error)")
            }
        }
        if _on_canvas != nil {
            print("PixelBufferCanvasBase.attach: calling python on_canvas")
            on_canvas()
        }
        print("PixelBufferCanvasBase.attach: done")
    }

    public func detach() {
        // Keep the shader object (it reinstalls on re-attach), but its
        // pipeline points at this node's image — tear that down with it.
        postShader?.detach()
        if let node, let engine {
            engine.remove(id: id)
            engine.destroyResources(of: node)
        }
        node = nil
        owner = nil
    }

    public func on_render(dt: Double) {
        if let node {
            onFrame?(node, dt)
        }
        markDirty()
        if _update_canvas != nil {
            update_canvas(dt: dt)
        }
    }

    /// Flag the node for redraw this frame.
    public func markDirty() {
        node?.dirty = true
    }

    /// Python-facing pixel feed: hand a full frame of tightly-packed RGBA8
    /// bytes to the node. `buffer` accepts anything satisfying Python's
    /// buffer protocol — `bytes`, `bytearray`, or `memoryview` over any
    /// other buffer-protocol object (numpy, ctypes, array.array, …) — since
    /// `Data` deserializes from all three (see `PyDeserialize+Data.swift`).
    /// This is the generic counterpart to the Swift-side `onFrame` hook
    /// (e.g. `NesEmulator.connect`): any Python producer can call this
    /// directly without a dedicated Swift bridge of its own.
    @PyMethod
    func write(buffer: Data) {
        guard let node else { return }
        buffer.withUnsafeBytes { raw in
            node.write(pixels: raw)
        }
    }

    /// A pixel canvas carries no vector layer — paints have nowhere to
    /// land. Part of the `PyCanvasBase` contract, so scene canvases that
    /// resolve their host up the tree fail loudly instead of silently.
    public func add(paint: Tvg_Paint) {
        print("PixelBufferCanvasBase: add(paint:) ignored — no vector layer on a pixel canvas")
    }

    public func remove(paint: Tvg_Paint) {
        // Nothing was ever added; nothing to remove.
    }

    /// Install a post shader on this canvas's render node — same single
    /// slot + replacement semantics as `ThorCanvasBase.add_shader`.
    @PyMethod
    func add_shader(index: Int, shader: PyPointer) throws {
        try setShader(shader)
    }

    /// Runtime replacement of the post pass: a `CanvasShader` swaps it
    /// in, None runs the pixels bare again.
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
