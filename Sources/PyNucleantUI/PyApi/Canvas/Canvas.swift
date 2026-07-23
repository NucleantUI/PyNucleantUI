//
//  Canvas.swift
//  PyNucleantUI
//
//  Created by CodeBuilder on 23/07/2026.
//



@preconcurrency import PySwiftKit
@preconcurrency import PySerializing
import PySwiftWrapper

//mport SulphurUI
//import NucleantVulkan

extension PyNucleantUI_Package {
    
    @PyModule(name: "nucleant.canvas")
    struct Canvas: PyModuleProtocol {
        
        static let py_classes: [any (PyClassProtocol & AnyObject).Type] = [
            ThorCanvasBase.self,
            //ThorSceneBase.self,
            PixelBufferCanvasBase.self,
            PyBufferCanvasBase.self,
            SkiaCanvasBase.self,
            CanvasShader.self
        ]
        
    }
}
