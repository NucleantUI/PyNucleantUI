//
//  Factory.swift
//  PyNucleantUI
//
import KivyWidgetRegistry
import KvParser
import PySwiftKit

@MainActor
public final class KvLangFactory {
    
    static let shared = KvLangFactory()
    
    var registered: [String: PyPointer] = [:]
    
    init() {
        
    }
    
    
    static func register(name: String, cls: PyPointer) {
        shared.registered[name] = cls
    }
    
    static func unregister(name: String) {
        shared.registered.removeValue(forKey: name)
    }
}
