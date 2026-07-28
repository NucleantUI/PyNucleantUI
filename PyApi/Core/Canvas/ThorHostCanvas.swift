//
//  ThorHostCanvas.swift
//  PyNucleantUI
//
//import NucleantVulkan
import NucleantVulkan
import PySwiftKit
//import CWgpu
import PySerializing
import PySwiftWrapper
import Observation
import Dispatch
import Foundation

import PyNucleantUI

import NucleantThorVG

public protocol ThorHostCanvas: PySerializable, PyClassProtocol, AnyObject {

    var id: Int { get }
    /// The widget holding this canvas. Canvases record their owner and
    /// widgets their parent — that chain is how nested scene canvases find
    /// the canvas they composite through.
    associatedtype Owner: WidgetProtocol
    var owner: Owner? { get set }

    /// The frame that sizes this canvas — handed down by the owner widget
    /// on assignment and on every later frame change. nil keeps the old
    /// behavior: adapt to the attach-time (nearest parent) size. Node
    /// canvases rebuild their render node to match; scene canvases only
    associatedtype Frame: FrameProtocol & AnyObject
    var frame: Frame? { get set }

    /// Bind into the render pipeline. Node canvases build (or adopt
    /// `ownNode`) their render node here; scene canvases resolve the
    /// nearest ancestor canvas and add themselves to it — the engine
    /// context is theirs to ignore.
    func attach(
        //engine:  VulkanRenderEngine,
        //wgpu:    WgpuContext,
        ownNode: ThorShaderNode<RenderNode<Frame>>?,
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

    /// Add / remove 2D content. Canvas-level add on node canvases,
    /// scene-level add on scene canvases — this is what lets scenes nest
    /// through whichever canvas kind they land on.
    func add(paint: Tvg_Paint)
    func remove(paint: Tvg_Paint)
}


