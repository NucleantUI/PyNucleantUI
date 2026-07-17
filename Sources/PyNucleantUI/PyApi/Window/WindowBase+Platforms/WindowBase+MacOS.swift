//
//  WindowBase+MacOS.swift
//  PyNucleantUI
//
//  Created by CodeBuilder on 13/07/2026.
//
import SulphurUI
import SulphurCore
import SulphurApplication

#if os(macOS)
import AppKit

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

extension WindowBase {
    
    
    
    final class PlatformWindow: NSWindow, NSWindowDelegate {
        
        public var on_close:            (()->Void)?
        
        weak var win_delegate: WindowBase?
        
        private var _displayLink: CVDisplayLink?
        
        let metalLayer: CAMetalLayer
        
        override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
            let view = DemoNSView(frame: .init(origin: .zero, size: contentRect.size))
            self.metalLayer = view.metalLayer
            super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
            self.contentView = view
            self.startDisplayLink()
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
        
        public func startDisplayLink() {
                if #available(macOS 14.0, *) {
                    startCADisplayLink()
                } else {
                    startCVDisplayLink()
                }
            }

            public func stopDisplayLink() {
                if let dl = _displayLink {
                    CVDisplayLinkStop(dl)
                    _displayLink = nil
                }
            }

    }
    
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




// MARK: - CVDisplayLink (macOS < 14)

//@available(macOS, introduced: 10.4, obsoleted: 14.0)
// ^ original annotation — `obsoleted` stops compiling under the macOS 14
// deployment floor (Observation), so `deprecated` stands in below. The
// whole CVDisplayLink path stays intact for a future pre-14 build.
@available(macOS, introduced: 10.4, deprecated: 14.0)
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


extension WindowBase {
    class WindowCommandItem: NSMenuItem {
        
        
        
        
        @objc func action( _ sender: Any?) {
            
        }
    }
}



#endif
