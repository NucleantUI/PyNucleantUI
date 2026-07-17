//
//  SulphurWidgetBase.swift
//
@preconcurrency import PySwiftKit
import PySerializing
import PySwiftWrapper

import SulphurUI
import SulphurCore
import SulphurApplication
import SulphurVulkan
import Foundation
import Observation


protocol PyWidgetProtocol: WidgetProtocol, PySerializable {
    var __self__: PyPointer { get }
}

extension PyWidgetProtocol {
    public func pyPointer() -> PyPointer {
        __self__.newRef
    }
}



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
public final class NucleantWidgetBase: PyWidgetProtocol, PySerializable, @preconcurrency PyClassProtocol {
    
    

    var __self__: PyPointer
    
    private var _frame: NucleantFrame?
    public var frame: NucleantFrame? {
        get { _frame ?? parent?.frame }
        set {
            _frame = newValue
            // Reading back through the getter resolves the parent fallback
            // when the own frame was just cleared. On a live node canvas
            // this is what triggers the render-node resize.
            _canvas?.frame = frame
        }
    }

    var _canvas: (any PyCanvasBase)?

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
                setCanvas(nil)
                return
            }
            let assigned: (any PyCanvasBase)? = switch newValue {
            case PySulphurCanvasBase.PyType: try? PySulphurCanvasBase.casted(unsafe: newValue)
            case PySulphurSceneBase.PyType: try? PySulphurSceneBase.casted(unsafe: newValue)
            default: nil
            }
            setCanvas(assigned)
            attachCanvasIfLive()
        }
    }

    public var children: [NucleantWidgetBase] = []

    weak var parent: NucleantWidgetBase?

    private weak var engine: VulkanRenderEngine?
    private weak var wgpu: WgpuContext?

    /// Size handed down by `attach` — the node size for canvases and
    /// children added after the tree is already live.
    private var attachedSize: (width: Int, height: Int)?

    @PyProperty()
    var id: Int = UUID().hashValue

    @PyInit
    init(__self__: PyPointer) {
        self.__self__ = __self__
    }

    /// Single point of canvas replacement: detaches whatever was there,
    /// wires the owner back-pointer, and hands the widget's (or nearest
    /// ancestor's) frame down so the canvas sizes itself from it.
    private func setCanvas(_ newCanvas: (any PyCanvasBase)?) {
        if let old = _canvas, old !== newCanvas {
            old.detach()
        }
        _canvas = newCanvas
        newCanvas?.owner = self
        newCanvas?.frame = frame
    }

    /// Attach the current canvas right away when the widget is already in
    /// a live tree — canvases assigned before `attach` wait for it instead.
    private func attachCanvasIfLive() {
        guard let engine, let wgpu, let size = attachedSize else { return }
        _canvas?.attach(
            engine:  engine,
            wgpu:    wgpu,
            ownNode: nil,
            width:   size.width,
            height:  size.height
        )
    }

    func on_render(dt: Double) {
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
    func attach(
        engine:  VulkanRenderEngine,
        wgpu:    WgpuContext,
        ownNode: ThorShaderNode? = nil,
        width:   Int,
        height:  Int
    ) {
        self.engine = engine
        self.wgpu = wgpu
        self.attachedSize = (width, height)
        _canvas?.attach(
            engine:  engine,
            wgpu:    wgpu,
            ownNode: ownNode,
            width:   width,
            height:  height
        )
        for child in children {
            child.attach(
                engine: engine,
                wgpu:   wgpu,
                width:  width,
                height: height
            )
        }
    }

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
        setCanvas(nil)
        parent = nil
        engine = nil
        wgpu = nil
        attachedSize = nil
    }

    public func add_widget<W>(widget: W) where W : WidgetProtocol {
        print("adding \(widget) to \(self)")
        //children.append(widget)
    }

    @PyMethod()
    func add_widget(widget: PyPointer) throws {
        let child: NucleantWidgetBase = try .casted(from: widget)
        child.parent = self
        children.append(child)
        if let engine, let wgpu, let size = attachedSize {
            child.attach(
                engine: engine,
                wgpu:   wgpu,
                width:  size.width,
                height: size.height
            )
        }
    }

    public func remove_widget<W>(widget: W) where W : WidgetProtocol {

    }

    @PyMethod()
    func remove_widget(widget: PyPointer) throws {
        let wid: NucleantWidgetBase = try .casted(from: widget)
        children.removeAll { $0.id == wid.id }
        wid.detachTree()
    }

    @PyMethod()
    public func clear_widgets() {
        for child in children {
            child.detachTree()
        }
        children.removeAll()
    }

}
