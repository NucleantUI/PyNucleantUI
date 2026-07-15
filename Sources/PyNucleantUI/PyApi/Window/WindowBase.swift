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

extension PyNucleantUI_Package {
    
    @PyModule(name: "nucleant.window")
    struct Window: PyModuleProtocol {
        
        static let py_classes: [any (PyClassProtocol & AnyObject).Type] = [
            WindowBase.self
        ]
        
    }
}



@PyClass(
    self_ref: true
)
final class WindowBase: PyDeserialize {
    
    fileprivate weak var app: PyApp?
    
    fileprivate let __self__: PyPointer
    
    
    private let _on_build:             PyPointer = "on_build"
    private let _on_frame:             PyPointer = "on_frame"
    private let _on_mouse_down:        PyPointer = "on_mouse_down"
    private let _on_mouse_up:          PyPointer = "on_mouse_up"
    private let _on_mouse_dragged:     PyPointer = "on_mouse_dragged"
    private let _on_mouse_moved:       PyPointer = "on_mouse_moved"
    private let _on_right_mouse_down:  PyPointer = "on_right_mouse_down"
    private let _on_right_mouse_up:    PyPointer = "on_right_mouse_up"
    private let _on_scroll:            PyPointer = "on_scroll"
    private let _on_key_down:          PyPointer = "on_key_down"
    private let _on_key_up:            PyPointer = "on_key_up"
    
    var platformWindow: PlatformWindow?
    var renderEngine: VulkanRenderEngine?
    var rootWidget: SulphurWidgetBase?
    
    var win_rect: SIMD4<Int>
    
    @PyInit
    init(__self__: PyPointer, x: Int, y: Int, w: Int, h: Int) throws {
        win_rect = .init(x, y, w, h)
        print(Self.self, "init")
        pyPrint(__self__)
        self.__self__ = __self__
    }
    
    deinit {
        _on_build.decRef()
        _on_mouse_down.decRef()
        _on_mouse_up.decRef()
        _on_mouse_dragged.decRef()
        _on_mouse_moved.decRef()
        _on_right_mouse_down.decRef()
        _on_right_mouse_up.decRef()
        _on_scroll.decRef()
        _on_key_down.decRef()
        _on_key_up.decRef()
    }
    
    @PyMethod
    func present() throws {
        let platformWindow = PlatformWindow(
            contentRect: .init(x: win_rect.x, y: win_rect.y, width: win_rect.z, height: win_rect.w),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        self.renderEngine = try .init(metalLayer: platformWindow.metalLayer)
        self.platformWindow = platformWindow
        platformWindow.win_delegate = self
        
        platformWindow.makeKeyAndOrderFront(nil)
        platformWindow.makeFirstResponder(nil)
        rootWidget = try on_build()
        attachRootWidget()
    }

    /// Bind the tree `on_build` returned into this window's engine: the
    /// context handed down here is what makes each canvas build its render
    /// node and join the engine's composite list. No pre-built root node —
    /// every canvas in the tree owns its own node (`ownNode` stays nil);
    /// the engine is this window's, the wgpu context the process-wide one.
    private func attachRootWidget() {
        guard let rootWidget, let renderEngine else { return }
        guard let wgpu = WgpuContext.shared else {
            print("WindowBase: no wgpu context — canvases stay unattached")
            return
        }
        let drawable = renderEngine.metalLayer.drawableSize
        let width  = drawable.width  > 0 ? Int(drawable.width)  : win_rect.z
        let height = drawable.height > 0 ? Int(drawable.height) : win_rect.w
        rootWidget.attach(
            engine: renderEngine,
            wgpu:   wgpu,
            width:  width,
            height: height
        )
    }

    /// Per display-link tick: Python's frame hook first (game state), then
    /// the tree's render pass (canvases flag dirty / run update hooks), then
    /// the engine draws what got flagged.
    func onFrame(_ dt: Double) {
        on_frame(dt: dt)
        rootWidget?.on_render(dt: dt)
        renderEngine?.drawFrame(dt)
    }
    
    
}

extension WindowBase {
    
    @PyCallMethod(path: \Self.__self__) func on_build() throws -> SulphurWidgetBase?
    @PyCallMethod(path: \Self.__self__) func on_frame(dt: Double)
    @PyCallMethod(path: \Self.__self__) func on_mouse_down(x: Double, y: Double)
    @PyCallMethod(path: \Self.__self__) func on_mouse_up(x: Double, y: Double)
    @PyCallMethod(path: \Self.__self__) func on_mouse_dragged(x: Double, y: Double)
    @PyCallMethod(path: \Self.__self__) func on_mouse_moved(x: Double, y: Double)
    @PyCallMethod(path: \Self.__self__) func on_right_mouse_down(x: Double, y: Double)
    @PyCallMethod(path: \Self.__self__) func on_right_mouse_up(x: Double, y: Double)
    @PyCallMethod(path: \Self.__self__) func on_scroll(dx: Double, dy: Double)
    @PyCallMethod(path: \Self.__self__) func on_key_down(keyCode: UInt16, characters: String?)
    @PyCallMethod(path: \Self.__self__) func on_key_up(keyCode: UInt16, characters: String?)
}

