//
//  Layout.swift
//  SulphurXcodeDemo
//
//  Created by CodeBuilder on 24/06/2026.
//

@preconcurrency import PySwiftKit
import PySerializing
import PySwiftWrapper

import SulphurUI
import SulphurCore

extension SulphurUi {
    
    @PyModule(name: "sulphur_ui.layout")
    struct Layout: PyModuleProtocol {
        
        
        
        
        @PyFunction()
        static func init_core() {
            print("called init_core", Self.self)
        }
        
        
        
        
    } // Layout
    
} // SulphurUI
