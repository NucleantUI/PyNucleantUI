//
//  WidgetProtocol.swift
//  ThorUI
//
import PySerializing
import PySwiftKit

public protocol WidgetProtocol: AnyObject {
    associatedtype Frame: FrameProtocol
    var frame: Frame? { get }
    
    associatedtype Child: WidgetProtocol
    
    var children: [Child] { get set }
    func add_widget<W: WidgetProtocol>(widget: W)
    //func add_widgets<W>(widget: W) where W: WidgetProtocol
    func remove_widget<W: WidgetProtocol>(widget: W)
    
    func clear_widgets()
}

public protocol PyWidgetProtocol: WidgetProtocol, PySerializable {
    var __self__: PyPointer { get }
}

extension PyWidgetProtocol {
    public func pyPointer() -> PyPointer {
        __self__.newRef
    }
}
