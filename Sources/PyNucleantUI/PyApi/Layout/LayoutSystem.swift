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
    /// Children keep their size on any axis they fix, and are re-positioned.
    /// A child is *flexible* on an axis when it is `nil` (flexible on both) or
    /// its frame flags that axis (`flexibleWidth` / `flexibleHeight`).
    /// Flexible stack-axis children split the leftover length equally;
    /// flexible cross-axis children fill the container — swift-cross-ui
    /// proposes `(length - spaceUsed - reservedSpace) / childrenRemaining` to
    /// each child in flexibility order; with all fixed sizes known up front
    /// that walk reduces to this equal split of what fixed children and
    /// spacing leave over.
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

        // A `nil` child is flexible on both axes; a present child is flexible
        // only where its frame flags say so. Flexible == "no fixed extent
        // here", i.e. the layout supplies the size on that axis.
        func flexible(_ child: Frame?, along axis: Orientation) -> Bool {
            guard let child else { return true }
            switch axis {
            case .horizontal: return child.flexibleWidth
            case .vertical: return child.flexibleHeight
            }
        }

        let totalSpacing = spacing * Double(max(children.count - 1, 0))
        let fixedLength = children.reduce(0.0) { total, child in
            flexible(child, along: orientation)
                ? total
                : total + (child?.size[component: orientation] ?? 0)
        }
        let flexibleCount = children.filter { flexible($0, along: orientation) }.count
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
            size[component: orientation] = flexible(child, along: orientation)
                ? flexibleLength
                : (child?.size[component: orientation] ?? 0)
            size[component: cross] = flexible(child, along: cross)
                ? container.size[component: cross]
                : (child?.size[component: cross] ?? 0)

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
