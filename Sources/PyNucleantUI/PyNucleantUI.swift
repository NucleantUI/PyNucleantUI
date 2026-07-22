// The Swift Programming Language
// https://docs.swift.org/swift-book
@preconcurrency import PySwiftKit
import PySerializing
import PySwiftWrapper

//import SulphurUI
//import NucleantVulkan
//import SulphurApplication

@PyModule(name: "nucleant")
public struct PyNucleantUI_Package: PyModuleProtocol {
    
    public static let modules: [any (PyModuleProtocol).Type] = [
        //Canvas.self,
        //Layout.self,
        //UIX.self,
        AppModule.self,
        Window.self
    ]
    
}


