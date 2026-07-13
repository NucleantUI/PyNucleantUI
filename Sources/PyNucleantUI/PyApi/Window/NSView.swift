//
//  NSView.swift
//  SulphurXcodeDemo
//
import AppKit
import QuartzCore
import Metal

/// An NSView backed by a CAMetalLayer, suitable for MoltenVK VkSurface creation.
///
/// Wire up `onFrame` to your Vulkan render loop; it receives the display-link
/// delta time in seconds.  Pass `metalLayer` to vkCreateMetalSurfaceEXT.
public final class DemoNSView: NSView {

    /// The Metal layer MoltenVK uses for VkSurface creation.
    public private(set) var metalLayer: CAMetalLayer!

    /// Called on the main thread each display-link tick with Δt in seconds.
    public var onFrame: ((Double) -> Void)?
    public var on_build: (()->Void)?

    private var _displayLink: CVDisplayLink?

    // MARK: - Init

    public override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        let ml = CAMetalLayer()
        ml.device           = MTLCreateSystemDefaultDevice()
        ml.pixelFormat      = .bgra8Unorm
        ml.framebufferOnly  = false
        ml.frame            = bounds
        ml.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer      = ml
        metalLayer = ml
    }

    public override func makeBackingLayer() -> CALayer {
        let ml = CAMetalLayer()
        ml.device          = MTLCreateSystemDefaultDevice()
        ml.pixelFormat     = .bgra8Unorm
        ml.framebufferOnly = false
        return ml
    }

    // MARK: - Display link

    public func startDisplayLink() {
        if #available(macOS 14.0, *) {
            startCADisplayLink()
        } else {
            startCVDisplayLink()
        }
    }

    public func stopDisplayLink() {
        if let dl = _displayLink {
            CVDisplayLinkStop(dl)
            _displayLink = nil
        }
    }

    @MainActor
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { startDisplayLink() } else { stopDisplayLink() }
    }

    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        metalLayer.drawableSize = convertToBacking(bounds).size
    }

    @MainActor
    deinit {
        stopDisplayLink()
    }

    // MARK: - Input events

    public override var acceptsFirstResponder: Bool { true }

    private var trackingArea: NSTrackingArea?

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    
}

// MARK: - CVDisplayLink (macOS < 14)

@available(macOS, introduced: 10.4, obsoleted: 14.0)
private extension DemoNSView {
    func startCVDisplayLink() {
        var dl: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&dl)
        guard let link = dl else { return }
        _displayLink = link

        let ref = Unmanaged.passUnretained(self)
        CVDisplayLinkSetOutputCallback(link, { _, _, outputTime, _, _, ctx -> CVReturn in
            guard let ctx else { return kCVReturnError }
            let ot = outputTime.pointee
            let dt = Double(ot.videoRefreshPeriod) / Double(ot.videoTimeScale)
            let view = Unmanaged<DemoNSView>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async { view.onFrame?(dt) }
            return kCVReturnSuccess
        }, ref.toOpaque())

        CVDisplayLinkStart(link)
    }
}

// MARK: - CADisplayLink (macOS 14+)

@available(macOS 14.0, *)
private extension DemoNSView {
    func startCADisplayLink() {
        let link = displayLink(target: self, selector: #selector(cadlTick(_:)))
        link.add(to: .main, forMode: .common)
    }

    @objc func cadlTick(_ link: CADisplayLink) {
        onFrame?(link.targetTimestamp - link.timestamp)
    }
}


