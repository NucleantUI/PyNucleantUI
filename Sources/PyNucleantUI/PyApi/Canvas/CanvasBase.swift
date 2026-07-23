//
//  CanvasBase.swift
//  PyNucleantUI
//
import PySwiftKit
import PySerializing
import NucleantVulkan
//import SulphurUI

public protocol CanvasBase: AnyObject, Identifiable {

    var id: Int { get }
    /// The widget holding this canvas. Canvases record their owner and
    /// widgets their parent — that chain is how nested scene canvases find
    /// the canvas they composite through.
    associatedtype Widget: WidgetProtocol
    var owner: Widget? { get set }

    /// The frame that sizes this canvas — handed down by the owner widget
    /// on assignment and on every later frame change. nil keeps the old
    /// behavior: adapt to the attach-time (nearest parent) size. Node
    /// canvases rebuild their render node to match; scene canvases only
    /// record it — their pixels live on the host's node.
    associatedtype Frame: FrameProtocol
    var frame: Frame? { get set }

    /// Bind into the render pipeline. Node canvases build (or adopt
    /// `ownNode`) their render node here; scene canvases resolve the
    /// nearest ancestor canvas and add themselves to it — the engine
    /// context is theirs to ignore.
    associatedtype Node: VulkanRenderNode
    
    // same problem again WE SHOULDNT HAVE TO SEND ENGINE OR WEBGPU
    func attach(
        //engine:  VulkanRenderEngine,
        //wgpu:    WgpuContext,
        ownNode: Node?,
        width:   Int,
        height:  Int
    )

    /// Undo `attach`: node canvases leave the composite list, scene
    /// canvases take their paint back off the host.
    func detach()

    /// Per-frame tick from the owning widget: flag for redraw and drive
    /// this canvas's own Python `update_canvas` hook if it has one.
    func on_render(dt: Double)

    /// Flag for redraw this frame.
    func markDirty()

}


