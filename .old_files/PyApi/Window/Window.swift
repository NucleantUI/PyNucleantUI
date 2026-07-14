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

import AppKit



extension SulphurUi {
    
    @PyModule(name: "sulphur_ui.window")
    struct Window: PyModuleProtocol {
        
        static let py_classes: [any (PyClassProtocol & AnyObject).Type] = [
            WindowBase.self
        ]
        
    }
}

protocol WindowBaseDelegate: AnyObject {
    func mouseDown(location: NSPoint)
    func mouseUp(location: NSPoint)
    func mouseDragged(location: NSPoint)
    func mouseMoved(location: NSPoint)
    func rightMouseDown(location: NSPoint)
    func rightMouseUp(location: NSPoint)
    func scrollWheel(deltaX: Double, deltaY: Double)
    func keyDown(key: UInt16, chars:  String?)
    func keyUp(key: UInt16, chars:  String?)
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

extension WindowBase: WindowBaseDelegate {
    func mouseDown(location: NSPoint) {
        on_mouse_down(x: location.x, y: location.y)
    }
    
    func mouseUp(location: NSPoint) {
        on_mouse_up(x: location.x, y: location.y)
    }
    
    func mouseDragged(location: NSPoint) {
        on_mouse_dragged(x: location.x, y: location.y)
    }
    
    func mouseMoved(location: NSPoint) {
        on_mouse_moved(x: location.x, y: location.y)
    }
    
    func rightMouseDown(location: NSPoint) {
        on_right_mouse_down(x: location.x, y: location.y)
    }
    
    func rightMouseUp(location: NSPoint) {
        on_right_mouse_up(x: location.x, y: location.y)
    }
    
    func scrollWheel(deltaX: Double, deltaY: Double) {
        on_scroll(dx: deltaX, dy: deltaY)
    }
    
    func keyDown(key: UInt16, chars: String?) {
        on_key_down(keyCode: key, characters: chars)
    }
    
    func keyUp(key: UInt16, chars: String?) {
        on_key_up(keyCode: key, characters: chars)
    }
    
    
    
    
}

extension WindowBase {
    
    
    
    final class PlatformWindow: NSWindow, NSWindowDelegate {
        
        public var on_close:            (()->Void)?
        
        weak var win_delegate: WindowBase?
        
        private var _displayLink: CVDisplayLink?
        
        let metalLayer: CAMetalLayer
        
        override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
            let view = SulphurNSView(frame: NSRect(origin: .zero, size: contentRect.size))
            self.metalLayer = view.metalLayer
            super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
            self.contentView = view
        }
        
        public override func mouseDown(with event: NSEvent) {
            win_delegate?.mouseDown(location: event.locationInWindow)
        }
        
        public override func mouseUp(with event: NSEvent) {
            win_delegate?.mouseDown(location: event.locationInWindow)
        }
        
        public override func mouseDragged(with event: NSEvent) {
            win_delegate?.mouseDragged(location: event.locationInWindow)
        }
        
        public override func mouseMoved(with event: NSEvent) {
            win_delegate?.mouseMoved(location: event.locationInWindow)
        }
        
        public override func rightMouseDown(with event: NSEvent) {
            win_delegate?.rightMouseDown(location: event.locationInWindow)
        }
        
        public override func rightMouseUp(with event: NSEvent) {
            win_delegate?.rightMouseDown(location: event.locationInWindow)
        }
        
        public override func scrollWheel(with event: NSEvent) {
            win_delegate?.scrollWheel(deltaX: event.deltaX, deltaY: event.deltaY)
        }
        
        public override func keyDown(with event: NSEvent) {
            win_delegate?.keyDown(key: event.keyCode, chars: event.characters)
        }
        
        public override func keyUp(with event: NSEvent) {
            win_delegate?.keyUp(key: event.keyCode, chars: event.characters)
        }
        
        func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
            
            return frameSize
        }
        
        
        func windowDidMiniaturize(_ notification: Notification) {
            
        }
        
        func windowDidBecomeKey(_ notification: Notification) {
            
        }
    }
}


// MARK: - CVDisplayLink (macOS < 14)

@available(macOS, introduced: 10.4, obsoleted: 14.0)
private extension WindowBase.PlatformWindow {
    func startCVDisplayLink() {
        var dl: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&dl)
        guard let link = dl , let win_delegate else { return }
        _displayLink = link

        let ref = Unmanaged.passUnretained(win_delegate)
        CVDisplayLinkSetOutputCallback(link, { _, _, outputTime, _, _, ctx -> CVReturn in
            guard let ctx else { return kCVReturnError }
            let ot = outputTime.pointee
            let dt = Double(ot.videoRefreshPeriod) / Double(ot.videoTimeScale)
            let win = Unmanaged<WindowBase>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async { win.onFrame(dt) }
            return kCVReturnSuccess
        }, ref.toOpaque())

        CVDisplayLinkStart(link)
    }
}

// MARK: - CADisplayLink (macOS 14+)

@available(macOS 14.0, *)
private extension WindowBase.PlatformWindow {
    func startCADisplayLink() {
        let link = displayLink(target: self, selector: #selector(cadlTick(_:)))
        link.add(to: .main, forMode: .common)
    }

    @objc func cadlTick(_ link: CADisplayLink) {
        win_delegate?.onFrame(link.targetTimestamp - link.timestamp)
    }
}
