//
//  RenderNode.swift
//  PyNucleantUI
//


import QuartzCore
import SulphurVulkan
import VulkanCore
import CVulkan
import SulphurCore
import SulphurShader
import CWgpu
#if canImport(SulphurApplication)
import SulphurApplication
#endif


// MARK: - Node type

public struct RenderNode {
    let id: Int
    
    let context: Context
    
    init(id: Int, context: Context) {
        self.id = id
        self.context = context
    }
}

