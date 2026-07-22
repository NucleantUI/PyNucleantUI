//
//  PyApp.swift
//  PyNucleantUI
//


@preconcurrency import PySwiftKit
@preconcurrency import PySerializing
import PySwiftWrapper
import NucleantApplication
import AppKit
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

    #if os(macOS)
    var appDelegate: AppDelegate<PyApp>?
    #endif
    
    @PyMethod()
    func run() {
        NSApplication.shared.run()
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
    @PyModule(name: "nucleant.app")
    struct AppModule: PyModuleProtocol {
        
        static let py_classes: [any (PyClassProtocol & AnyObject).Type] = [
            PyApp.self
        ]
    }
}


