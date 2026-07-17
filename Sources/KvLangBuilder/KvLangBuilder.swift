//
//  KvLangBuilder.swift
//  PyNucleantUI
//
import KivyWidgetRegistry
import KvParser
import SulphurUI
import PySwiftAST
import PySwiftKit

public final class KvLangBuilder<Widget: WidgetProtocol> {
    
    
    
    private var module: KvModule
    
    private var py_module: [Statement] = []
    
    public init(kv: String) throws {
        self.module = try KvParser(tokens: try KvTokenizer(source: kv).tokenize()).parse()
        
        
    }
    
    
    private func process() {
        
        for rule in module.rules {
            rule.selector.primaryName
        }
        
        py_module.append(contentsOf: module.templates.map { template in
            let cls_def = ClassDef(name: template.name)
            
            
            return .classDef(cls_def)
        })
        
    }
}


class WidgetClassBuilder {
    
    init(rule: KvRule) {
        
    }
    
    var py_class: PySwiftAST.ClassDef {
        
        
        return .init(
            name: "test",
            bases: [.name("NucleantWidgetBase")],
            keywords: [],
            body: [],
            decoratorList: [],
            typeParams: [],
            lineno: 0,
            colOffset: 0,
            endLineno: 0,
            endColOffset: 0
        )
    }
    
}
