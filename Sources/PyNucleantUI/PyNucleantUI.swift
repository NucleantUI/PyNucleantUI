// The Swift Programming Language
// https://docs.swift.org/swift-book
@preconcurrency import PySwiftKit
import PySerializing
import PySwiftWrapper



extension Int {
    var asDouble: Double { .init(self) }
    
    func scaled(_ scale: Double) -> Double {
        self.asDouble * scale
    }
}

extension Double {
    var asInt: Int { .init(self) }
    
    func scaled(_ scale: Double) -> Double {
        self * scale
    }
}
