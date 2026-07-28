//
//  PixelBufferCanvasBase.swift
//  PyNucleantUI
//
//import NucleantVulkan
import NucleantVulkan
import PySwiftKit
import PySerializing
import PySwiftWrapper
import Foundation
import PyNucleantUI
import PNU_Layout

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
public final class PixelBufferCanvasBase: PyCanvasBase, @unchecked Sendable {

    public let id: Int = UUID().hashValue

    /// Fixed content resolution, set at `__init__` — the size the
    /// producer writes, not the widget's on-screen size.
    public let contentWidth:  Int
    public let contentHeight: Int

    /// Integer up-scale of the node's image over the content size. The
    /// producer still writes contentWidth×contentHeight; the upload path
    /// nearest-blits up on the GPU, so a post shader sees a scale×-larger
    /// surface with real subpixels. 1 = the plain old direct-copy path.
    public let contentScale: Int

    public typealias Node = PixelBufferShaderNode<RenderNode<NucleantFrame>>
    public private(set) var node: Node?
    /// The engine reference is the window's to supply — the one place a
    /// pixel canvas touches NucleantVulkan is installing a compute post
    /// shader. nil until the window layer wires the handoff.
    public private(set) weak var engine: RenderEngine?

    /// Held strongly so the compiled pipeline survives even if Python
    /// drops its own reference — same contract as `ThorCanvasBase`.
    public var postShader: CanvasShader?

    /// The producer hook, called once per rendered frame with the live
    /// node: step your machine, `write` your pixels. Installed Swift-side
    /// (e.g. `NesEmulator.connect`) — Python content goes through the
    /// `update_canvas` hook instead.
    public var onFrame: ((Node, Double) -> Void)?

    /// Recorded only — a pixel canvas never resizes its node from the
    /// frame, so unlike `ThorCanvasBase` there is nothing to observe.
    private weak var _frame: NucleantFrame?
    public var frame: NucleantFrame? {
        get { _frame }
        set { _frame = newValue }
    }

    private weak var _owner: PyWidgetBase?
    public var owner: PyWidgetBase? {
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

    /// The window (engine owner) supplies its engine here before handing the
    /// built node down through `attach` — same sanctioned handoff as the
    /// other canvases (post shader / detach only; never used to build a node).
    func bind(engine: RenderEngine) {
        self.engine = engine
    }




    /// Bind into the render pipeline. Like the thor/skia canvases after the
    /// refactor this is a passive holder: the CPU-fed render node is built
    /// by the engine-owning layer (the window) and handed down as `ownNode`
    /// — building it here was the engine's job in the old design and is
    /// deliberately gone (see rules). The node is content-sized
    /// (contentWidth×contentHeight×scale), not sized from the widget frame.
    public func attach(
        ownNode: Node?,
        width:   Int,
        height:  Int
    ) {
        if let ownNode {
            node = ownNode
        } else if node == nil {
            // TODO(refactor): no node yet, and creating one is not this
            // canvas's job — the window builds the content-sized
            // PixelBufferShaderNode and re-attaches with it as `ownNode`.
        }
        if let postShader, let engine, let node {
            do {
                try postShader.attach(engine: engine, node: node)
            } catch {
                print("PixelBufferCanvasBase: pending post shader install failed: \(error)")
            }
        }
        if _on_canvas != nil {
            on_canvas()
        }
    }

    /// Undo `attach`: drop the shader's pipeline, then take the node out of
    /// the engine's composite list — `remove(id:)` frees the node's GPU
    /// resources (staging buffer, image/view/memory, upload image) on the
    /// way out.
    public func detach() {
        postShader?.detach()
        if node != nil, let engine {
            engine.remove(id: id)
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
