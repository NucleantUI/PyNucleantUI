//
//  Layout.swift
//  SulphurXcodeDemo
//


@preconcurrency import PySwiftKit
import PySerializing
import PySwiftWrapper

//import SulphurUI
//import NucleantVulkan





@PyModule
fileprivate struct _layout: PyModuleProtocol {
    
    static let py_classes: [any (PyClassProtocol & AnyObject).Type] = [
        NucleantFrame.self,
        VerticalLayout.self,
        HorizontalLayout.self,
        VerticalGrid.self,
        HorizontalGrid.self,
        GridItem.self
    ]
    
    
    static let modules: [any PyModuleProtocol.Type] = [
        
    ]
    
    
    
} // SulphurUI
