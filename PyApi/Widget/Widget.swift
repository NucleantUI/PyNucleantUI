//
//  Widget.swift
//  PyNucleantUI
//

@preconcurrency import PySwiftKit
@preconcurrency import PySerializing
@preconcurrency import PySwiftWrapper
import PNU_Core


@PyModule
struct widget: PyModuleProtocol, @unchecked Sendable {
    
    static let py_classes: [any (PyClassProtocol & AnyObject).Type] = [
        PyWidgetBase.self
    ]
    
    
}
