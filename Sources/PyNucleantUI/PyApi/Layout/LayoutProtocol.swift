//
//  LayoutProtocol.swift
//  PyNucleantUI
//
import SulphurUI

public protocol LayoutProtocol {
    associatedtype Frame: FrameProtocol
    associatedtype Widget: WidgetProtocol
    
    var subFrames: [Frame] { get }
    
    func computeFrames(widget: Widget)
}


public protocol VerticalLayout: LayoutProtocol {
    
}

extension VerticalLayout {
    public func computeFrames(widget: Widget) {
        
    }
}

public protocol HorizontalLayout: LayoutProtocol {
    
}
