//
//  SceneBase.swift
//  SulphurXcodeDemo
//
//  The scene flavor of PyCanvasBase: instead of owning a render node, it
//  wraps one ThorVG scene/paint and rides the nearest real canvas up the
//  widget tree. Assign it to a widget's `canvas` like any other canvas —
//  the widget can't tell the difference.
//
import SulphurCore
import SulphurVulkan
import PySwiftKit
import PySerializing
import PySwiftWrapper
import Foundation

/// A canvas backed by a ThorVG scene instead of a render node. Accepts the
/// scene/paint from Python — a thorvg-cython `Paint`/`Scene`, a
/// `PyCapsule("Tvg_Paint")`, or a raw pointer int. On attach it walks up
/// from its owner widget to the nearest canvas (node canvas *or* another
/// scene canvas — canvases record their owner, widgets their parent) and
/// adds its paint there; nested scene widgets compose through each other
/// for free.
@PyClass(self_ref: true)
public final class ThorSceneBase: PyCanvasBase {
    
    public var id: Int = UUID().hashValue

    /// The wrapped ThorVG paint (usually a scene).
    public private(set) var paint: Tvg_Paint?

    public weak var owner: NucleantWidgetBase?

    /// Recorded to satisfy the canvas contract, nothing more yet — a scene
    /// renders at whatever size its host node has. The obvious next use is
    /// translating the wrapped paint by `frame.pos`.
    public weak var frame: NucleantFrame?

    /// The canvas this scene's paint currently lives on. Weak: the host
    /// belongs to its own widget, this is only the record for detach.
    weak var hostCanvas: (any PyCanvasBase)?

    private var __self__: PyPointer

    /// Python draw hooks — same contract as the node canvas: `on_canvas`
    /// fires once the scene lands on its host, `update_canvas` every frame.
    let _on_canvas: PyPointer?
    let _update_canvas: PyPointer?

    @PyInit
    init(__self__: PyPointer, scene: PyPointer?) throws {
        self.__self__ = __self__
        func optionalAttr(_ key: String) -> PyPointer? {
            PyObject_HasAttr(__self__, key) ? try? PyObject_GetAttr(__self__, key: key) : nil
        }
        _on_canvas = optionalAttr("on_canvas")
        _update_canvas = optionalAttr("update_canvas")
        if let scene, scene != .None {
            self.paint = try Self.extractPaint(scene)
        }
    }

    deinit {
        _on_canvas?.decRef()
        _update_canvas?.decRef()
    }

    @PyCall
    func on_canvas()

    @PyCall
    func update_canvas(dt: Double)

    /// The engine context is a node-canvas concern — a scene canvas only
    /// needs the tree, so attach is just the nearest-canvas resolution.
    public func attach(
        engine:  VulkanRenderEngine,
        wgpu:    WgpuContext,
        ownNode: ThorShaderNode?,
        width:   Int,
        height:  Int
    ) {
        attachToHost()
    }

    /// Bind the paint to the nearest canvas above the owner widget. Starts
    /// at the owner's parent — the owner's own canvas is this scene. No-op
    /// until the tree is attached or when already bound; the widget retries
    /// on every attach pass.
    func attachToHost() {
        guard
            hostCanvas == nil,
            let paint,
            let host = owner?.parent?.nearestCanvas()
        else { return }
        host.add(paint: paint)
        hostCanvas = host
        if _on_canvas != nil {
            on_canvas()
        }
    }

    /// Take the paint back off its host — called when the owning widget
    /// subtree leaves the tree or the scene is replaced.
    public func detach() {
        if let paint, let host = hostCanvas {
            host.remove(paint: paint)
        }
        hostCanvas = nil
        owner = nil
    }

    public func on_render(dt: Double) {
        markDirty()
        if _update_canvas != nil {
            update_canvas(dt: dt)
        }
    }

    public func markDirty() {
        hostCanvas?.markDirty()
    }

    public func add(paint: Tvg_Paint) {
        guard let own = self.paint else { return }
        _ = tvg_scene_add(own, paint)
        markDirty()
    }

    public func remove(paint: Tvg_Paint) {
        guard let own = self.paint else { return }
        _ = tvg_scene_remove(own, paint)
        markDirty()
    }

    /// Replace the wrapped paint. Detaches the old one first; the new one
    /// re-attaches immediately if this scene is already in an attached tree.
    @PyMethod
    func set_scene(scene: PyPointer) throws {
        let newPaint = try Self.extractPaint(scene)
        let widget = owner
        detach()
        paint = newPaint
        owner = widget
        attachToHost()
    }

    /// Nest another scene canvas's paint inside this one — the wrapped
    /// paint must actually be a ThorVG scene for this to composite.
    @PyMethod
    func add_scene(scene: PyPointer) throws {
        guard PyObject_TypeCheck(scene, Self.PyType) else {
            throw PyStandardException.typeError
        }
        let child: ThorSceneBase = try .casted(from: scene)
        guard paint != nil, let childPaint = child.paint else {
            throw PyStandardException.valueError
        }
        add(paint: childPaint)
        child.hostCanvas = self
        child.owner = owner
    }

    public func pyPointer() -> PyPointer {
        __self__.newRef
    }

    /// Accept a scene/paint in any of the shapes Python produces: a
    /// `PyCapsule("Tvg_Paint")`, an object exposing `capsule()` returning
    /// one (thorvg-cython `Paint`), or a raw pointer as int.
    static func extractPaint(_ object: PyPointer) throws -> Tvg_Paint {
        if PyCapsule_IsValid(object, "Tvg_Paint") == 1 {
            guard let raw = PyCapsule_GetPointer(object, "Tvg_Paint") else {
                throw PyStandardException.valueError
            }
            return Tvg_Paint(raw)
        }
        if PyObject_HasAttr(object, "capsule") {
            let method = try PyObject_GetAttr(object, key: "capsule")
            defer { method.decRef() }
            guard let capsule = PyObject_CallObject(method, nil) else {
                PyErr_Print()
                throw PyStandardException.valueError
            }
            defer { capsule.decRef() }
            guard
                PyCapsule_IsValid(capsule, "Tvg_Paint") == 1,
                let raw = PyCapsule_GetPointer(capsule, "Tvg_Paint")
            else {
                throw PyStandardException.valueError
            }
            return Tvg_Paint(raw)
        }
        if let address = try? Int.casted(from: object), let raw = UnsafeMutableRawPointer(bitPattern: address) {
            return Tvg_Paint(raw)
        }
        throw PyStandardException.typeError
    }
}
