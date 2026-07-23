//
//  WindowMenu.swift
//  PyNucleantUI
//
import PySwiftKit
import PySerializing
import PySwiftWrapper



@PyClass
class WindowMenuCommand {
    
    typealias ActionFunction = ((String?)->Void)
    
    let name: String
    let menu_action: ActionFunction
    
    @PyInit
    init(name: String, action: PyPointer) {
        self.name = name
        self.menu_action = #PyCallable_V<String?>(action)
    }
    
}

#if os(macOS)
import AppKit
extension WindowMenuCommand {
    final class WindowMenuItem: NSMenuItem {
        
        weak var owner: WindowMenuCommand?
        
        init(title string: String, keyEquivalent charCode: String, owner: WindowMenuCommand) {
            self.owner = owner
            super.init(title: string, action: #selector(Self.cmdAction), keyEquivalent: charCode)
        }
        
        required init(coder: NSCoder) {
            fatalError()
        }
        
        @objc func cmdAction(_ sender: Any?) {
            owner?.menu_action(self.keyEquivalent)
        }
    }
}

#endif
