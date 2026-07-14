//
//  PyApp+MacOS.swift
//  PyNucleantUI
//

#if os(macOS)
import AppKit

extension PyApp {
    
    func setup() {
        // NSApplication is a singleton: a plain NSApplication() here makes any
        // later sharedApplication call throw "Creating more than one Application".
        let app = NSApplication.shared
        let delegate = AppDelegate(py_app: self)
        // NSApplication.delegate is weak — retain the delegate on self.
        appDelegate = delegate
        app.delegate = delegate
    }
    
    public final class AppDelegate: NSObject, NSApplicationDelegate {
        
        weak var py_app: PyApp?
        
        public init(py_app: PyApp) {
            self.py_app = py_app
            super.init()
        }

        public func applicationDidFinishLaunching(_ notification: Notification) {
            let width:  CGFloat = 800
            let height: CGFloat = 600
            let rect = NSRect(x: 200, y: 200, width: width, height: height)
            
    //        window = NSWindow(
    //            contentRect: rect,
    //            styleMask: [.titled, .closable, .miniaturizable, .resizable],
    //            backing: .buffered,
    //            defer: false
    //        )
    //
    //        let view = SulphurNSView(frame: NSRect(origin: .zero, size: rect.size))
    //        view.onFrame = on_frame
    //        view.onMouseDown = on_mouse_down
    //        view.onMouseUp = on_mouse_up
    //        view.onMouseDragged = on_mouse_dragged
    //        view.onMouseMoved = on_mouse_moved
    //        view.onRightMouseDown = on_right_mouse_down
    //        view.onRightMouseUp = on_right_mouse_up
    //        view.onScrollWheel = on_scroll
    //        view.onKeyDown = on_key_down
    //        view.onKeyUp = on_key_up
    //        window.title = "Sulphur"
    //        window.contentView = view
    //        window.makeKeyAndOrderFront(nil)
    //        window.makeFirstResponder(view)
            py_app?.on_start()
        }

        public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

        public func applicationWillTerminate(_ notification: Notification) {
            
        }
    }

    
}


#endif
