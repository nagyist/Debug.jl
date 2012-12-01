include(find_in_path("Debug.jl"))

module TestGraft
export @syms
using Base, Debug.AST, Debug.Meta, Debug.Eval
import Debug, Debug.instrument
export cut_grafts, @test_graft

macro assert_fails(ex)
    quote
        if (try; $(esc(ex)); true; catch e; false; end)
            error($("@assert_fails: $ex didn't fail!"))
        end
    end
end

macro graft(args...)
    error("Should never be invoked directly!")
end

macro test_graft(ex)
    stem, grafts = cut_grafts(ex)
    grafts = tuple(grafts...)  # make grafts work as just a value
    trap = (loc, scope)->debug_eval(scope, grafts[loc.line])
    esc(instrument(quot(trap), stem))
end

cut_grafts(ex) = (grafts = {}; (cut_grafts!(grafts, ex), grafts))

cut_grafts!(grafts::Vector, ex) = ex
function cut_grafts!(grafts::Vector, ex::Expr)
    code = {}
    for arg in argsof(ex)
        if Debug.Analysis.is_linenumber(arg)
            # omit the original line numbers
        elseif is_expr(arg, :macrocall) && argof(arg,1) == symbol("@graft")
            @assert nargsof(arg) == 2                
            push(grafts, argof(arg, 2))
            push(code, expr(:line, length(grafts)))
        else
            push(code, cut_grafts!(grafts, arg))
        end
    end
    expr(headof(ex), code)
end

type T
    x
    y
end

@test_graft let
    # test read and write, both ways
    local x = 11
    @graft (@assert x == 11; x = 2)
    @assert x == 2
    
    # test tuple assignment in graft
    local y, z 
    @graft y, z = 12, 23 
    @assert (y, z) == (12, 23)
    
    # test updating operator in graft
    q = 3
    @graft q += 5
    @assert q == 8
    
    # test assignment to ref in graft (don't rewrite)
    a = [1:5]
    @graft a[2]  = 45
    @graft a[3] += 1
    @assert isequal(a, [1,45,4,4,5])
    
    # test assignment to field in graft (don't rewrite)
    t = T(7,83)
    @graft t.x  = 71
    @graft t.y -= 2
    @assert (t.x == 71) && (t.y == 81)
    
    # test that k inside the grafted let block is separated from k outside
    k = 21
    @graft let k=5
        @assert k == 5
    end
    @assert k == 21
    
    # test that assignments to local vars don't leak out
    @graft let
        l = 3
    end
    
    # test that assignements to shared vars do leak out
    s = 1
    @graft let
        s = 6
    end
    @assert s == 6
end

@test_graft begin
    type TT
        x::Int
        function TT(x)
            local z
            @graft z=2x
            new(z)
        end
    end

    t = TT(42)
    @assert t.x == 84
end

@assert_fails @test_graft let
    @graft a = 3
end
@assert_fails @test_graft let
    @graft local d1 = 3
end
@assert_fails @test_graft let
    @graft local d2
end

end # module
