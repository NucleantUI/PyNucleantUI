//
//  Canvas.swift
//  PyNucleantUI
//

@preconcurrency import PySwiftKit
import PySwiftWrapper
import PNU_Layout
import PNU_Core

@PyModule
fileprivate struct canvas: PyModuleProtocol {
    
    static let py_classes: [any (PyClassProtocol & AnyObject).Type] = [
        ThorCanvasBase.self,
        //ThorSceneBase.self,
        PixelBufferCanvasBase.self,
        PyBufferCanvasBase.self,
        SkiaCanvasBase.self,
        CanvasShader.self
    ]
    
}
