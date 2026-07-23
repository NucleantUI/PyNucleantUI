//
//  Widget.swift
//  PyNucleantUI
//

@preconcurrency import PySwiftKit
@preconcurrency import PySerializing
import PySwiftWrapper

//import NucleantVulkan

extension PyNucleantUI_Package {
    
    @PyModule(name: "nucleant.widget")
    struct Widget: PyModuleProtocol {
        
        static let py_classes: [any (PyClassProtocol & AnyObject).Type] = [
            PyWidgetBase.self
        ]
        
    }
}
