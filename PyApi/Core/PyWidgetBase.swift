//
//  SulphurWidgetBase.swift
//
@preconcurrency import PySwiftKit
import PySerializing
import PySwiftWrapper
import PyNucleantUI
import PNU_Layout

import NucleantVulkan
import Foundation
import Observation






@PyClass(
    external: false,
    self_ref: true,
    swift_mode: .v6
)
//@PyContainer(weak_ref: true)
/*
 when both PyClass and PyContainer combined
 class is just by default inited with instance of pyobject wrap of itself
 weak_ref is true, soo it doesnt hold ref to itself
 but allows us to use the @PyCall macro for calling
 functions added to the object when inherit it...
*/
/// The attachment side of the tree: parenting, child bookkeeping, and
/// handing the engine/wgpu context down. A widget never touches a render
/// node — it holds one `any PyCanvasBase`, whichever kind: the render-node
/// canvas or a scene canvas. Drawing is entirely the canvas's business
/// (its Python hooks live on the canvas object); assign no canvas and the
/// widget is a pure container for other widgets.
public final class PyWidgetBase: PyWidgetProtocol, PySerializable, PyClassProtocol, @unchecked Sendable {
    
    

    public var __self__: PyPointer
    
    /// The widget's one and only frame. Defaults to a both-axes flexible
    /// frame, so a widget that never sets one is sized by the layout — it
    /// takes the remaining parent space (SwiftUI's no-frame behaviour)
    /// instead of inheriting the parent's frame as a fixed size. Assigning
    /// `frame = None` from Python resets it back to flexible.
    private var _frame: NucleantFrame? = NucleantFrame(flexible: .zero)

    @PyProperty
    public var frame: NucleantFrame? {
        get { _frame }
        set {
            _frame = newValue //?? NucleantFrame(flexible: .zero)
            // On a live node canvas, handing the (possibly just-reset) frame
            // down is what triggers the render-node resize.
            _canvas?.setFrame(newValue)
            // Container size changed → re-place children under any layout.
            runLayout()
        }
    }

    var _canvas: (any PyCanvasBase)?//(any PyCanvasBase)?

    /// Owned reference to `_canvas`'s Python shell. The Swift canvas
    /// instance is owned by its Python object (tp_init stores it, dealloc
    /// releases it) — holding only the Swift side lets a
    /// `w.canvas = PixelBufferCanvasBase(...)` temporary die at the end of
    /// the statement, and the shell's dealloc (plus a later zombie
    /// resurrection through the getter's `newRef`) over-releases the Swift
    /// instance `_canvas` still points at → SIGSEGV in
    /// swift_unknownObjectRetain on the next tree attach. Tetris only
    /// survived because its game object happens to keep the Python canvas
    /// alive. Retained in `setCanvas`, released on replacement and deinit.
    private var _canvasPyRef: PyPointer?

    /// The widget's canvas slot as Python sees it. Assign any canvas kind
    /// — `PySulphurCanvasBase` or `PySulphurSceneBase` — or None to
    /// detach. Typed `PyPointer` because the macro can't deserialize an
    /// existential; the concrete-type dispatch happens here instead.
    @PyProperty var canvas: PyPointer {
        get {
            _canvas?.pyPointer() ?? .None
        }
        set {
            if newValue == .None {
                clearCanvas()
                return
            }
            //let assigned: (any PyCanvasBase)? =
            switch newValue {
            case ThorCanvasBase.PyType: setCanvas(try? ThorCanvasBase.casted(unsafe: newValue))
            //case ThorSceneBase.PyType: try? ThorSceneBase.casted(unsafe: newValue)
            case PixelBufferCanvasBase.PyType: setCanvas(try? PixelBufferCanvasBase.casted(unsafe: newValue))
            case PyBufferCanvasBase.PyType: setCanvas(try? PyBufferCanvasBase.casted(unsafe: newValue))
            case SkiaCanvasBase.PyType: setCanvas(try? SkiaCanvasBase.casted(unsafe: newValue))
            default: break
            }
            //setCanvas(assigned)
            attachCanvasIfLive()
        }
    }

    public var children: [PyWidgetBase] = []

    /// The layout that positions this widget's children — Python assigns one
    /// of the layout `@PyClass`es (`widget.layout = GridLayout(columns=3)`).
    /// Stored as the existential; the `layout` `@PyProperty` below is the
    /// Python round-trip, dispatching on concrete type exactly like `canvas`.
    /// `nil` means no managed layout — children keep whatever frames they were
    /// given. Nothing drives the pass automatically yet; call `runLayout()`
    /// when children or this widget's frame change.
    private var _layout: (any PyLayoutProtocol)?

    /// The layout slot as Python sees it. Assign a layout `@PyClass` or None
    /// to clear. Typed `PyPointer` because the macro can't deserialize an
    /// existential — concrete-type dispatch happens here, same as `canvas`.
    @PyProperty var layout: PyPointer {
        get {
            _layout?.pyPointer() ?? .None
        }
        set {
            if newValue == .None {
                _layout = nil
            } else {
                _layout = switch newValue {
                case VerticalLayout.PyType:   try? VerticalLayout.casted(unsafe: newValue)
                case HorizontalLayout.PyType: try? HorizontalLayout.casted(unsafe: newValue)
                case VerticalGrid.PyType:     try? VerticalGrid.casted(unsafe: newValue)
                case HorizontalGrid.PyType:   try? HorizontalGrid.casted(unsafe: newValue)
                default: nil
                }
            }
            // Layout (re)assigned → place existing children with it.
            runLayout()
        }
    }

    weak var parent: PyWidgetBase?

    //private weak var engine: VulkanRenderEngine?
    //private weak var wgpu: WgpuContext?

    /// Size handed down by `attach` — the node size for canvases and
    /// children added after the tree is already live.
    private var attachedSize: (width: Int, height: Int)?

    @PyProperty()
    var id: Int = UUID().hashValue

    @PyInit
    init(__self__: PyPointer) {
        self.__self__ = __self__
    }

    deinit {
        _canvasPyRef?.decRef()
    }

    /// Single point of canvas replacement: detaches whatever was there,
    /// wires the owner back-pointer, and hands the widget's (or nearest
    /// ancestor's) frame down so the canvas sizes itself from it.
    private func clearCanvas() {
        if let old = _canvas {
            old.detach()
        }
        // Keep the Python shell alive alongside the Swift instance — see
        // `_canvasPyRef`. `pyPointer()` returns +1 (`__self__.newRef`),
        // taken here while the setter still borrows the object, i.e.
        // before the caller's temporary can die.
        _canvasPyRef?.decRef()
        _canvasPyRef = nil
        _canvas = nil
        //newCanvas?.owner = self
        //newCanvas?.frame = frame
    }
    
    private func setCanvas(_ newCanvas: ThorCanvasBase?) {
        if let old = _canvas, old !== newCanvas {
            old.detach()
        }
        // Keep the Python shell alive alongside the Swift instance — see
        // `_canvasPyRef`. `pyPointer()` returns +1 (`__self__.newRef`),
        // taken here while the setter still borrows the object, i.e.
        // before the caller's temporary can die.
        _canvasPyRef?.decRef()
        _canvasPyRef = newCanvas?.pyPointer()
        _canvas = newCanvas
        newCanvas?.owner = self
        newCanvas?.frame = frame
    }
    
    private func setCanvas(_ newCanvas: SkiaCanvasBase?) {
        if let old = _canvas, old !== newCanvas {
            old.detach()
        }
        // Keep the Python shell alive alongside the Swift instance — see
        // `_canvasPyRef`. `pyPointer()` returns +1 (`__self__.newRef`),
        // taken here while the setter still borrows the object, i.e.
        // before the caller's temporary can die.
        _canvasPyRef?.decRef()
        _canvasPyRef = newCanvas?.pyPointer()
        _canvas = newCanvas
        newCanvas?.owner = self
        newCanvas?.frame = frame
    }
    
    private func setCanvas(_ newCanvas: PixelBufferCanvasBase?) {
            if let old = _canvas, old !== newCanvas {
                old.detach()
            }
            // Keep the Python shell alive alongside the Swift instance — see
            // `_canvasPyRef`. `pyPointer()` returns +1 (`__self__.newRef`),
            // taken here while the setter still borrows the object, i.e.
            // before the caller's temporary can die.
            _canvasPyRef?.decRef()
            _canvasPyRef = newCanvas?.pyPointer()
            _canvas = newCanvas
            newCanvas?.owner = self
            newCanvas?.frame = frame
        }
    
    private func setCanvas(_ newCanvas: PyBufferCanvasBase?) {
            if let old = _canvas, old !== newCanvas {
                old.detach()
            }
            // Keep the Python shell alive alongside the Swift instance — see
            // `_canvasPyRef`. `pyPointer()` returns +1 (`__self__.newRef`),
            // taken here while the setter still borrows the object, i.e.
            // before the caller's temporary can die.
            _canvasPyRef?.decRef()
            _canvasPyRef = newCanvas?.pyPointer()
            _canvas = newCanvas
            newCanvas?.owner = self
            newCanvas?.frame = frame
        }

    /// Attach the current canvas right away when the widget is already in
    /// a live tree — canvases assigned before `attach` wait for it instead.
    private func attachCanvasIfLive() {
        // guard let engine, let wgpu, let size = attachedSize else { return }
        // _canvas?.attach(
        //     engine:  engine,
        //     wgpu:    wgpu,
        //     ownNode: nil,
        //     width:   size.width,
        //     height:  size.height
        // )
    }

    /// Position `children` with `layout`, if one is set: this widget's frame
    /// is the container, each child hands in its frame. Frames are mutated in
    /// place, so an observing canvas reacts. No-op without a layout. Call it
    /// when children are added/removed or this widget's frame changes — the
    /// pass isn't driven automatically.
    public func runLayout() {
        guard let activeLayout = _layout, let container = frame else { return }
        // Hand the frames to the layout and let it place them. The layout
        // keeps them so a later `spacing`/`alignment` change can recompute
        // on its own — it never calls back here.
        activeLayout.boundContainer = container
        activeLayout.boundChildren  = children.map { $0.frame }
        activeLayout.recompute()
    }

    public func on_render(dt: Double) {
        for child in children {
            child.on_render(dt: dt)
        }
        _canvas?.on_render(dt: dt)
    }

    /// Hands the shared engine/wgpu context down the tree, attaching each
    /// widget's canvas whatever its kind. Canvases are Python's to create
    /// and assign — the widget only attaches what it holds. `ownNode` is
    /// the app root's pre-built window node, adopted by the root widget's
    /// canvas.
    // func attach(
    //     engine:  VulkanRenderEngine,
    //     wgpu:    WgpuContext,
    //     ownNode: ThorShaderNode? = nil,
    //     width:   Int,
    //     height:  Int
    // ) {
    //     self.engine = engine
    //     self.wgpu = wgpu
    //     self.attachedSize = (width, height)
    //     _canvas?.attach(
    //         engine:  engine,
    //         wgpu:    wgpu,
    //         ownNode: ownNode,
    //         width:   width,
    //         height:  height
    //     )
    //     for child in children {
    //         child.attach(
    //             engine: engine,
    //             wgpu:   wgpu,
    //             width:  width,
    //             height: height
    //         )
    //     }
    // }

    /// The canvas this widget's content lands on: its own, or the closest
    /// ancestor's. Scene canvases resolve their host through this — every
    /// canvas records its owner widget and every widget its parent, so
    /// nesting is just a walk up.
    func nearestCanvas() -> (any PyCanvasBase)? {
        _canvas ?? parent?.nearestCanvas()
    }

    /// Tears this subtree out of the composite — every canvas detaches its
    /// own way (nodes leave the engine, scenes leave their host), so
    /// nothing stale keeps drawing every frame.
    private func detachTree() {
        
        for child in children {
            child.detachTree()
        }
        clearCanvas()
        parent = nil
        // engine = nil // should we even need to ref to render engine at all in this class ?
        // wgpu = nil // NEVER REF TO WEBGPU OF ANY KIND ON THIS SIDE, IT BELONGS IN RENDERENGINE ONLY
        attachedSize = nil
    }

    public func add_widget<W>(widget: W) where W : WidgetProtocol {
        print("adding \(widget) to \(self)")
        //children.append(widget)
    }

    @PyMethod()
    func add_widget(widget: PyPointer) throws {
        let child: PyWidgetBase = try .casted(from: widget)
        child.parent = self
        children.append(child)
        // A new child changed the set the layout places.
        runLayout()
        // find better way that doesnt envolve stored engine or webgpu
        // we should never need to ref to this again on this side, belong in render
        // make this smarter
        //if let engine, let wgpu, let size = attachedSize {
        //    child.attach(
        //        engine: engine,
        //        wgpu:   wgpu,
        //        width:  size.width,
        //        height: size.height
        //    )
        // }
    }

    public func remove_widget<W>(widget: W) where W : WidgetProtocol {

    }

    @PyMethod()
    func remove_widget(widget: PyPointer) throws {
        let wid: PyWidgetBase = try .casted(from: widget)
        children.removeAll { $0.id == wid.id }
        wid.detachTree()
        runLayout()
    }

    @PyMethod()
    public func clear_widgets() {
        for child in children {
            child.detachTree()
        }
        children.removeAll()
    }

}
