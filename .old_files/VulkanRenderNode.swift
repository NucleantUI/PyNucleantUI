//
//  VulkanRenderNode.swift
//  SulphurXcodeDemo
//
import SulphurVulkan
import VulkanCore
import CVulkan


public protocol VulkanRenderNode: AnyObject {
    var image:                VkImage           { get }
    var imageView:            VkImageView       { get }
    var computePipeline:      VkPipeline?       { get }
    var computeLayout:        VkPipelineLayout? { get }
    var computeDescriptorSet: VkDescriptorSet?  { get }
    var dirty:                Bool              { get set }
}
