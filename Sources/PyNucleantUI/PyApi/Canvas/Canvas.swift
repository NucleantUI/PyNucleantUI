
@preconcurrency import PySwiftKit
@preconcurrency import PySerializing
import PySwiftWrapper

import SulphurUI
import SulphurCore

extension PyNucleantUI_Package {
    
    @PyModule(name: "nucleant.canvas")
    struct Canvas: PyModuleProtocol {
        
        static let py_classes: [any (PyClassProtocol & AnyObject).Type] = [
            ThorCanvasBase.self,
            ThorSceneBase.self,
            PixelBufferCanvasBase.self,
            SkiaCanvasBase.self,
            CanvasShader.self
        ]
        
    }
}
