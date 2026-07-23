//
//  LayoutSystem.swift
//  PyNucleantUI
//
//  Stack maths adapted from swift-cross-ui's LayoutSystem
//  (https://github.com/moreSwift/swift-cross-ui, Sources/SwiftCrossUI/Layout).
//  Their system probes every child twice (minimum/maximum proposals) to rank
//  flexibility because any view may stretch; here a child's own frame *is*
//  its fixed size and a frameless child is fully flexible, so the ranking
//  collapses — see `computeStackFrames`.
//

//import SulphurUI
import simd

/// The stack axis. Mirrors swift-cross-ui's `Orientation`, which lets one
/// shared algorithm drive both stack directions via `subscript(component:)`.
public enum Orientation: Sendable {
    case horizontal
    case vertical

    public var perpendicular: Orientation {
        switch self {
        case .horizontal: .vertical
        case .vertical: .horizontal
        }
    }
}

/// Cross-axis placement of children that keep their own (smaller) size.
/// Frameless children fill the cross axis, so alignment never moves them.
public enum StackAlignment: Sendable {
    case leading
    case center
    case trailing
}

extension SIMD2 where Scalar == Double {
    /// The component along the given stack axis (x for horizontal, y for
    /// vertical) — swift-cross-ui's trick for writing the stack maths once.
    public subscript(component orientation: Orientation) -> Double {
        get {
            switch orientation {
            case .horizontal: x
            case .vertical: y
            }
        }
        set {
            switch orientation {
            case .horizontal: x = newValue
            case .vertical: y = newValue
            }
        }
    }
}

public enum LayoutSystem {

    /// Stack layout over plain frames, in the container's coordinate space
    /// (children start at `container.pos`, i.e. absolute when the container
    /// frame is absolute).
    ///
    /// Children with a frame keep their size and are only re-positioned.
    /// `nil` children split the leftover length equally and fill the cross
    /// axis — swift-cross-ui proposes
    /// `(length - spaceUsed - reservedSpace) / childrenRemaining` to each
    /// child in flexibility order; with all fixed sizes known up front that
    /// walk reduces to this equal split of what fixed children and spacing
    /// leave over.
    ///
    /// Returns one frame per child, in child order. `SIMD4` (x, y, w, h) is
    /// the plain frame value SulphurUI already treats as a `FrameProtocol`.
    public static func computeStackFrames<Frame: FrameProtocol>(
        container: Frame,
        children: [Frame?],
        orientation: Orientation,
        spacing: Double = 0,
        alignment: StackAlignment = .leading
    ) -> [SIMD4<Double>] {
        let cross = orientation.perpendicular

        let totalSpacing = spacing * Double(max(children.count - 1, 0))
        let fixedLength = children.reduce(0.0) { total, child in
            total + (child?.size[component: orientation] ?? 0)
        }
        let flexibleCount = children.filter { $0 == nil }.count
        let leftover = max(
            container.size[component: orientation] - fixedLength - totalSpacing,
            0
        )
        let flexibleLength = flexibleCount > 0 ? leftover / Double(flexibleCount) : 0

        var frames: [SIMD4<Double>] = []
        frames.reserveCapacity(children.count)

        var offset = container.pos[component: orientation]
        for child in children {
            var size = SIMD2<Double>.zero
            if let child {
                size = child.size
            } else {
                size[component: orientation] = flexibleLength
                size[component: cross] = container.size[component: cross]
            }

            let slack = container.size[component: cross] - size[component: cross]
            let crossOffset: Double = switch alignment {
            case .leading: 0
            case .center: slack / 2
            case .trailing: slack
            }

            var pos = SIMD2<Double>.zero
            pos[component: orientation] = offset
            pos[component: cross] = container.pos[component: cross] + crossOffset

            frames.append(SIMD4(pos.x, pos.y, size.x, size.y))
            offset += size[component: orientation] + spacing
        }

        return frames
    }
}
