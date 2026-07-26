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
#if os(iOS)
import UIKit
import Platform_iOS
#endif

extension PyNucleantUI_Package {
    
    @PyModule(name: "_nucleant.window")
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
    private let _py_on_size:           PyPointer = "on_size"
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
    private let _on_touch_down:        PyPointer = "on_touch_down"
    private let _on_touch_moved:       PyPointer = "on_touch_moved"
    private let _on_touch_up:          PyPointer = "on_touch_up"
    private let _on_touch_cancelled:   PyPointer = "on_touch_cancelled"

    #if os(macOS) || os(iOS)
    // Strongly held: PlatformWindow keeps only a weak `win_delegate` back to
    // us, and the platform's own retain of a visible window isn't a contract
    // to rely on — the window's lifetime is this object's to own. Each
    // platform compiles its own PlatformWindow (AppKit NSWindow / UIKit
    // UIWindow); only one is in scope per build.
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
        _py_on_size.decRef()
        _on_mouse_down.decRef()
        _on_mouse_up.decRef()
        _on_mouse_dragged.decRef()
        _on_mouse_moved.decRef()
        _on_right_mouse_down.decRef()
        _on_right_mouse_up.decRef()
        _on_scroll.decRef()
        _on_key_down.decRef()
        _on_key_up.decRef()
        _on_touch_down.decRef()
        _on_touch_moved.decRef()
        _on_touch_up.decRef()
        _on_touch_cancelled.decRef()
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
        if let root = root {
            if let frame = root.frame {
                frame.size = .init(Double(win_rect.z), Double(win_rect.w))
            } else {
                root.frame = .init(pos: .zero, size: .init(Double(win_rect.z), Double(win_rect.w)))
            }
            // Root now carries the window size — lay its subtree out before bind.
            root.runLayout()
        }
        if let root {
            RenderBinder.bind(tree: root, into: engine, width: win_rect.z, height: win_rect.w)
        }

        // 4. Show it.
        platformWindow.title = "Nucleant"
        platformWindow.makeKeyAndOrderFront(nil)
        platformWindow.makeFirstResponder(platformWindow.contentView)
        #elseif os(iOS)
        // 1. iOS platform window: a UIWindow + root view controller hosting the
        //    CAMetalLayer-backed VulkanView. Its display link is already
        //    running; it no-ops until win_delegate + the engine are in place.
        //    Unlike macOS, iOS has no windowed-desktop concept here — whatever
        //    size Python requested (a desktop-oriented default in most
        //    examples) is ignored in favor of the connecting UIWindowScene's
        //    bounds: full screen in normal single-window mode, or whatever
        //    rect Stage Manager assigned in windowed mode. Building the window
        //    with `windowScene:` (not a bare frame) is what makes it keep
        //    tracking that rect automatically if the user resizes it later.
        // win_rect is updated to match so the widget tree and RenderBinder
        // below lay out against the real window size, not the stale request.
        let scale = ActiveScene.current?.screen.scale ?? 2.0
        let screenBounds = ActiveScene.current?.coordinateSpace.bounds ?? UIScreen.main.bounds
        win_rect = SIMD4(
            Int(screenBounds.origin.x), Int(screenBounds.origin.y),
            Int(screenBounds.width * scale) ,    Int(screenBounds.height * scale)
        )
        let platformWindow: PlatformWindow<WindowBase>
        if let windowScene = ActiveScene.current {
            platformWindow = PlatformWindow<WindowBase>(windowScene: windowScene)
        } else {
            platformWindow = PlatformWindow<WindowBase>(frame: screenBounds)
        }

        // 2. Vulkan engine on that layer — same ownership as macOS.
        let engine = try RenderEngine(metalLayer: platformWindow.metalLayer)
        self.renderEngine   = engine
        self.platformWindow = platformWindow
        platformWindow.win_delegate = self

        // 3. Build + bind the Python widget tree (identical to macOS).
        let root = try on_build()
        rootWidget = root
        if let root = root {
            if let frame = root.frame {
                frame.size = .init(Double(win_rect.z), Double(win_rect.w))
            } else {
                root.frame = .init(pos: .zero, size: .init(Double(win_rect.z), Double(win_rect.w)))
            }
            root.runLayout()
        }
        if let root {
            RenderBinder.bind(tree: root, into: engine, width: win_rect.z, height: win_rect.w)
        }
        //py_on_size(w: win_rect.z.scaled(scale), h: win_rect.w.scaled(scale))
        // 4. Show it.
        platformWindow.makeKeyAndVisible()
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

    /// Window content resized to `w × h` (native side — not a Python hook).
    /// Adopt the new size and hand it to the root widget: its frame is the
    /// layout container size, and setting it drives the root canvas's
    /// render-node resize through the widget's `frame` setter. The engine
    /// recreates its swapchain from the layer's drawable size on the next
    /// `drawFrame`, so we don't touch the swapchain here.
    func on_size(w: Double, h: Double) {
        // w, h arrive in points (VulkanView's onSizeChange contract matches
        // touch/mouse coordinates), but the widget/render layer works in
        // pixels -- RenderBinder sizes canvases and the composite viewport
        // straight off frame sizes against the swapchain's pixel-sized
        // drawable. Scale before touching anything layout/render-facing;
        // py_on_size (the Python hook) keeps the raw point values, same as
        // touch/mouse.
        let scale = Double(platformWindow?.metalLayer.contentsScale ?? 1.0)
        let pxW = w * scale
        let pxH = h * scale
        win_rect.z = Int(pxW)
        win_rect.w = Int(pxH)
        py_on_size(w: pxW, h: pxH)
        // Root fills the window: a fixed frame at the origin, the new size.
        guard let rootWidget else { return }
        if let frame = rootWidget.frame {
            frame.size = .init(pxW, pxH)
        } else {
            rootWidget.frame = NucleantFrame(pos: .zero, size: .init(pxW, pxH))
        }
        // In-place `frame.size` mutation drives the root's own render, but it
        // bypasses the widget's `frame` setter — so re-place the children under
        // the new container size explicitly, same as `present` does.
        rootWidget.runLayout()
    }


}

extension WindowBase {
    
    @PyCallMethod(path: \Self.__self__) func on_build() throws -> PyWidgetBase?
    @PyCallMethod(path: \Self.__self__) func on_frame(dt: Double)
    @PyCallMethod(path: \Self.__self__) func py_on_size(w: Double, h: Double)
    @PyCallMethod(path: \Self.__self__) func on_mouse_down(x: Double, y: Double)
    @PyCallMethod(path: \Self.__self__) func on_mouse_up(x: Double, y: Double)
    @PyCallMethod(path: \Self.__self__) func on_mouse_dragged(x: Double, y: Double)
    @PyCallMethod(path: \Self.__self__) func on_mouse_moved(x: Double, y: Double)
    @PyCallMethod(path: \Self.__self__) func on_right_mouse_down(x: Double, y: Double)
    @PyCallMethod(path: \Self.__self__) func on_right_mouse_up(x: Double, y: Double)
    @PyCallMethod(path: \Self.__self__) func on_scroll(dx: Double, dy: Double)
    @PyCallMethod(path: \Self.__self__) func on_key_down(keyCode: UInt16, characters: String?)
    @PyCallMethod(path: \Self.__self__) func on_key_up(keyCode: UInt16, characters: String?)
    @PyCallMethod(path: \Self.__self__) func on_touch_down(id: Int, x: Double, y: Double)
    @PyCallMethod(path: \Self.__self__) func on_touch_moved(id: Int, x: Double, y: Double)
    @PyCallMethod(path: \Self.__self__) func on_touch_up(id: Int, x: Double, y: Double)
    @PyCallMethod(path: \Self.__self__) func on_touch_cancelled(id: Int, x: Double, y: Double)
}

#if os(macOS)
// PlatformWindow routes AppKit events to its `win_delegate` through
// WindowBaseDelegate; the mapping to our `on_*` Python hooks is the default
// implementation on `NucleantWindow where Self: WindowBaseDelegate`
// (Platform_MacOS), so declaring the conformance is all that's needed.
extension WindowBase: WindowBaseDelegate {}
#endif

#if os(iOS)
// Same pattern on iOS: PlatformWindow routes UIKit touches to its
// `win_delegate` through WindowTouchDelegate, whose default impls
// (Platform_iOS) forward to our `on_touch_*` Python hooks.
extension WindowBase: WindowTouchDelegate {}
#endif

