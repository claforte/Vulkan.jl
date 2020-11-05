"""
A Vulkan application represents any program that uses the Vulkan API. Application goals and setups may vary greatly, but they all require many structures to function. Some may do offline rendering (without presenting the result to a window), or use Vulkan Compute and render directly to a display, but both uses share similarities in that they require an Instance and one (or several) devices.
"""
abstract type VulkanApplication end

"""
While handles are primordial for executing Vulkan API calls, they usually involve a lot more information that is intrinsically linked with the handle itself. A setup wraps a `Handle` by gathering the information that is required for a given piece of the application to work. For a logical device, that would include the physical device and the device itself (as a `Handle`), as well as its queues, semaphores and fences. A swapchain is also bound to a `Handle`, covers a certain extent of a surface and possesses images. When performing API calls, since a `Setup` object is bound to a handle, there is no need to specify the handle manually. The `Setup` object will automatically be converted to its handle when such call is performed.
"""
abstract type Setup end

# to avoid having to specify the handle every time an API call is made
Base.cconvert(T::Type{<: Ptr}, x::Setup) = x.handle
Base.convert(T::Type{<: Handle}, x::Setup) = x.handle
Base.broadcastable(x::Setup) = Ref(x)
Base.broadcastable(x::VulkanApplication) = Ref(x)

mutable struct AppSetup <: Setup
    handle::Instance
    debug_messenger
    function AppSetup(instance::Instance; debug_messenger = nothing)
        as = new(instance, debug_messenger)
        finalizer(as) do x
            finalize.(getproperty.(x, (:debug_messenger, :handle)))
        end
    end
end

Base.@kwdef struct Queues
    present = nothing
    graphics = nothing
    compute = nothing
end

struct DeviceQueue <: Setup
    handle
    queue_index
    queue_family_index
end

mutable struct DeviceSetup <: Setup
    handle::Device
    physical_device_handle::PhysicalDevice
    queues::Queues
    semaphores::Dict{Symbol, Semaphore}
    fences::Dict{Symbol, Fence}
    function DeviceSetup(handle, physical_device_handle, queues; semaphores = Dict{Symbol, Semaphore}(), fences = Dict{Symbol, Fence}())
        ds = new(handle, physical_device_handle, queues, semaphores, fences)
        finalizer(ds) do x
            finalize.(values(x.semaphores))
            finalize.(values(x.fences))
            finalize(x.handle)
        end
    end
end

mutable struct SwapchainSetup <: Setup
    handle::SwapchainKHR
    buffering::Int
    format::Format
    colorspace::ColorSpaceKHR
    extent::Extent2D
    layers::Int
    usage::ImageUsageFlags
    sharing_mode::SharingMode
    present_mode::PresentModeKHR
    clipped::Bool
    images::Array{Image, 1}
    image_views::Array{ImageView, 1}
    function SwapchainSetup(args...)
        ss = new(args...)
        finalizer(ss) do x
            finalize.(x.image_views)
            finalize(x.handle)
        end
    end
end

mutable struct SurfaceSetup <: Setup
    handle::SurfaceKHR
    window
    function SurfaceSetup(handle; window = nothing)
        ss = new(handle, window)
        finalizer(ss) do x
            finalize(x.handle)
        end
    end
end

mutable struct PipelineSetup <: Setup
    handle
    shader_modules
    layout
    cache
    stages
    function PipelineSetup(shader_modules, stages; layout = C_NULL, cache = C_NULL)
        ps = new(C_NULL, shader_modules, layout, cache, stages)
        finalizer(ps) do x
            finalize.(x.shader_modules)
            finalize.(getproperty.(x, (:handle, :layout, :cache)))
        end
    end
end

mutable struct BufferSetup <: Setup
    handle::Buffer
    memory::DeviceMemory
    function BufferSetup(device::DeviceSetup, size, usage, memory_properties, sharing_mode=SHARING_MODE_EXCLUSIVE, queue_families=[], flags=0, next=C_NULL)
        buffer = Buffer(device, BufferCreateInfo(size, usage, sharing_mode, queue_families; flags, next))
        mem_reqs = get_buffer_memory_requirements(device, buffer)
        physical_device = device.physical_device_handle
        index = find_memory_type(physical_device, mem_reqs.memory_type_bits, memory_properties)
        buffer_memory = allocate_memory(device, MemoryAllocateInfo(mem_reqs.size, index))
        finalizer(x -> free_memory(device, memory=x), buffer_memory)
        bind_buffer_memory(device, buffer, buffer_memory, 0)
        bs = new(buffer, buffer_memory)
        finalizer(x -> finalize.(getproperty.(x, [:handle, :memory])), bs)
    end
end

mutable struct ViewportState
    viewport
    scissor
end

mutable struct RenderState
    frame
    frame_index
    arr_sem_image_available
    arr_sem_render_finished
    arr_fen_image_drawn
    arr_fen_acquire_image
    arr_command_buffers
    max_simultaneously_drawn_frames
    function RenderState(args...)
        rs = new(args...)
        finalizer(rs) do x
            finalize.(x.arr_sem_image_available)
            finalize.(x.arr_sem_render_finished)
            finalize.(x.arr_fen_acquire_image)
            finalize.(x.arr_fen_image_drawn)
        end
    end
end


mutable struct VulkanApplicationSingleDevice <: VulkanApplication
    app::AppSetup
    device
    surface
    swapchain
    framebuffers
    command_pools::Dict{Symbol, CommandPool}
    viewport
    render_pass
    render_state
    pipelines::Dict{Symbol, PipelineSetup}
    buffers::Dict{Symbol, BufferSetup}
    function VulkanApplicationSingleDevice(
                                        app::AppSetup;
                                        device           = nothing,
                                        surface          = nothing,
                                        swapchain        = nothing,
                                        framebuffers     = Framebuffer[],
                                        command_pools    = Dict{Symbol, CommandPool}(),
                                        viewport         = nothing,
                                        render_pass      = nothing,
                                        render_state     = nothing,
                                        pipelines        = Dict{Symbol, Pipeline}(),
                                        buffers          = Dict{Symbol, BufferSetup}(),
                                        )
        vasg = new(app, device, surface, swapchain, framebuffers, command_pools, viewport, render_pass, render_state, pipelines, buffers)
        finalizer(vasg) do x
            # !isnothing(x.device) && (device_wait_idle(x.device.handle); @debug("Device idle"))
            finalize.(values(x.pipelines))
            finalize.(values(x.buffers))
            !isempty(x.framebuffers) && finalize.(x.framebuffers)
            finalize.(values(x.command_pools))
                # finalize.(command_pool, pipeline, framebuffers..., pipeline_layout, render_pass, image_views..., swapchain, surface, sem_image_available..., sem_render_finished..., fen_wait_images_drawn..., device, dbg, instance)
            finalize.(getproperty.(x, (:render_pass, :render_state, :swapchain, :surface, :device, :app)))
        end
    end
end

struct PipelineState
    vertex_input_state::PipelineVertexInputStateCreateInfo
    input_assembly_state::PipelineInputAssemblyStateCreateInfo
    shaders::Vector{PipelineShaderStageCreateInfo}
    rasterization::PipelineRasterizationStateCreateInfo
    multisample_state::PipelineMultisampleStateCreateInfo
    color_blend_state::PipelineColorBlendStateCreateInfo
    dynamic_state
end

abstract type BlendingMode end

struct NoBlending <: BlendingMode end
Base.@kwdef struct AlphaBlending <: BlendingMode
    factor = 1
end

struct Target{T} end
abstract type RenderPassType end
struct RenderPassPresent{T} <: RenderPassType
    target::T
end
