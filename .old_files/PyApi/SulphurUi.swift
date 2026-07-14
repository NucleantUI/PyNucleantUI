//
//  SulphurUi.swift
//  SulphurXcodeDemo
//
@preconcurrency import PySwiftKit
import PySerializing
import PySwiftWrapper

import SulphurUI
import SulphurCore
import SulphurApplication

@PyModule
struct SulphurUi: PyModuleProtocol {
    
    @PyFunction()
    static func init_core() {
        print("called init_core", Self.self)
        
    }
    
    static let modules: [any (PyModuleProtocol).Type] = [
        Layout.self,
        UIX.self,
        py_app.self,
        Window.self
    ]
    
}
