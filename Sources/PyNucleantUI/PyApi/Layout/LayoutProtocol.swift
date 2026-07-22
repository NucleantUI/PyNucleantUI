//
//  LayoutProtocol.swift
//  PyNucleantUI
//
//import SulphurUI
import simd

// The widget stays out of the layout maths for now — it owns *when*
// (calling computeFrames when its pos or size changes), the layout owns
// *where*. The pass runs on frames alone: the container's frame plus each
// child's optional own frame, nil meaning "no frame of its own — take a
// share of the remaining space".
public protocol LayoutProtocol {
    /// The widget type the layout attaches to. The frame type rides in on
    /// the widget — `WidgetProtocol` fixes its own `associatedtype Frame`,
    /// so the layout never picks a frame type of its own.
    associatedtype Widget: WidgetProtocol
    typealias Frame = Widget.Frame
    // parked widget-driven pass, until the widget side gets wired up:
    //var subFrames: [Frame] { get set }
    //func computeFrames(widget: Widget)

    /// One frame per child, in child order. `nil` children are flexible:
    /// they split whatever length the fixed children and spacing leave
    /// over, and fill the cross axis.
    func computeFrames(
        container: Frame,
        children: [Frame?]
    ) -> [SIMD4<Double>]
}

extension LayoutProtocol where Frame == NucleantFrame {
    /// In-place pass for the widget side: fixed children get their existing
    /// frame mutated (in-place mutation is what an observing canvas reacts
    /// to), frameless children get a fresh `SulphurFrame` the widget can
    /// hand them. Result is in child order.
    ///
    /// Named apart from `computeFrames` on purpose — sharing the name makes
    /// calls ambiguous against the `StackLayoutProtocol` overload.
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
    /// Cross-axis placement of children that keep their own (smaller) size.
    var alignment: StackAlignment { get }
}

extension StackLayoutProtocol {
    public func computeFrames(
        container: Frame,
        children: [Frame?]
    ) -> [SIMD4<Double>] {
        LayoutSystem.computeStackFrames(
            container: container,
            children: children,
            orientation: orientation,
            spacing: spacing,
            alignment: alignment
        )
    }
}

public protocol VerticalLayout: StackLayoutProtocol {

}

extension VerticalLayout {
    public var orientation: Orientation { .vertical }
    // parked with the frame-centric reshape above:
    //public func computeFrames(widget: Widget) {
    //
    //}
}

public protocol HorizontalLayout: StackLayoutProtocol {

}

extension HorizontalLayout {
    public var orientation: Orientation { .horizontal }
}

/// Ready-to-attach concrete stacks, generic over the widget they attach
/// to — `VStackLayout<SulphurWidgetBase>`; the frame type follows.
public struct VStackLayout<Widget: WidgetProtocol>: VerticalLayout {
    public var spacing: Double
    public var alignment: StackAlignment

    public init(spacing: Double = 0, alignment: StackAlignment = .leading) {
        self.spacing = spacing
        self.alignment = alignment
    }
}

public struct HStackLayout<Widget: WidgetProtocol>: HorizontalLayout {
    public var spacing: Double
    public var alignment: StackAlignment

    public init(spacing: Double = 0, alignment: StackAlignment = .leading) {
        self.spacing = spacing
        self.alignment = alignment
    }
}
