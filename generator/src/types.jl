const ExprLike = Union{Symbol, Expr}
const Optional{T} = Union{Nothing, T}

is_ptr_to_ptr(ex) = !isnothing(ptrtype(ptrtype(ex)))
is_ptr(ex) = !isnothing(ptr_type(ex))

ptr_type(ex) = @when :(Ptr{$T}) = ex T
ntuple_type(ex) = @when :(NTuple{$N, $T}) = ex T

is_ntuple(ex) = !isnothing(ntuple_type(ex))

is_vulkan_type(name) = name ∈ vcat(spec_structs.name, spec_handles.name)

inner_type(ex) = @when :($T{$(args...)}) = ex collect(args)

function innermost_type(ex::Expr)
    if is_ntuple(ex)
        innermost_type(ntuple_type(ex))
    else
        t = inner_type(ex)
        if !isnothing(t)
            if length(t) > 1
                error("Expected 1 inner type for $ex, found $(length(t)) ($t)")
            else
                innermost_type(first(t))
            end
        else
            nothing
        end
    end
end

innermost_type(sym::Symbol) = sym
