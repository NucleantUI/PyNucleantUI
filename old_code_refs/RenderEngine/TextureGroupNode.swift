//
//  TextureGroupNode.swift
//  PyNucleantUI
//
import VulkanCore
import CVulkan

public enum TextureGroupNode {
    case container(TextureContainer)
}


extension TextureGroupNode {
    
    public class TextureContainer {
        var image: VkImage
        var blend: BlendMode
        
        public init(image: VkImage, blend: BlendMode = .mix) {
            self.image = image
            self.blend = blend
        }
    }
    
    public enum BlendMode {
        case multiply
        case mix
        case addition
        case substract
    }
    
}
