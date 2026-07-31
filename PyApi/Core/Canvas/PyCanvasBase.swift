//
//  ThorCanvasBase.swift
//  SulphurXcodeDemo
//
//import NucleantVulkan
import NucleantVulkan
import PySwiftKit
import PySerializing
import PySwiftWrapper
import Observation
import Dispatch
import Foundation
import PyNucleantUI
import PNU_Layout
/// The general canvas contract — the one thing a widget holds and drives.
/// A widget's `canvas` slot is `any PyCanvasBase`, so the same slot takes
/// the render-node canvas (`PySulphurCanvasBase`) or the scene one
/// (`PySulphurSceneBase`); the widget never knows which. Each
/// implementation decides what `attach` means: build/adopt a render node,
/// or hook a scene into the nearest canvas up the tree.
public protocol PyCanvasBase: CanvasBase, PySerializable, PyClassProtocol {


    var frame: Frame? { get set }
    /// Bind into the render pipeline. Node canvases build (or adopt
    /// `ownNode`) their render node here; scene canvases resolve the
    /// nearest ancestor canvas and add themselves to it — the engine
    /// context is theirs to ignore.
    ///
    // same problem again WE SHOULDNT HAVE TO SEND ENGINE OR WEBGPU
    func attach(
        //engine:  VulkanRenderEngine,
        // wgpu:    WgpuContext,
        ownNode: (any VulkanRenderNode)?,
        width:   Int,
        height:  Int
    )
}

extension PyCanvasBase {
    // same problem again WE SHOULDNT HAVE TO SEND ENGINE OR WEBGPU
    public func attach(
        //engine:  VulkanRenderEngine,
        //wgpu:    WgpuContext,
        ownNode: (any VulkanRenderNode)?,
        width:   Int,
        height:  Int
    ) {
        //(ownNode as! Node).attach
        attach(ownNode: ownNode as? Node, width: width, height: height)
    }
    
    func setFrame(_ frame: NucleantFrame?) {
        
    }
}
