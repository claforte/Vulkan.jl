while true
    initialize(_PhysicalDeviceFeatures2, _PhysicalDeviceVulkan12Features, _PhysicalDeviceVulkanMemoryModelFeatures)
    f1 = initialize(PhysicalDeviceFeatures2, PhysicalDeviceVulkan12Features, PhysicalDeviceVulkanMemoryModelFeatures)

    chain_args = [PhysicalDeviceFeatures2(PhysicalDeviceFeatures()), PhysicalDeviceVulkan12Features(), PhysicalDeviceVulkanMemoryModelFeatures(false, false, false)]
    chained = chain(chain_args...)
    unchain(chained)

    f2 = _PhysicalDeviceFeatures2(f1)
    from_vk(PhysicalDeviceFeatures2, f2.vks, PhysicalDeviceVulkan12Features, PhysicalDeviceVulkanMemoryModelFeatures)
    f3 = Base.unsafe_convert(VkCore.VkPhysicalDeviceFeatures2, f2)
    f4 = PhysicalDeviceFeatures2(f3, PhysicalDeviceVulkan12Features, PhysicalDeviceVulkanMemoryModelFeatures)
    break
end
