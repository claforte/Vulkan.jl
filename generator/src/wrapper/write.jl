"""
Write the wrapper to `destfile`.
"""
function Base.write(vw::VulkanWrapper, destfile)
    exprs = vcat(vw.handles, vw.structs, vw.funcs, vw.misc)
    ordered_exprs = sort_expressions(exprs)
    structs = filter(is_category(:struct), ordered_exprs)
    funcs = filter(is_category(:function), ordered_exprs)

    open(destfile, "w+") do io
        print_block(io, structs)
        print_block(io, funcs)
        print_block(io, setdiff(ordered_exprs, vcat(structs, funcs)))

        write_exports(io, exprs)
    end
end

function sort_expressions(exprs)
    exprs_order = resolve_dependencies(name.(exprs), exprs)
    ordered_exprs = exprs[exprs_order]
    check_dependencies(ordered_exprs)

    ordered_exprs
end

is_category(cat) = x -> category(x) == cat

function print_block(io::IO, exs)
    print.(Ref(io), block.(exs))
    println(io)
end

block(ex::Expr) = string(prettify(ex)) * spacing(ex)

spacing(ex::Expr) = spacing(ex, category(ex))

spacing(ex, cat) = @match cat begin
    :struct => '\n'^2
    :function => '\n'^2
    :const => '\n'
    :enum => '\n'
end

function write_exports(io::IO, decls)
    println(io)

    ignored_symbols = vcat(:(Base.convert), :Base)

    decl_symbols = sort(filter(!in(ignored_symbols), unique(name.(decls))))

    exports = :(export $([decl_symbols; getproperty.(spec_all_semantic_enums, :name)]...))

    println(io, string(exports))
end