//
//  CanvasBuilder.swift
//  PyNucleantUI
//
import KivyWidgetRegistry
import KvParser
//import SulphurUI
import PySwiftAST
import PySwiftKit

public final class ThorInstruction {
    
    var statements: [Statement] = []
    
    static func rectangle(props: [KvProperty]) -> ThorInstruction {
        let out = ThorInstruction()
        var py_args = [Expression]()
        var py_keys = [Keyword]()
        for prop in props {
            switch prop.name {
            case "pos":
                py_keys.append(
                    .init(arg: "pos", value: .list(.init(elts: [.constant(.init(value: .int(0))),.constant(.init(value: .int(0)))])))
                )
            case "size":
                py_keys.append(
                    .init(arg: "size", value: .list(.init(elts: [.constant(.init(value: .int(0))),.constant(.init(value: .int(0)))])))
                )
            default: continue
            }
        }
        return out
    }
}


public final class ThorInstructionBuilder {
    
    var currentColor: CanvasColor = .white
    
    var statements: [Statement] = []
    
    init(rules: [KvRule]) {
        
        for rule in rules {
            if let before = rule.canvasBefore {
                for instruction in before.instructions {
                    switch KnownCanvasInstruction(rawValue: instruction.instructionType) {
                    case .color:
                        currentColor = if let first = instruction.properties.first {
                            .fromString(first.value)
                        } else { .white }
                    case .rectangle:
                        statements.append(contentsOf: ThorInstruction.rectangle(props: instruction.properties).statements)
                    default:
                        fatalError()
                    }
                }
            }
            
            if let canvas = rule.canvas {
                
            }
            
            if let after = rule.canvasAfter {
                
            }
        }
    }
    
    static func rule2instruction(_ rule: KvRule) -> ThorInstruction {
        
        
        
        fatalError()
    }
}

extension UInt8 {
    var pyConstant: PySwiftAST.Constant {
        .init(value: .int(.init(self)))
    }
    var pyExpr: PySwiftAST.Expression {
        .constant(pyConstant)
    }
}

extension String {
    var asDouble: Double {
        .init(self)!
    }
}

extension Substring {
    var asDouble: Double {
        .init(self)!
    }
}

extension ThorInstructionBuilder {
    public final class CanvasColor {
        var r: Double
        var g: Double
        var b: Double
        var a: Double
        
        public init(r: Double, g: Double, b: Double, a: Double = 1) {
            self.r = r
            self.g = g
            self.b = b
            self.a = a
        }
        
        public init(r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255) {
            self.r = Double(r) / 255
            self.g = Double(g) / 255
            self.b = Double(b) / 255
            self.a = Double(a) / 255
        }
        
        static func fromArray(_ value: [Double]) -> CanvasColor {
            switch value.count {
            case 1:
                return .init(r: value[0], g: value[0], b: value[0])
            case 2:
                return .init(r: value[0], g: value[0], b: value[0], a: value[1])
            case 3:
                return .init(r: value[0], g: value[1], b: value[2])
            case 4:
                return .init(r: value[0], g: value[1], b: value[2], a: value[3])
            default: fatalError("\(value) is not valid input")
            }
        }
        
        static func fromString(_ value: String) -> CanvasColor {
            let values: [Double] = value.split(separator: ",").map(\.asDouble)
            
            return .fromArray(values)
        }
        
        var thorRed: UInt8 { .init(r * 255) }
        var thorGreen: UInt8 { .init(g * 255) }
        var thorBlue: UInt8 { .init(b * 255) }
        var thorAlpha: UInt8 { .init(a * 255) }
        
        var thorTupleRGB: PySwiftAST.Tuple {
            .init(elts: [
                thorRed.pyExpr,
                thorGreen.pyExpr,
                thorBlue.pyExpr
            ])
        }
        
        var thorTupleRGBA: PySwiftAST.Tuple {
            .init(elts: [
                thorRed.pyExpr,
                thorGreen.pyExpr,
                thorBlue.pyExpr,
                thorAlpha.pyExpr
            ])
        }
    }
    
    
}


extension ThorInstructionBuilder.CanvasColor {
    static var white: Self { .init(r: 1.0, g: 1.0, b: 1.0, a: 1.0) }
}
