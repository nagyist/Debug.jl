
module Debug
using Base
export @debug, @instrument, @bp, debug_eval, Scope, Node, BlockNode, BPNode

include(find_in_path("Debug/src/AST.jl"))
include(find_in_path("Debug/src/Meta.jl"))
include(find_in_path("Debug/src/Analysis.jl"))
include(find_in_path("Debug/src/Graft.jl"))
include(find_in_path("Debug/src/Eval.jl"))
include(find_in_path("Debug/src/Flow.jl"))
include(find_in_path("Debug/src/UI.jl"))
using AST, Meta, Analysis, Graft, Eval, Flow, UI

instrument(pred, trap_ex, ex) = Graft.instrument(pred, trap_ex, analyze(ex, true))

is_trap(::Union(LocNode,BlockNode)) = false
is_trap(node::Node)                 = isa(parentof(node), BlockNode)

macro debug(ex)
    code_debug(UI.instrument(ex))
end
macro instrument(trap_ex, ex)
    @gensym trap_var
    code_debug(quote
        const $trap_var = $trap_ex
        $(instrument(is_trap, trap_var, ex))
    end)
end

function code_debug(ex)
    globalvar = esc(gensym("globalvar"))
    quote
        $globalvar = false
        try
            global $globalvar
            $globalvar = true
        end
        if !$globalvar
            error("@debug: must be applied in global scope!")
        end
        $(esc(ex))
    end
end

end # module
