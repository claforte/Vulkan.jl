command_pool = CommandPool(device, 0)
cbuffer = first(unwrap(allocate_command_buffers(device, CommandBufferAllocateInfo(command_pool, COMMAND_BUFFER_LEVEL_PRIMARY, 1))))
@test cbuffer isa CommandBuffer
