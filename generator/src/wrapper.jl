using JuliaFormatter

include("wrapper/exprs.jl")
include("wrapper/type_conversions.jl")
include("wrapper/naming_conventions.jl")
include("wrapper/conventions.jl")
include("wrapper/wrap.jl")

include("wrapper/dependency_resolution.jl")
include("wrapper/write.jl")

export
        # Naming Conventions
        ### Convention types
        CamelCaseLower,
        CamelCaseUpper,
        SnakeCaseLower,
        SnakeCaseUpper,

        ### Convention utilities
        detect_convention,
        enforce_convention,
        nc_convert,
        remove_parts,
        remove_prefix,

        ### Vulkan specific
        vulkan_to_julia,
        prefix_vk,
        vk_prefix,

        # Expr
        name,
        category,
        deconstruct,
        reconstruct,
        rmlines,
        striplines,
        unblock,
        prettify,

        VulkanWrapper,
        wrap,
        add_constructor,
        extend_from_vk


