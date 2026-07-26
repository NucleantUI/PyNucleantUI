//
//  PyApp.swift
//  PyNucleantUI
//


@preconcurrency import PySwiftKit
@preconcurrency import PySerializing
import PySwiftWrapper
import NucleantApplication
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
//import NucleantVulkan
import NucleantThorVG


@PyClass(
    name: "App",
    self_ref: true
)

final class PyApp: NucleantApplication {
    
    let __self__: PyPointer
    
    
    @PyInit
    init(__self__: PyPointer, threads: UInt32) {
        
        tvg_engine_init(threads)
        
        self.__self__ = __self__
        _on_start = "on_start"
        
        setup()
        
        
    }
    
    private var _on_start: PyPointer

    #if os(macOS) || os(iOS)
    var appDelegate: AppDelegate<PyApp>?
    #endif

    @PyMethod()
    func run() {
        #if os(macOS)
        NSApplication.shared.run()
        #elseif os(iOS)
        // The host entry point owns the UIApplication run loop (the ksproject
        // iOS template boots it, then runs this Python app module which reaches
        // here). So run() does what macOS's launch callback does: on_start
        // builds initial state and presents the window(s); each window's
        // CADisplayLink then drives frames on the already-running loop. (If the
        // iOS entry is ever changed to a bare Python boot with nothing owning
        // the loop, run() would call UIApplicationMain here instead — the
        // direct mirror of NSApplication.run().)
        onStart()
        #endif
    }
    
    var registeredWindows: [String:PyPointer] = [:]
    
    
    @PyMethod
    func register_window(name: String, window: PyPointer) {
        registeredWindows[name] = window
    }
    
    @PyMethod
    func open_registered_window(name: String) throws {
        if let py_cls = registeredWindows[name] {
            //let window = try WindowBase.casted(unsafe: PyObject_CallNoArgs(py_cls))
            // make window appear
            // PyObject_CallMethodNoArgs(self: UnsafeMutablePointer<PyObject>!, name: UnsafeMutablePointer<PyObject>!)
            // PyObject_CallMethodOneArg(self: UnsafeMutablePointer<PyObject>!, name: UnsafeMutablePointer<PyObject>!, arg: UnsafeMutablePointer<PyObject>!)
            // PyObject_VectorcallMethod(name: UnsafeMutablePointer<PyObject>!, args: UnsafePointer<UnsafeMutablePointer<PyObject>?>!, nargsf: Int, kwnames: UnsafeMutablePointer<PyObject>!)
        }
    }
    
    func onStart() {
        // Platform launch (NSApplicationDelegate.applicationDidFinishLaunching)
        // lands here — bridge it into Python's `on_start`, where the app
        // subclass builds initial state and presents its window(s).
        on_start()
    }
    
    //@PyMethod
    //func open_window(window: WindowBase) throws {
       //try window.present()
    //}
}

extension PyApp {
    
    @PyCallMethod(path: \Self.__self__)
    func on_start()
    
}

extension PyNucleantUI_Package {
    @PyModule(name: "_nucleant.app")
    struct AppModule: PyModuleProtocol {
        
        static let py_classes: [any (PyClassProtocol & AnyObject).Type] = [
            PyApp.self
        ]
    }
}


