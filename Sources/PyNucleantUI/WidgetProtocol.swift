//
//  WidgetProtocol.swift
//  ThorUI
//


public protocol WidgetProtocol {
    associatedtype Frame: FrameProtocol
    var frame: Frame? { get }
    
    associatedtype Child: WidgetProtocol
    
    var children: [Child] { get set }
    func add_widget<W: WidgetProtocol>(widget: W)
    //func add_widgets<W>(widget: W) where W: WidgetProtocol
    func remove_widget<W: WidgetProtocol>(widget: W)
    
    func clear_widgets()
}
