###
### Special algorithm for sorting floating points
###


using Core.Intrinsics: slt_int

const Floats = Union{Float32,Float64}

# Specialization for floating point numbers
function _serioussort!(v::AbstractVector, lo::Int, hi::Int, a::QuickSortAlg, o::TrivialOrder{T,typeof(isless),reverse}) where {T<:Floats, reverse}
    i, j = lo, hi = movenans!(v, o, lo, hi)
    # Pre-process [negative | positive]
    @inbounds while true
        while i ≤ j &&  hassign(v[i], o); i += 1; end
        while i ≤ j && !hassign(v[j], o); j -= 1; end
        i ≤ j || break
        v[i], v[j] = v[j], v[i]
        i += 1; j -= 1
    end

    fastorder = TrivialOrder{T}((a,b) -> slt_int(a,b), o.fs)
    _serioussort!(v, lo, j,  a, Rev(fastorder))
    _serioussort!(v, i,  hi, a, fastorder)
    return v
end


hassign(x, o::TrivialOrder{T,O,true}) where {T,O} = 0 < by(o, x)
hassign(x, o::TrivialOrder{T,O,false}) where {T,O} = by(o, x) < 0

function movenans!(v::AbstractVector, o::TrivialOrder{T,O,true}, lo::Int, hi::Int) where {T,O}
    i = lo
    @inbounds while i <= hi && isnan(by(o, v[i]))
        i += 1
    end
    j = i + 1
    @inbounds while j <= hi
        if isnan(by(o, v[j]))
            v[i], v[j] = v[j], v[i]
            i += 1
        end
        j += 1
    end
    return i, hi
end

function movenans!(v::AbstractVector, o::TrivialOrder{T,O,false}, lo::Int, hi::Int) where {T,O}
    i = hi
    @inbounds while lo <= i && isnan(by(o, v[i]))
        i -= 1
    end
    j = i - 1
    @inbounds while lo <= j
        if isnan(by(o, v[j]))
            v[i], v[j] = v[j], v[i]
            i -= 1
        end
        j -= 1
    end
    return lo, i
end