//
//  RenderBinder.swift
//  PyNucleantUI
//
//  Created by CodeBuilder on 28/07/2026.
//
import PyNucleantUI
import PNU_Layout

// MARK: - Widget tree → engine binding

/// The single app-layer seam that pairs a canvas with the render node it
/// drives — the same knowledge `RenderNode.Context` centralises, kept in the
/// same file for the same reason: this is what a future build plugin
/// regenerates per enabled backend. Enable/disable Skia or ThorVG and only
/// this file changes; the window and widget layers never name a canvas kind
/// and so never break.
///
/// The window owns the engine and calls `bind(tree:into:…)` once its
/// `on_build` tree exists. It hands over a `PyWidgetBase` root and its engine
/// and gets back a fully-attached composite — it never relates to a canvas
/// itself.
public enum RenderBinder {

    /// Walk the tree and bind every canvas in it into `engine`.
    public static func bind(tree root: PyWidgetBase, into engine: RenderEngine, width: Int, height: Int) {
        bind(widget: root, into: engine, width: width, height: height)
    }

    private static func bind(widget: PyWidgetBase, into engine: RenderEngine, width: Int, height: Int) {
        if let canvas = widget._canvas {
            bindSlot(for: canvas, into: engine, width: width, height: height)
        }
        for child in widget.children {
            bind(widget: child, into: engine, width: width, height: height)
        }
    }

    /// The one switch over canvas kinds: build the node the canvas kind maps
    /// to (backend factories on the engine), append it as an id-keyed slot,
    /// hand the engine to the canvas (its only sanctioned engine touch — post
    /// shaders / detach), then hand the built node down. This is the part a
    /// backend config regenerates; adding a kind is a case here plus a case in
    /// `Context`, nothing in the window.
    private static func bindSlot(for canvas: any PyCanvasBase, into engine: RenderEngine, width: Int, height: Int) {
        // A frame set on the canvas wins over the window size; without one the
        // canvas fills the window.
        let size = canvas.frame?.size ?? .zero
        let w = size.x != 0 ? Int(size.x) : width
        let h = size.y != 0 ? Int(size.y) : height
        //let w = canvas.frame.map { Int($0.size.x) } ?? width
        //let h = canvas.frame.map { Int($0.size.y) } ?? height

        switch canvas {
        case let skia as SkiaCanvasBase:
            do {
                let context = try engine.makeSkiaContext()
                guard let node = engine.makeSkiaWidgetNode(context: context, width: w, height: h) else {
                    print("RenderBinder: skia node build (\(w)x\(h)) failed")
                    return
                }
                skia.bind(engine: engine)
                let slot = RenderNode(id: skia.id, context: .skia(node))
                slot.frame = skia.frame
                slot.observeContext()
                engine.append(slot)
                skia.attach(ownNode: node, width: w, height: h)
            } catch {
                print("RenderBinder: skia context creation failed: \(error)")
            }

        case let pixel as PixelBufferCanvasBase:
            // Content-sized (source × scale), never the widget frame — the
            // producer writes a fixed resolution and the composite scales it.
            do {
                let node = try engine.makePixelBufferNode(
                    width:  pixel.contentWidth,
                    height: pixel.contentHeight,
                    scale:  pixel.contentScale
                )
                pixel.bind(engine: engine)
                let slot = RenderNode(id: pixel.id, context: .pixel_buffer(node))
                slot.frame = pixel.frame
                slot.observeContext()
                engine.append(slot)
                pixel.attach(ownNode: node, width: pixel.contentWidth, height: pixel.contentHeight)
            } catch {
                print("RenderBinder: pixel buffer node build failed: \(error)")
            }

        case let pyBuffer as PyBufferCanvasBase:
            // Same content-sized contract as the pixel canvas; the node
            // differs only in reading its bytes through Python's buffer
            // protocol rather than from Swift-held ones.
            do {
                let node = try engine.makePyBufferNode(
                    width:  pyBuffer.contentWidth,
                    height: pyBuffer.contentHeight,
                    scale:  pyBuffer.contentScale
                )
                pyBuffer.bind(engine: engine)
                let slot = RenderNode(id: pyBuffer.id, context: .py_buffer(node))
                slot.frame = pyBuffer.frame
                slot.observeContext()
                engine.append(slot)
                pyBuffer.attach(ownNode: node, width: pyBuffer.contentWidth, height: pyBuffer.contentHeight)
            } catch {
                print("RenderBinder: py buffer node build failed: \(error)")
            }

        // Zero-copy on every platform: NucleantThorVG's
        // VulkanRenderEngine+Thor.swift imports the wgpu target's backing
        // memory straight into a VkImage — VK_EXT_metal_objects on Apple,
        // VK_KHR_external_memory_fd on Linux.
        case let thor as ThorCanvasBase:
            // The engine builds the wgpu-backed node and adopts the canvas's
            // own `Tvg_Canvas` (so capsules Python already took stay valid).
            // All webgpu is inside makeThorWidgetNode / NucleantThorVG — this
            // seam only forwards the opaque ThorVG canvas handle.
            guard let node = engine.makeThorWidgetNode(adopting: thor.base, width: w, height: h) else {
                print("RenderBinder: thor node build (\(w)x\(h)) failed")
                return
            }
            thor.bind(engine: engine)
            let slot = RenderNode(id: thor.id, context: .thor(node))
            slot.frame = thor.frame
            slot.observeContext()
            engine.append(slot)
            thor.attach(ownNode: node, width: w, height: h)

        default:
            print("RenderBinder: unhandled canvas kind \(type(of: canvas)) — skipped")
        }
    }
}
