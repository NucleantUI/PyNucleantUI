//
//  Window.swift
//  SulphurXcodeDemo
//
@preconcurrency import PySwiftKit
@preconcurrency import PySerializing
import PySwiftWrapper

import SulphurUI
import SulphurCore
import SulphurApplication

//import AppKit

// Optional hooks: check existence first rather than fetch-and-swallow —
// most apps won't define most of these, and that's the normal case,
// not an error worth routing through Python's exception machinery.
extension PyPointer {
    func optionalAttr(_ key: String) -> PyPointer? {
        PyObject_HasAttr(self, key) ? try? PyObject_GetAttr(self, key: key) : nil
    }
}

extension PyNucleantUI_Package {
    
    @PyModule(name: "sulphur_ui.window")
    struct Window: PyModuleProtocol {
        
        static let py_classes: [any (PyClassProtocol & AnyObject).Type] = [
            WindowBase.self
        ]
        
    }
}



@PyClass(self_ref: true)
final class WindowBase: PyDeserialize {
    
    let platformWindow: PlatformWindow
    
    fileprivate weak var app: PyApp?
    
    fileprivate let __self__: PyPointer
    
    
    private let _on_build:             PyPointer?
    private let _on_mouse_down:        PyPointer?
    private let _on_mouse_up:          PyPointer?
    private let _on_mouse_dragged:     PyPointer?
    private let _on_mouse_moved:       PyPointer?
    private let _on_right_mouse_down:  PyPointer?
    private let _on_right_mouse_up:    PyPointer?
    private let _on_scroll:            PyPointer?
    private let _on_key_down:          PyPointer?
    private let _on_key_up:            PyPointer?
    
    var renderEngine: VulkanRenderEngine
    var rootWidget: SulphurWidgetBase?
    
    @PyInit
    init(__self__: PyPointer, x: Int, y: Int, w: Int, h: Int) throws {
        
        self.__self__ = __self__
        self._on_build            = __self__.optionalAttr("on_build")
        self._on_mouse_down       = __self__.optionalAttr("on_mouse_down")
        self._on_mouse_up         = __self__.optionalAttr("on_mouse_up")
        self._on_mouse_dragged    = __self__.optionalAttr("on_mouse_dragged")
        self._on_mouse_moved      = __self__.optionalAttr("on_mouse_moved")
        self._on_right_mouse_down = __self__.optionalAttr("on_right_mouse_down")
        self._on_right_mouse_up   = __self__.optionalAttr("on_right_mouse_up")
        self._on_scroll           = __self__.optionalAttr("on_scroll")
        self._on_key_down         = __self__.optionalAttr("on_key_down")
        self._on_key_up           = __self__.optionalAttr("on_key_up")
        
        let platformWindow = PlatformWindow(
            contentRect: .init(x: x, y: y, width: w, height: h),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        self.renderEngine = try .init(metalLayer: platformWindow.metalLayer)
        self.platformWindow = platformWindow
        platformWindow.win_delegate = self
        
        rootWidget = try on_build()
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
    
    func onFrame(_ dt: Double) {
        rootWidget?.on_render(dt: dt)
    }
    
    
}

extension WindowBase {
    
    @PyCall func on_build() throws -> SulphurWidgetBase?
    
    @PyCall func on_mouse_down(x: Double, y: Double)
    @PyCall func on_mouse_up(x: Double, y: Double)
    @PyCall func on_mouse_dragged(x: Double, y: Double)
    @PyCall func on_mouse_moved(x: Double, y: Double)
    @PyCall func on_right_mouse_down(x: Double, y: Double)
    @PyCall func on_right_mouse_up(x: Double, y: Double)
    @PyCall func on_scroll(dx: Double, dy: Double)
    @PyCall func on_key_down(keyCode: UInt16, characters: String?)
    @PyCall func on_key_up(keyCode: UInt16, characters: String?)
}

