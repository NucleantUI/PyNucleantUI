//
//  Window.swift
//  SulphurXcodeDemo
//
@preconcurrency import PySwiftKit
@preconcurrency import PySerializing
import PySwiftWrapper

//import SulphurUI
//import NucleantVulkan
import NucleantApplication
import NucleantWindow
import NucleantVulkan
#if os(macOS)
import AppKit
import Platform_MacOS
#endif

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
final class WindowBase: NucleantWindow, PyDeserialize {
    
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
    
    #if os(macOS)
    // Strongly held: PlatformWindow keeps only a weak `win_delegate` back to
    // us, and AppKit's own retain of an ordered-front window isn't a contract
    // to rely on — the window's lifetime is this object's to own.
    var platformWindow: PlatformWindow<WindowBase>?
    #endif
    var renderEngine: VulkanRenderEngine<RenderNode>?
    var rootWidget: PyWidgetBase?
    
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
        #if os(macOS)
        // 1. Platform window + its CAMetalLayer-backed view. The view starts
        //    a display link straight away; it no-ops until `win_delegate` and
        //    the engine below are in place (both nil-guarded in onFrame).
        let platformWindow = PlatformWindow<WindowBase>(
            contentRect: NSRect(
                x:      Double(win_rect.x),
                y:      Double(win_rect.y),
                width:  Double(win_rect.z),
                height: Double(win_rect.w)
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing:   .buffered,
            defer:     false
        )

        // 2. The Vulkan engine renders into that layer. We own the engine;
        //    canvases only ever receive nodes it builds (see attachTree).
        let engine = try RenderEngine(metalLayer: platformWindow.metalLayer)
        self.renderEngine   = engine
        self.platformWindow = platformWindow
        platformWindow.win_delegate = self

        // 3. Build the Python widget tree and bind it into the engine. The
        //    window owns the engine and the tree; how a canvas maps to a
        //    render node is the RenderBinder seam's business, not ours — we
        //    never name a canvas kind here.
        let root = try on_build()
        rootWidget = root
        if let root {
            RenderBinder.bind(tree: root, into: engine, width: win_rect.z, height: win_rect.w)
        }

        // 4. Show it.
        platformWindow.title = "Nucleant"
        platformWindow.makeKeyAndOrderFront(nil)
        platformWindow.makeFirstResponder(platformWindow.contentView)
        #endif
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
    
    @PyCallMethod(path: \Self.__self__) func on_build() throws -> PyWidgetBase?
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

#if os(macOS)
// PlatformWindow routes AppKit events to its `win_delegate` through
// WindowBaseDelegate; the mapping to our `on_*` Python hooks is the default
// implementation on `NucleantWindow where Self: WindowBaseDelegate`
// (Platform_MacOS), so declaring the conformance is all that's needed.
extension WindowBase: WindowBaseDelegate {}
#endif

