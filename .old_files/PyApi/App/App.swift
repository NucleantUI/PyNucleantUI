//
//  App.swift
//  SulphurXcodeDemo
//
@preconcurrency import PySwiftKit
@preconcurrency import PySerializing
import PySwiftWrapper
import SulphurApplication
import AppKit
import SulphurCore

@PyClass(
    name: "App",
    self_ref: true
)

class PyApp {
    
    let __self__: PyPointer
    
    var _on_build: PyPointer?
    
    var _on_start: PyPointer?

    // Optional — unlike on_build, an app isn't required to handle input,
    // so these are fetched with `try?` (nil if Python doesn't define them)
    // rather than on_build's `try!`, and every call site below guards on
    // the pointer being non-nil before invoking the matching @PyCall.
    var _on_mouse_down:       PyPointer?
    var _on_mouse_up:         PyPointer?
    var _on_mouse_dragged:    PyPointer?
    var _on_mouse_moved:      PyPointer?
    var _on_right_mouse_down: PyPointer?
    var _on_right_mouse_up:   PyPointer?
    var _on_scroll:           PyPointer?
    var _on_key_down:         PyPointer?
    var _on_key_up:           PyPointer?

    var rootWidget: SulphurWidgetBase?
    
    var rootWindow: WindowBase?

    var renderTarget: RootRenderTarget?

    @PyInit init(__self__: PyPointer, threads: UInt32) throws {

        tvg_engine_init(threads)

        self.__self__ = __self__

        self._on_build =   try! PyObject_GetAttr(__self__, key: "on_build")
        self._on_start = try! PyObject_GetAttr(__self__, key: "on_start")
        // Optional hooks: check existence first rather than fetch-and-swallow —
        // most apps won't define most of these, and that's the normal case,
        // not an error worth routing through Python's exception machinery.
        func optionalAttr(_ key: String) -> PyPointer? {
            PyObject_HasAttr(__self__, key) ? try? PyObject_GetAttr(__self__, key: key) : nil
        }
        self._on_mouse_down       = optionalAttr("on_mouse_down")
        self._on_mouse_up         = optionalAttr("on_mouse_up")
        self._on_mouse_dragged    = optionalAttr("on_mouse_dragged")
        self._on_mouse_moved      = optionalAttr("on_mouse_moved")
        self._on_right_mouse_down = optionalAttr("on_right_mouse_down")
        self._on_right_mouse_up   = optionalAttr("on_right_mouse_up")
        self._on_scroll           = optionalAttr("on_scroll")
        self._on_key_down         = optionalAttr("on_key_down")
        self._on_key_up           = optionalAttr("on_key_up")

        let app = NSApplication.shared
        let delegate = AppDelegate()
        delegate.on_frame = { [weak self] dt in
            // MoltenVK translates every Vulkan call in drawFrame() into
            // Objective-C/Metal objects (command buffers, encoders, texture
            // views…), all autoreleased by Cocoa convention. CVDisplayLink's
            // callback hops here via DispatchQueue.main.async, which doesn't
            // reliably get its own drained pool every tick — without an
            // explicit one, a full frame's worth of Metal objects piles up
            // every single frame, forever, even with nothing on screen.
            autoreleasepool {
                guard let self, let rootWidget = self.rootWidget else { return }

                //rootWidget.on_canvas(dt: dt, canvas: self.rootWidget?.canvas?.asCapsule() ?? .None)
                rootWidget.on_render(dt: dt)

                self.renderTarget?.engine.drawFrame(dt)
            }
        }
        delegate.on_build = { [weak self] in
            
            guard let self, let root = try? self.on_start() else { return }
            return
            
            guard let self, let root = try? self.on_build() else { return }
            guard let target = Self.makeRootRenderTarget() else { return }
            self.renderTarget = target
            root.attach(
                engine:  target.engine,
                wgpu:    target.wgpu,
                ownNode: target.node,
                width:   Int(target.node.width),
                height:  Int(target.node.height)
            )
            self.rootWidget = root
        }
        delegate.on_mouse_down = { [weak self] x, y in
            guard let self, self._on_mouse_down != nil else { return }
            try? self.on_mouse_down(x: x, y: y)
        }
        delegate.on_mouse_up = { [weak self] x, y in
            guard let self, self._on_mouse_up != nil else { return }
            try? self.on_mouse_up(x: x, y: y)
        }
        delegate.on_mouse_dragged = { [weak self] x, y in
            guard let self, self._on_mouse_dragged != nil else { return }
            try? self.on_mouse_dragged(x: x, y: y)
        }
        delegate.on_mouse_moved = { [weak self] x, y in
            guard let self, self._on_mouse_moved != nil else { return }
            try? self.on_mouse_moved(x: x, y: y)
        }
        delegate.on_right_mouse_down = { [weak self] x, y in
            guard let self, self._on_right_mouse_down != nil else { return }
            try? self.on_right_mouse_down(x: x, y: y)
        }
        delegate.on_right_mouse_up = { [weak self] x, y in
            guard let self, self._on_right_mouse_up != nil else { return }
            try? self.on_right_mouse_up(x: x, y: y)
        }
        delegate.on_scroll = { [weak self] dx, dy in
            guard let self, self._on_scroll != nil else { return }
            try? self.on_scroll(dx: dx, dy: dy)
        }
        delegate.on_key_down = { [weak self] keyCode, characters in
            guard let self, self._on_key_down != nil else { return }
            try? self.on_key_down(keyCode: Int(keyCode), characters: characters)
        }
        delegate.on_key_up = { [weak self] keyCode, characters in
            guard let self, self._on_key_up != nil else { return }
            try? self.on_key_up(keyCode: Int(keyCode), characters: characters)
        }
        app.delegate = delegate
        //app.run()
    }
    
    @PyMethod()
    func run() {
        NSApplication.shared.run()
    }
    
    @PyMethod
    func new_window(window: WindowBase) {
        NSApplication.shared.addWindowsItem(window.platformWindow, title: window.platformWindow.title, filename: false)
    }
    
    deinit {
        _on_build?.decRef()
        _on_mouse_down?.decRef()
        _on_mouse_up?.decRef()
        _on_mouse_dragged?.decRef()
        _on_mouse_moved?.decRef()
        _on_right_mouse_down?.decRef()
        _on_right_mouse_up?.decRef()
        _on_scroll?.decRef()
        _on_key_down?.decRef()
        _on_key_up?.decRef()
    }

    @PyCall func on_build() throws -> SulphurWidgetBase?

    @PyCall func on_mouse_down(x: Double, y: Double) throws
    @PyCall func on_mouse_up(x: Double, y: Double) throws
    @PyCall func on_mouse_dragged(x: Double, y: Double) throws
    @PyCall func on_mouse_moved(x: Double, y: Double) throws
    @PyCall func on_right_mouse_down(x: Double, y: Double) throws
    @PyCall func on_right_mouse_up(x: Double, y: Double) throws
    @PyCall func on_scroll(dx: Double, dy: Double) throws
    @PyCall func on_key_down(keyCode: Int, characters: String) throws
    @PyCall func on_key_up(keyCode: Int, characters: String) throws

}

extension SulphurUi {
    @PyModule(name: "sulphur_ui.app")
    struct py_app: PyModuleProtocol {
        
        static let py_classes: [any (PyClassProtocol & AnyObject).Type] = [
            PyApp.self
        ]
    }
}
