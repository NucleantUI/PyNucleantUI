//
//  Layout.swift
//  SulphurXcodeDemo
//


@preconcurrency import PySwiftKit
import PySerializing
import PySwiftWrapper

import SulphurUI
//import NucleantVulkan





extension PyNucleantUI_Package {
    
    @PyModule(name: "nucleant.layout")
    struct Layout: PyModuleProtocol {
        
        
        
        
        @PyFunction()
        static func init_core() {
            print("called init_core", Self.self)
        }
        
        
        
        
    } // Layout
    
} // SulphurUI
