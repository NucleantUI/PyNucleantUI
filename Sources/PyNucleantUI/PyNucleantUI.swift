// The Swift Programming Language
// https://docs.swift.org/swift-book
@preconcurrency import PySwiftKit
import PySerializing
import PySwiftWrapper

//import SulphurUI
//import NucleantVulkan
//import SulphurApplication

@PyModule(name: "_nucleant")
public struct PyNucleantUI_Package: PyModuleProtocol {

    public static let modules: [any (PyModuleProtocol).Type] = [

        Layout.self,
        //UIX.self,
        AppModule.self,
        Canvas.self,
        Widget.self,
        Window.self
    ]
    
}


extension Int {
    var asDouble: Double { .init(self) }
    
    func scaled(_ scale: Double) -> Double {
        self.asDouble * scale
    }
}

extension Double {
    var asInt: Int { .init(self) }
    
    func scaled(_ scale: Double) -> Double {
        self * scale
    }
}
