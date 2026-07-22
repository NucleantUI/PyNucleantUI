//
//  ThorCanvasBase.swift
//  SulphurXcodeDemo
//
//import NucleantVulkan
import NucleantVulkan
import PySwiftKit
import CWgpu
import PySerializing
import PySwiftWrapper
import Observation
import Dispatch
import Foundation


/// The general canvas contract — the one thing a widget holds and drives.
/// A widget's `canvas` slot is `any PyCanvasBase`, so the same slot takes
/// the render-node canvas (`PySulphurCanvasBase`) or the scene one
/// (`PySulphurSceneBase`); the widget never knows which. Each
/// implementation decides what `attach` means: build/adopt a render node,
/// or hook a scene into the nearest canvas up the tree.
public protocol PyCanvasBase: CanvasBase, PySerializable, PyClassProtocol, AnyObject {

    /// The widget holding this canvas. Canvases record their owner and
    /// widgets their parent — that chain is how nested scene canvases find
    /// the canvas they composite through.
    var owner: PyWidgetBase? { get set }

    /// The frame that sizes this canvas — handed down by the owner widget
    /// on assignment and on every later frame change. nil keeps the old
    /// behavior: adapt to the attach-time (nearest parent) size. Node
    /// canvases rebuild their render node to match; scene canvases only
    /// record it — their pixels live on the host's node.
    var frame: NucleantFrame? { get set }

    /// Bind into the render pipeline. Node canvases build (or adopt
    /// `ownNode`) their render node here; scene canvases resolve the
    /// nearest ancestor canvas and add themselves to it — the engine
    /// context is theirs to ignore.
    ///
    // same problem again WE SHOULDNT HAVE TO SEND ENGINE OR WEBGPU
    func attach(
        //engine:  VulkanRenderEngine,
        // wgpu:    WgpuContext,
        ownNode: VulkanRenderNode?,
        width:   Int,
        height:  Int
    )
}

extension PyCanvasBase {
    // same problem again WE SHOULDNT HAVE TO SEND ENGINE OR WEBGPU
    public func attach(
        //engine:  VulkanRenderEngine,
        //wgpu:    WgpuContext,
        ownNode: VulkanRenderNode?,
        width:   Int,
        height:  Int
    ) {
        //(ownNode as! Node).attach
        attach(ownNode: ownNode as? Node, width: width, height: height)
    }
}
