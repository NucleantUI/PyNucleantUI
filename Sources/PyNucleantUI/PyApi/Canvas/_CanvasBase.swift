//
//  CanvasBase.swift
//  PyNucleantUI
//
import PySwiftKit
import PySerializing



public enum __CanvasBase {
    case thorCanvas(ThorCanvasBase)
    case thorScene(ThorSceneBase)
    case skiaSurface(SkiaCanvasBase)
    case pixelBuffer(PixelBufferCanvasBase)
    case ogl(PixelBufferCanvasBase)
}

extension __CanvasBase {
    public func setFrame(_ frame: NucleantFrame?) {
        switch self {
        case .thorCanvas(let thorCanvasBase):
            thorCanvasBase.frame = frame
        case .thorScene(let thorSceneBase):
            thorSceneBase.frame = frame
        case .skiaSurface(let skiaCanvasBase):
            skiaCanvasBase.frame = frame
        case .pixelBuffer(let pixelBufferCanvasBase):
            pixelBufferCanvasBase.frame = frame
        case .ogl(let pixelBufferCanvasBase):
            pixelBufferCanvasBase.frame = frame
        }
    }
    
    public func attach(
            engine:  VulkanRenderEngine,
            wgpu:    WgpuContext,
            ownNode: VulkanRenderNode?,
            width:   Int,
            height:  Int
    ) {
        switch self {
        case .thorCanvas(let thorCanvasBase):
            thorCanvasBase.attach(
                engine: engine,
                wgpu: wgpu,
                ownNode: ownNode as? ThorShaderNode,
                width: width,
                height: height
            )
        case .thorScene(let thorSceneBase):
            thorSceneBase.attach(
                engine: engine,
                wgpu: wgpu,
                ownNode: ownNode as? ThorShaderNode,
                width: width,
                height: height
            )
        case .skiaSurface(let skiaCanvasBase):
            skiaCanvasBase.attach(
                engine: engine,
                wgpu: wgpu,
                ownNode: ownNode as? SkiaShaderNode,
                width: width,
                height: height
            )
        case .pixelBuffer(let pixelBufferCanvasBase):
            pixelBufferCanvasBase.attach(
                engine: engine,
                wgpu: wgpu,
                ownNode: ownNode as? ThorShaderNode,
                width: width,
                height: height
            )
        case .ogl(let pixelBufferCanvasBase):
            pixelBufferCanvasBase.attach(
                engine: engine,
                wgpu: wgpu,
                ownNode: ownNode as? ThorShaderNode,
                width: width,
                height: height
            )
        }
    }
    
    public func detach() {
        switch self {
        case .thorCanvas(let thorCanvasBase):
            thorCanvasBase.detach()
        case .thorScene(let thorSceneBase):
            thorSceneBase.detach()
        case .skiaSurface(let skiaCanvasBase):
            skiaCanvasBase.detach()
        case .pixelBuffer(let pixelBufferCanvasBase):
            pixelBufferCanvasBase.detach()
        case .ogl(let pixelBufferCanvasBase):
            pixelBufferCanvasBase.detach()
        }
    }
}

extension __CanvasBase: PySerializable {
    public func pyPointer() -> PyPointer {
        switch self {
        case .thorCanvas(let thorCanvasBase):
            thorCanvasBase.pyPointer()
        case .thorScene(let thorSceneBase):
            thorSceneBase.pyPointer()
        case .skiaSurface(let skiaCanvasBase):
            skiaCanvasBase.pyPointer()
        case .pixelBuffer(let pixelBufferCanvasBase):
            pixelBufferCanvasBase.pyPointer()
        case .ogl(let pixelBufferCanvasBase):
            pixelBufferCanvasBase.pyPointer()
        }
    }
    
    public static func casted(unsafe object: PyPointer) throws -> __CanvasBase {
        switch object {
        case ThorCanvasBase.PyType:
            return .thorCanvas(try .casted(unsafe: object))
        case ThorSceneBase.PyType:
            return .thorScene(try .casted(unsafe: object))
        case SkiaCanvasBase.PyType:
            return .skiaSurface(try .casted(unsafe: object))
        case PixelBufferCanvasBase.PyType:
            return .pixelBuffer(try .casted(unsafe: object))
        default:
            pyPrint(object)
            fatalError("pytype not accepted")
        }
    }
    
    public static func casted(from object: PyPointer) throws -> __CanvasBase {
        try casted(unsafe: object)
    }
}

