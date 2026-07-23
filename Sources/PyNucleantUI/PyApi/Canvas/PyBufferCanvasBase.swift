//
//  PyBufferCanvasBase.swift
//  PyNucleantUI
//
import NucleantVulkan
import PyNucleantBuffer
import PySwiftKit
import PySerializing
import PySwiftWrapper
import Foundation


/// The canvas over a `PyBufferShaderNode`: a fixed-resolution pixel
/// surface fed straight from Python's buffer protocol, with the same post-
/// shader slot the other canvases carry.
///
/// The sibling of `PixelBufferCanvasBase`, and the difference is the whole
/// point of it: `write` takes the producer object itself and reads it
/// through `PyObject_GetBuffer`, so anything exporting a buffer works —
/// `bytes`, `bytearray`, `memoryview`, numpy, ctypes, `array.array`, or an
/// extension type with a `bf_getbuffer` slot of its own::
///
///     canvas.write(nes.background_layer)     # no memoryview() wrapper
///
/// `PixelBufferCanvasBase.write` deserializes to `Data`, and `Data.casted`
/// switches on the concrete Python type — so a producer that *is* a buffer
/// gets rejected there unless the caller wraps it first. That canvas is
/// unchanged; this is the one to reach for when the producer is a buffer
/// object.
///
/// Like the pixel canvas and unlike `ThorCanvasBase`, the node never
/// resizes with the widget frame: the content resolution is intrinsic and
/// the composite pass scales the image to the window. Frame changes are
/// recorded but don't rebuild anything.
@PyClass(self_ref: true)
public final class PyBufferCanvasBase: PyCanvasBase {

    public var id: Int = UUID().hashValue

    /// Fixed content resolution, set at `__init__` — the size the producer
    /// writes, not the widget's on-screen size.
    public let contentWidth:  Int
    public let contentHeight: Int

    /// Integer up-scale of the node's image over the content size. The
    /// producer still writes contentWidth×contentHeight; the upload path
    /// nearest-blits up on the GPU, so a post shader sees a scale×-larger
    /// surface with real subpixels. 1 = the plain direct-copy path.
    public let contentScale: Int

    public typealias Node = PyBufferShaderNode<RenderNode>
    public private(set) var node: Node?
    /// The engine reference is the window's to supply — the one place this
    /// canvas touches NucleantVulkan is installing a compute post shader.
    /// nil until the window layer wires the handoff.
    public private(set) weak var engine: RenderEngine?

    /// Held strongly so the compiled pipeline survives even if Python drops
    /// its own reference — same contract as the other canvases.
    public var postShader: CanvasShader?

    /// The Swift-side producer hook, called once per rendered frame with
    /// the live node. Python producers go through `update_canvas` +
    /// `write` instead, which is the path this canvas kind exists for.
    public var onFrame: ((Node, Double) -> Void)?

    /// Recorded only — this canvas never resizes its node from the frame,
    /// so unlike `ThorCanvasBase` there is nothing to observe.
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

    /// This instance's Python identity — set once by tp_init; it *is* self,
    /// borrowed, never released.
    private var __self__: PyPointer

    /// Python hooks, mirroring the other canvases: nil when the subclass
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

    /// The window (engine owner) supplies its engine here before handing
    /// the built node down through `attach` — same sanctioned handoff as
    /// the other canvases (post shader / detach only; never used to build a
    /// node).
    func bind(engine: RenderEngine) {
        self.engine = engine
    }

    /// Bind into the render pipeline. A passive holder like the other
    /// canvases: the node is built by the engine-owning layer (via
    /// `RenderBinder`) and handed down as `ownNode`. The node is
    /// content-sized (contentWidth×contentHeight×scale), never sized from
    /// the widget frame.
    public func attach(
        ownNode: Node?,
        width:   Int,
        height:  Int
    ) {
        if let ownNode {
            node = ownNode
        }
        if let postShader, let engine, let node {
            do {
                try postShader.attach(engine: engine, node: node)
            } catch {
                print("PyBufferCanvasBase: pending post shader install failed: \(error)")
            }
        }
        if _on_canvas != nil {
            on_canvas()
        }
    }

    /// Undo `attach`: drop the shader's pipeline, then take the node out of
    /// the engine's composite list — `remove(id:)` frees the node's GPU
    /// resources on the way out.
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

    /// Hand a full frame of tightly-packed RGBA8 to the node, read directly
    /// out of `buffer` through the buffer protocol — no `memoryview()`
    /// wrapper, no `Data` round-trip. Raises `BufferError` if the object
    /// doesn't export a buffer.
    ///
    /// Short input fills what it covers; excess bytes are ignored. Silently
    /// a no-op before the node exists (nothing to upload into yet).
    @PyMethod
    func write(buffer: PyPointer) throws {
        guard let node else { return }
        guard node.write(buffer: buffer) else {
            throw PyStandardException.bufferError
        }
    }

    /// Install a post shader on this canvas's render node — same single
    /// slot + replacement semantics as the other canvases.
    @PyMethod
    func add_shader(index: Int, shader: PyPointer) throws {
        try setShader(shader)
    }

    /// Runtime replacement of the post pass: a `CanvasShader` swaps it in,
    /// None runs the pixels bare again.
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
