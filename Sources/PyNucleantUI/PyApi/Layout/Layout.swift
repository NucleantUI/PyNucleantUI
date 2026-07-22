//
//  Layout.swift
//  SulphurXcodeDemo
//


@preconcurrency import PySwiftKit
import PySerializing
import PySwiftWrapper

//import SulphurUI
//import NucleantVulkan





extension PyNucleantUI_Package {
    
    @PyModule(name: "nucleant.layout")
    struct Layout: PyModuleProtocol {
        
        static let py_classes: [any (PyClassProtocol & AnyObject).Type] = [
            NucleantFrame.self
        ]
        
    
        static let modules: [any PyModuleProtocol.Type] = [
            
        ]
        
        
    } // Layout
    
} // SulphurUI
