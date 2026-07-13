//
//  UIX.swift
//  SulphurXcodeDemo
//
@preconcurrency import PySwiftKit
@preconcurrency import PySerializing
import PySwiftWrapper

import SulphurUI
import SulphurCore

extension PyNucleantUI_Package {
    
    @PyModule(name: "nucleant.uix")
    struct UIX: PyModuleProtocol {
        
        @PyFunction()
        static func init_core() {
            print("called init_core", Self.self)
        }
        
        @PyModule(name: "nucleant.uix.widget")
        struct Widget: PyModuleProtocol {
            
            @PyFunction()
            static func init_core() {
                print("called init_core", Self.self)
            }
            
            static let py_classes: [any (PyClassProtocol & AnyObject).Type] = [
                SulphurWidgetBase.self,
                PySulphurCanvasBase.self,
                PySulphurSceneBase.self,
                CanvasShader.self
            ]
            
        }
        
    }
}
