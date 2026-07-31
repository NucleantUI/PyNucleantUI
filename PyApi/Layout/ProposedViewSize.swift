//
//  ProposedViewSize.swift
//  PyNucleantUI
//
//  Adapted from swift-cross-ui's ProposedViewSize
//  (https://github.com/moreSwift/swift-cross-ui,
//  Sources/SwiftCrossUI/Layout/ProposedViewSize.swift), itself modelled on
//  SwiftUI. Ported to this codebase's `Double` / `SIMD2<Double>` sizes and
//  `Orientation` axis instead of swift-cross-ui's `ViewSize` / `Axis`.
//

// Apple-only module — see the note in Sources/PyNucleantUI/FrameProtocol.swift.
#if canImport(simd)
import simd
#endif

/// A size a container proposes to a child during layout. Either dimension
/// may be `nil` — *unspecified* — meaning the container isn't constraining
/// that axis, so the child picks its own extent there. That's the proposal
/// analogue of a `flexible` frame axis: unspecified ⇄ flexible.
public struct ProposedViewSize: Hashable, Sendable {

    /// Both dimensions `0` — the smallest a child may be asked to be.
    public static let zero = ProposedViewSize(0, 0)

    /// Both dimensions `+∞` — "as large as you like".
    public static let infinity = ProposedViewSize(.infinity, .infinity)

    /// Both dimensions unspecified — the child sizes itself on both axes.
    public static let unspecified = ProposedViewSize(nil, nil)

    public var width: Double?
    public var height: Double?

    public init(_ width: Double?, _ height: Double?) {
        self.width = width
        self.height = height
    }

    /// A fully-specified proposal from a concrete size.
    public init(_ size: SIMD2<Double>) {
        self.width = size.x
        self.height = size.y
    }

    /// The proposal as a concrete size, or `nil` if either axis is
    /// unspecified.
    public var concrete: SIMD2<Double>? {
        guard let width, let height else { return nil }
        return .init(width, height)
    }

    /// Fill any unspecified axis from `size`, yielding a concrete size —
    /// swift-cross-ui's `replacingUnspecifiedDimensions(by:)`.
    public func replacingUnspecifiedDimensions(
        by size: SIMD2<Double> = .zero
    ) -> SIMD2<Double> {
        .init(width ?? size.x, height ?? size.y)
    }

    /// The proposed extent along a stack axis — mirrors
    /// `SIMD2.subscript(component:)`, so the same maths can read a proposal
    /// and a size the same way.
    public subscript(component orientation: Orientation) -> Double? {
        get {
            switch orientation {
            case .horizontal: width
            case .vertical: height
            }
        }
        set {
            switch orientation {
            case .horizontal: width = newValue
            case .vertical: height = newValue
            }
        }
    }
}
