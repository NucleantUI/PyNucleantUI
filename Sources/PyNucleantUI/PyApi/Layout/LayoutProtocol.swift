//
//  LayoutProtocol.swift
//  PyNucleantUI
//
//import SulphurUI
@preconcurrency import PySwiftKit
import PySerializing
import PySwiftWrapper
import simd

/// A layout a widget owns — `widget.layout = GridLayout(...)`. It runs on
/// frames alone: the widget's own frame is the container, each child hands in
/// its frame, and a `nil` (or flexible) child takes a share of the leftover
/// space. Concrete over `NucleantFrame` — the frame type every widget uses —
/// so a widget can hold `any LayoutProtocol` without threading a generic
/// widget/frame parameter through the layout type.
public protocol LayoutProtocol {
    /// One frame per child, in child order. Flexible children (`nil`, or a
    /// frame flagging `flexibleWidth`/`flexibleHeight`) split whatever space
    /// the fixed children and spacing leave over.
    func computeFrames(
        container: NucleantFrame,
        children: [NucleantFrame?]
    ) -> [SIMD4<Double>]
}

extension LayoutProtocol {
    /// In-place pass for the widget side: fixed children get their existing
    /// frame mutated (in-place mutation is what an observing canvas reacts
    /// to), frameless children get a fresh `NucleantFrame` the widget can
    /// hand them. Result is in child order.
    ///
    /// Named apart from `computeFrames` on purpose — sharing the name makes
    /// calls ambiguous against the `StackLayoutProtocol`/`GridLayoutProtocol`
    /// overloads.
    public func applyFrames(
        container: NucleantFrame,
        children: [NucleantFrame?]
    ) -> [NucleantFrame] {
        let computed = computeFrames(container: container, children: children)
        return zip(children, computed).map { child, frame in
            guard let child else {
                return NucleantFrame(pos: frame.pos, size: frame.size)
            }
            child.pos = frame.pos
            child.size = frame.size
            return child
        }
    }
}

/// A layout that stacks its children along one axis.
public protocol StackLayoutProtocol: LayoutProtocol {
    var orientation: Orientation { get }
    /// Gap between neighbouring children along the stack axis.
    var spacing: Double { get }
    /// Cross-axis placement of children that keep their own (smaller) size, as
    /// a raw value (0 start / 1 center / 2 end). Each concrete stack exposes a
    /// typed `alignment` (`HorizontalAlignment` / `VerticalAlignment`) and maps
    /// it here, so the shared maths stay axis-agnostic.
    var crossAlignment: Int { get }
}

extension StackLayoutProtocol {
    public func computeFrames(
        container: NucleantFrame,
        children: [NucleantFrame?]
    ) -> [SIMD4<Double>] {
        LayoutSystem.computeStackFrames(
            container: container,
            children: children,
            orientation: orientation,
            spacing: spacing,
            crossAlignment: crossAlignment
        )
    }
}

/// The Python-facing layout contract: a `LayoutProtocol` that is also a
/// `@PyClass` instance, so a widget can hold `any PyLayoutProtocol`, hand its
/// Python object back through `widget.layout`, and still run the frame pass.
/// Mirrors `PyCanvasBase` — the same round-trip a canvas slot does.
public protocol PyLayoutProtocol: LayoutProtocol, PySerializable, PyClassProtocol, AnyObject {}

/// Ready-to-attach vertical stack — `widget.layout = VerticalLayout(spacing=8)`.
/// Children align across the horizontal axis; `alignment` crosses from Python
/// as a `HorizontalAlignment` raw value (0 leading / 1 center / 2 trailing).
@PyClass(self_ref: true)
public final class VerticalLayout: StackLayoutProtocol, PyLayoutProtocol {
    private let __self__: PyPointer

    public var orientation: Orientation { .vertical }

    @PyProperty public var spacing: Double
    public var alignment: HorizontalAlignment
    public var crossAlignment: Int { alignment.rawValue }

    @PyInit
    init(__self__: PyPointer, spacing: Double = 0, alignment: Int = 0) {
        self.__self__ = __self__
        self.spacing = spacing
        self.alignment = HorizontalAlignment(rawValue: alignment) ?? .leading
    }

    public func pyPointer() -> PyPointer { __self__.newRef }
}

/// Ready-to-attach horizontal stack — `widget.layout = HorizontalLayout(spacing=8)`.
/// Children align across the vertical axis; `alignment` crosses from Python as
/// a `VerticalAlignment` raw value (0 top / 1 center / 2 bottom).
@PyClass(self_ref: true)
public final class HorizontalLayout: StackLayoutProtocol, PyLayoutProtocol {
    private let __self__: PyPointer

    public var orientation: Orientation { .horizontal }

    @PyProperty public var spacing: Double
    public var alignment: VerticalAlignment
    public var crossAlignment: Int { alignment.rawValue }

    @PyInit
    init(__self__: PyPointer, spacing: Double = 0, alignment: Int = 0) {
        self.__self__ = __self__
        self.spacing = spacing
        self.alignment = VerticalAlignment(rawValue: alignment) ?? .top
    }

    public func pyPointer() -> PyPointer { __self__.newRef }
}

/// A grid: children flow across cross-axis tracks (`GridItem`s) and wrap into
/// new lines along the growth axis. `VerticalGrid` (tracks are columns, grows
/// down) and `HorizontalGrid` (tracks are rows, grows right) conform.
public protocol GridLayout: LayoutProtocol {
    /// The cross-axis tracks — columns for a vertical grid, rows for a
    /// horizontal one.
    var tracks: [GridItem] { get }
    /// Growth axis: `.vertical` wraps into new rows, `.horizontal` into new
    /// columns.
    var orientation: Orientation { get }
    /// Gap between wrapped lines (rows for a vertical grid, columns for a
    /// horizontal one).
    var lineSpacing: Double { get }
    /// In-cell placement of a child smaller than its cell, as a raw value
    /// (0 start / 1 center / 2 end).
    var crossAlignment: Int { get }
}

extension GridLayout {
    public func computeFrames(
        container: NucleantFrame,
        children: [NucleantFrame?]
    ) -> [SIMD4<Double>] {
        LayoutSystem.computeGridFrames(
            container: container,
            children: children,
            tracks: tracks,
            orientation: orientation,
            lineSpacing: lineSpacing,
            alignment: crossAlignment
        )
    }
}

/// Vertical grid (SwiftUI's `LazyVGrid`): grows downward; `columns` are the
/// cross-axis tracks. `widget.layout = VerticalGrid(columns=[GridItem(...)])`.
@PyClass(self_ref: true)
public final class VerticalGrid: GridLayout, PyLayoutProtocol {
    private let __self__: PyPointer

    public var columns: [GridItem]
    @PyProperty public var spacing: Double
    public var alignment: HorizontalAlignment

    public var tracks: [GridItem] { columns }
    public var orientation: Orientation { .vertical }
    public var lineSpacing: Double { spacing }
    public var crossAlignment: Int { alignment.rawValue }

    @PyInit
    init(
        __self__: PyPointer,
        columns: [GridItem],
        spacing: Double = 0,
        alignment: Int = 0
    ) {
        self.__self__ = __self__
        self.columns = columns
        self.spacing = spacing
        self.alignment = HorizontalAlignment(rawValue: alignment) ?? .leading
    }

    public func pyPointer() -> PyPointer { __self__.newRef }
}

/// Horizontal grid (SwiftUI's `LazyHGrid`): grows rightward; `rows` are the
/// cross-axis tracks. `widget.layout = HorizontalGrid(rows=[GridItem(...)])`.
@PyClass(self_ref: true)
public final class HorizontalGrid: GridLayout, PyLayoutProtocol {
    private let __self__: PyPointer

    public var rows: [GridItem]
    @PyProperty public var spacing: Double
    public var alignment: VerticalAlignment

    public var tracks: [GridItem] { rows }
    public var orientation: Orientation { .horizontal }
    public var lineSpacing: Double { spacing }
    public var crossAlignment: Int { alignment.rawValue }

    @PyInit
    init(
        __self__: PyPointer,
        rows: [GridItem],
        spacing: Double = 0,
        alignment: Int = 0
    ) {
        self.__self__ = __self__
        self.rows = rows
        self.spacing = spacing
        self.alignment = VerticalAlignment(rawValue: alignment) ?? .top
    }

    public func pyPointer() -> PyPointer { __self__.newRef }
}

/// One track of a grid — a column for a vertical grid, a row for a horizontal
/// one — modelled on SwiftUI's `GridItem`. A `@PyClass` (so pyswiftkit can
/// wrap it and a grid can take a list of them). pyswiftkit has no enum
/// support, so the sizing mode crosses as `kind` (a `GridSize` raw value)
/// with `minimum` / `maximum` bounds; for `.fixed`, `minimum` is the exact
/// extent. Defaults mirror SwiftUI's `.flexible()`.
@PyClass
public final class GridItem: PyDeserialize {
    /// Sizing mode as a `GridSize` raw value (0 fixed / 1 flexible / 2 adaptive).
    @PyProperty public var kind: Int
    /// Lower bound, or the exact extent when `kind == fixed`.
    @PyProperty public var minimum: Double
    /// Upper bound (`inf` = unbounded); ignored when `kind == fixed`.
    @PyProperty public var maximum: Double
    /// Gap after this track; negative means "use the grid's default".
    @PyProperty public var spacing: Double

    /// The sizing mode as a typed value for Swift consumers.
    public var sizing: GridSize { GridSize(rawValue: kind) ?? .flexible }

    @PyInit
    init(
        kind: Int = 1,
        minimum: Double = 10,
        maximum: Double = .infinity,
        spacing: Double = -1
    ) {
        self.kind = kind
        self.minimum = minimum
        self.maximum = maximum
        self.spacing = spacing
    }
}
