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
import PySwiftKit
import PySerializing
import PyNucleantUI

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

/// Cross-axis placement within a `VerticalLayout` — where a child narrower
/// than the container sits along the horizontal axis. `Int`-backed (0/1/2)
/// so it crosses to Python as a raw value; the layout `@PyClass`es take it
/// that way in their `__init__`.
public enum HorizontalAlignment: Int, Sendable, PySerializable {
    case leading
    case center
    case trailing
}

/// Cross-axis placement within a `HorizontalLayout` — where a child shorter
/// than the container sits along the vertical axis. Same raw values as
/// `HorizontalAlignment` (start = 0, center = 1, end = 2).
public enum VerticalAlignment: Int, Sendable, PySerializable {
    case top
    case center
    case bottom
}

/// How one grid track sizes itself — modelled on SwiftUI's `GridItem.Size`.
/// `Int`-backed (0/1/2) so it crosses to Python as a raw value.
public enum GridSize: Int, Sendable, PySerializable {
    /// An exact extent — `GridItem.minimum` is the size.
    case fixed
    /// A share of the leftover length, clamped to `[minimum, maximum]`.
    case flexible
    /// As many `[minimum, maximum]`-sized cells as fit in one flexible slot.
    case adaptive
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

    /// Whether a child has no fixed extent on `axis` — `nil` (flexible on
    /// both axes) or a frame flagging that axis (`flexibleWidth` /
    /// `flexibleHeight`). Shared by every layout so "flexible == the layout
    /// supplies the size here" reads the same way for stacks and grids.
    static func isFlexible<Frame: FrameProtocol>(
        _ child: Frame?,
        along axis: Orientation
    ) -> Bool {
        guard let child else { return true }
        switch axis {
        case .horizontal: return child.flexibleWidth
        case .vertical: return child.flexibleHeight
        }
    }

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
        crossAlignment: Int = 0
    ) -> [SIMD4<Double>] {
        let cross = orientation.perpendicular

        let totalSpacing = spacing * Double(max(children.count - 1, 0))
        let fixedLength = children.reduce(0.0) { total, child in
            isFlexible(child, along: orientation)
                ? total
                : total + (child?.size[component: orientation] ?? 0)
        }
        let flexibleCount = children.filter { isFlexible($0, along: orientation) }.count
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
            size[component: orientation] = isFlexible(child, along: orientation)
                ? flexibleLength
                : (child?.size[component: orientation] ?? 0)
            size[component: cross] = isFlexible(child, along: cross)
                ? container.size[component: cross]
                : (child?.size[component: cross] ?? 0)

            let slack = container.size[component: cross] - size[component: cross]
            // rawValue 0/1/2 → start / center / end: 0, slack/2, slack.
            let crossOffset = slack * Double(crossAlignment) / 2

            var pos = SIMD2<Double>.zero
            pos[component: orientation] = offset
            pos[component: cross] = container.pos[component: cross] + crossOffset

            frames.append(SIMD4(pos.x, pos.y, size.x, size.y))
            offset += size[component: orientation] + spacing
        }

        return frames
    }

    /// Grid pass driven by per-track `GridItem`s (SwiftUI's LazyV/HGrid).
    /// `tracks` describe the cross-axis lanes — columns when the growth
    /// `orientation` is `.vertical`, rows when `.horizontal`; children flow
    /// across the tracks and wrap into a new line along the growth axis.
    /// `lineSpacing` gaps the wrapped lines; each track's own `spacing` gaps
    /// it from the next track.
    ///
    /// Track sizing along the cross axis: `.fixed` takes its `minimum`;
    /// `.flexible` (and, for now, `.adaptive`) split the leftover cross length,
    /// each clamped to its `[minimum, maximum]`. Lines split the growth-axis
    /// length evenly. Per cell, a child flexible on an axis fills the cell
    /// there; a fixed axis keeps the child's own extent, aligned by
    /// `alignment` (0/1/2). Returns one frame per child, in child order.
    public static func computeGridFrames<Frame: FrameProtocol>(
        container: Frame,
        children: [Frame?],
        tracks: [GridItem],
        orientation: Orientation,
        lineSpacing: Double = 0,
        alignment: Int = 0
    ) -> [SIMD4<Double>] {
        let count = children.count
        guard count > 0, !tracks.isEmpty else { return [] }

        let cross = orientation.perpendicular
        let trackCount = tracks.count

        // --- Resolve track extents along the cross axis ------------------
        // Gap after each track but the last (GridItem.spacing; < 0 = none).
        let gaps: [Double] = (0..<trackCount).map { i in
            i == trackCount - 1 ? 0 : max(tracks[i].spacing, 0)
        }
        let crossAvail = max(container.size[component: cross] - gaps.reduce(0, +), 0)

        let fixedSum = tracks.reduce(0.0) { $0 + ($1.sizing == .fixed ? $1.minimum : 0) }
        let flexCount = tracks.filter { $0.sizing != .fixed }.count
        let perFlex = flexCount > 0 ? max(crossAvail - fixedSum, 0) / Double(flexCount) : 0

        var trackExtent = [Double](repeating: 0, count: trackCount)
        var trackOffset = [Double](repeating: 0, count: trackCount)
        var run = container.pos[component: cross]
        for (i, t) in tracks.enumerated() {
            let extent = t.sizing == .fixed
                ? t.minimum
                : min(max(perFlex, t.minimum), t.maximum)
            trackExtent[i] = max(extent, 0)
            trackOffset[i] = run
            run += trackExtent[i] + gaps[i]
        }

        // --- Lines along the growth axis, split evenly -------------------
        let lineCount = (count + trackCount - 1) / trackCount
        let mainAvail = max(
            container.size[component: orientation] - lineSpacing * Double(lineCount - 1),
            0
        )
        let lineExtent = lineCount > 0 ? mainAvail / Double(lineCount) : 0

        var frames: [SIMD4<Double>] = []
        frames.reserveCapacity(count)

        for (i, child) in children.enumerated() {
            let trackIdx = i % trackCount
            let lineIdx = i / trackCount

            var cellSize = SIMD2<Double>.zero
            cellSize[component: cross] = trackExtent[trackIdx]
            cellSize[component: orientation] = lineExtent

            var cellPos = SIMD2<Double>.zero
            cellPos[component: cross] = trackOffset[trackIdx]
            cellPos[component: orientation] =
                container.pos[component: orientation]
                + Double(lineIdx) * (lineExtent + lineSpacing)

            // Flexible axis → fill the cell; fixed axis → keep the child size.
            let proposal = ProposedViewSize(
                isFlexible(child, along: .horizontal) ? cellSize.x : nil,
                isFlexible(child, along: .vertical) ? cellSize.y : nil
            )
            let size = proposal.replacingUnspecifiedDimensions(by: child?.size ?? .zero)

            // rawValue 0/1/2 → start / center / end within the cell.
            let x = cellPos.x + (cellSize.x - size.x) * Double(alignment) / 2
            let y = cellPos.y + (cellSize.y - size.y) * Double(alignment) / 2

            frames.append(SIMD4(x, y, size.x, size.y))
        }

        return frames
    }
}
