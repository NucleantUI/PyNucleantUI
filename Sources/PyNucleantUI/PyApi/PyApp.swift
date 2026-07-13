//
//  PyApp.swift
//  PyNucleantUI
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
    
    
    @PyInit
    init(__self__: PyPointer) {
        self.__self__ = __self__
    }
    
    private var _on_start: PyPointer?
    
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
            let window = try WindowBase.casted(unsafe: PyObject_CallNoArgs(py_cls))
            // make window appear
            
        }
    }
    
    @PyMethod
    func open_window(window: WindowBase) throws {
        window.platformWindow.makeFirstResponder(nil)
    }
}

extension PyApp {
    
    @PyCall(method: true)
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
