// The Swift Programming Language
// https://docs.swift.org/swift-book
@preconcurrency import PySwiftKit
import PySerializing
import PySwiftWrapper

import SulphurUI
import SulphurCore
import SulphurApplication

@PyModule(name: "nucleant")
public struct PyNucleantUI_Package: PyModuleProtocol {
    
    @PyFunction()
    public static func init_core() {
        print("called init_core", Self.self)
        
    }
    
    public static let modules: [any (PyModuleProtocol).Type] = [
        Layout.self,
        UIX.self,
        AppModule.self,
        Window.self
    ]
    
}
