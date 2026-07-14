//
//  VulkanRenderEngine+Snapshot.swift
//  SulphurXcodeDemo
//
//  Debug-only: dump a node's VkImage to a PNG on disk via a GPU->CPU
//  staging copy, so its content can be inspected without a live display —
//  captures the shared texture ThorVG renders into directly, before the
//  composite/present stage, so it isolates whether ThorVG's draw actually
//  lands in shared memory independent of the rest of the pipeline.
//
//  Reads via an intermediate hop: node.image (imported, MoltenVK doesn't
//  own its layout) -> a normal, freshly-allocated VkImage (MoltenVK fully
//  owns and understands its layout) -> staging buffer. If content shows up
//  correctly through this path but not a direct node.image -> buffer copy,
//  that isolates the bug to vkCmdCopyImageToBuffer's handling of imported
//  images specifically, not the underlying memory sharing itself.
//
import AppKit
import VulkanCore
import CVulkan

extension VulkanRenderEngine {
    @discardableResult
    func captureSnapshot(of node: ThorShaderNode, to path: String) -> Bool {
        let width  = Int(node.width)
        let height = Int(node.height)
        let bufferSize = VkDeviceSize(width * height * 4)

        // Intermediate, non-imported image MoltenVK fully owns.
        var intermediate: VkImage?
        var imageInfo = VkImageCreateInfo()
        imageInfo.sType         = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO
        imageInfo.imageType     = VK_IMAGE_TYPE_2D
        imageInfo.format        = VK_FORMAT_B8G8R8A8_UNORM
        imageInfo.extent        = VkExtent3D(width: UInt32(width), height: UInt32(height), depth: 1)
        imageInfo.mipLevels     = 1
        imageInfo.arrayLayers   = 1
        imageInfo.samples       = VK_SAMPLE_COUNT_1_BIT
        imageInfo.tiling        = VK_IMAGE_TILING_OPTIMAL
        imageInfo.usage         = VkImageUsageFlags(VK_IMAGE_USAGE_TRANSFER_DST_BIT.rawValue) | VkImageUsageFlags(VK_IMAGE_USAGE_TRANSFER_SRC_BIT.rawValue)
        imageInfo.sharingMode   = VK_SHARING_MODE_EXCLUSIVE
        imageInfo.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED
        guard vkCreateImage(device, &imageInfo, nil, &intermediate) == VK_SUCCESS, let intermediate else {
            print("captureSnapshot: intermediate image create failed")
            return false
        }
        defer { vkDestroyImage(device, intermediate, nil) }

        var intermRequirements = VkMemoryRequirements()
        vkGetImageMemoryRequirements(device, intermediate, &intermRequirements)
        var intermMemory: VkDeviceMemory?
        var intermAllocInfo = VkMemoryAllocateInfo()
        intermAllocInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO
        intermAllocInfo.allocationSize = intermRequirements.size
        intermAllocInfo.memoryTypeIndex = findMemoryType(
            typeFilter: intermRequirements.memoryTypeBits,
            properties: VkMemoryPropertyFlags(VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT.rawValue)
        )
        guard vkAllocateMemory(device, &intermAllocInfo, nil, &intermMemory) == VK_SUCCESS, let intermMemory else {
            print("captureSnapshot: intermediate image memory alloc failed")
            return false
        }
        defer { vkFreeMemory(device, intermMemory, nil) }
        vkBindImageMemory(device, intermediate, intermMemory, 0)

        var stagingBuffer: VkBuffer?
        var bufferInfo = VkBufferCreateInfo()
        bufferInfo.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO
        bufferInfo.size  = bufferSize
        bufferInfo.usage = VkBufferUsageFlags(VK_BUFFER_USAGE_TRANSFER_DST_BIT.rawValue)
        bufferInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE
        guard vkCreateBuffer(device, &bufferInfo, nil, &stagingBuffer) == VK_SUCCESS, let stagingBuffer else {
            print("captureSnapshot: vkCreateBuffer failed")
            return false
        }
        defer { vkDestroyBuffer(device, stagingBuffer, nil) }

        var requirements = VkMemoryRequirements()
        vkGetBufferMemoryRequirements(device, stagingBuffer, &requirements)
        var memory: VkDeviceMemory?
        var allocInfo = VkMemoryAllocateInfo()
        allocInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO
        allocInfo.allocationSize = requirements.size
        allocInfo.memoryTypeIndex = findMemoryType(
            typeFilter: requirements.memoryTypeBits,
            properties: VkMemoryPropertyFlags(VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT.rawValue)
                | VkMemoryPropertyFlags(VK_MEMORY_PROPERTY_HOST_COHERENT_BIT.rawValue)
        )
        guard vkAllocateMemory(device, &allocInfo, nil, &memory) == VK_SUCCESS, let memory else {
            print("captureSnapshot: vkAllocateMemory failed")
            return false
        }
        defer { vkFreeMemory(device, memory, nil) }
        vkBindBufferMemory(device, stagingBuffer, memory, 0)

        let priorLayout = node.currentLayout
        oneTimeSubmit { cmd in
            var srcBarrier = VkImageMemoryBarrier()
            srcBarrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER
            srcBarrier.oldLayout = priorLayout
            srcBarrier.newLayout = VK_IMAGE_LAYOUT_GENERAL
            srcBarrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED
            srcBarrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED
            srcBarrier.image = node.image
            srcBarrier.subresourceRange = VkImageSubresourceRange(
                aspectMask: VkImageAspectFlags(VK_IMAGE_ASPECT_COLOR_BIT.rawValue),
                baseMipLevel: 0, levelCount: 1, baseArrayLayer: 0, layerCount: 1
            )
            srcBarrier.srcAccessMask = VkAccessFlags(VK_ACCESS_MEMORY_WRITE_BIT.rawValue) | VkAccessFlags(VK_ACCESS_MEMORY_READ_BIT.rawValue)
            srcBarrier.dstAccessMask = VkAccessFlags(VK_ACCESS_TRANSFER_READ_BIT.rawValue)

            var dstBarrier = VkImageMemoryBarrier()
            dstBarrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER
            dstBarrier.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED
            dstBarrier.newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
            dstBarrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED
            dstBarrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED
            dstBarrier.image = intermediate
            dstBarrier.subresourceRange = srcBarrier.subresourceRange
            dstBarrier.srcAccessMask = 0
            dstBarrier.dstAccessMask = VkAccessFlags(VK_ACCESS_TRANSFER_WRITE_BIT.rawValue)

            withUnsafeMutablePointer(to: &srcBarrier) { srcPtr in
                withUnsafeMutablePointer(to: &dstBarrier) { dstPtr in
                    let barriers = [srcPtr.pointee, dstPtr.pointee]
                    barriers.withUnsafeBufferPointer { buf in
                        vkCmdPipelineBarrier(
                            cmd,
                            VkPipelineStageFlags(VK_PIPELINE_STAGE_ALL_COMMANDS_BIT.rawValue),
                            VkPipelineStageFlags(VK_PIPELINE_STAGE_TRANSFER_BIT.rawValue),
                            0, 0, nil, 0, nil, UInt32(buf.count), buf.baseAddress
                        )
                    }
                }
            }

            var copyRegion = VkImageCopy()
            copyRegion.srcSubresource = VkImageSubresourceLayers(
                aspectMask: VkImageAspectFlags(VK_IMAGE_ASPECT_COLOR_BIT.rawValue),
                mipLevel: 0, baseArrayLayer: 0, layerCount: 1
            )
            copyRegion.dstSubresource = copyRegion.srcSubresource
            copyRegion.extent = VkExtent3D(width: UInt32(width), height: UInt32(height), depth: 1)
            vkCmdCopyImage(
                cmd,
                node.image, VK_IMAGE_LAYOUT_GENERAL,
                intermediate, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                1, &copyRegion
            )

            var toTransferSrc = VkImageMemoryBarrier()
            toTransferSrc.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER
            toTransferSrc.oldLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
            toTransferSrc.newLayout = VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL
            toTransferSrc.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED
            toTransferSrc.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED
            toTransferSrc.image = intermediate
            toTransferSrc.subresourceRange = srcBarrier.subresourceRange
            toTransferSrc.srcAccessMask = VkAccessFlags(VK_ACCESS_TRANSFER_WRITE_BIT.rawValue)
            toTransferSrc.dstAccessMask = VkAccessFlags(VK_ACCESS_TRANSFER_READ_BIT.rawValue)
            vkCmdPipelineBarrier(
                cmd,
                VkPipelineStageFlags(VK_PIPELINE_STAGE_TRANSFER_BIT.rawValue),
                VkPipelineStageFlags(VK_PIPELINE_STAGE_TRANSFER_BIT.rawValue),
                0, 0, nil, 0, nil, 1, &toTransferSrc
            )

            var region = VkBufferImageCopy()
            region.imageSubresource = VkImageSubresourceLayers(
                aspectMask: VkImageAspectFlags(VK_IMAGE_ASPECT_COLOR_BIT.rawValue),
                mipLevel: 0, baseArrayLayer: 0, layerCount: 1
            )
            region.imageExtent = VkExtent3D(width: UInt32(width), height: UInt32(height), depth: 1)
            vkCmdCopyImageToBuffer(cmd, intermediate, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, stagingBuffer, 1, &region)

            var backToPrior = srcBarrier
            backToPrior.oldLayout = VK_IMAGE_LAYOUT_GENERAL
            backToPrior.newLayout = priorLayout
            backToPrior.srcAccessMask = VkAccessFlags(VK_ACCESS_TRANSFER_READ_BIT.rawValue)
            backToPrior.dstAccessMask = VkAccessFlags(VK_ACCESS_MEMORY_READ_BIT.rawValue) | VkAccessFlags(VK_ACCESS_MEMORY_WRITE_BIT.rawValue)
            vkCmdPipelineBarrier(
                cmd,
                VkPipelineStageFlags(VK_PIPELINE_STAGE_TRANSFER_BIT.rawValue),
                VkPipelineStageFlags(VK_PIPELINE_STAGE_ALL_COMMANDS_BIT.rawValue),
                0, 0, nil, 0, nil, 1, &backToPrior
            )
        }

        var mapped: UnsafeMutableRawPointer?
        vkMapMemory(device, memory, 0, bufferSize, 0, &mapped)
        guard let mapped else {
            print("captureSnapshot: vkMapMemory failed")
            return false
        }
        defer { vkUnmapMemory(device, memory) }

        // BGRA8 -> RGBA8 swizzle for NSBitmapImageRep.
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let src = mapped.assumingMemoryBound(to: UInt8.self)
        for i in 0..<(width * height) {
            let s = i * 4
            rgba[s + 0] = src[s + 2]
            rgba[s + 1] = src[s + 1]
            rgba[s + 2] = src[s + 0]
            rgba[s + 3] = src[s + 3]
        }

        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: width,
                pixelsHigh: height,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: width * 4,
                bitsPerPixel: 32
            ),
            let bitmapData = rep.bitmapData
        else {
            print("captureSnapshot: NSBitmapImageRep alloc failed")
            return false
        }
        rgba.withUnsafeBufferPointer { buf in
            bitmapData.update(from: buf.baseAddress!, count: buf.count)
        }

        guard let png = rep.representation(using: .png, properties: [:]) else {
            print("captureSnapshot: PNG encode failed")
            return false
        }
        do {
            try png.write(to: URL(fileURLWithPath: path))
            print("captureSnapshot: wrote \(path)")
            return true
        } catch {
            print("captureSnapshot: write failed \(error)")
            return false
        }
    }
}
