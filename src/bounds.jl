function upperbound(xs::AbstractVector, value, lo::Integer, hi::Integer, ord::Ord = Forward)
    count = hi - lo + 1

    while count > 0
        step = count ÷ 2
        p = lo + step
        @inbounds if !ord(value, xs[p])
            lo = p + 1
            count -= step + 1
        else
            count = step
        end
    end

    return lo - 1
end

function lowerbound(xs::AbstractVector, value, lo::Integer, hi::Integer, ord::Ord = Forward)
    count = hi - lo + 1

    while count > 0
        step = count ÷ 2
        p = lo + step
        @inbounds if ord(xs[p], value)
            lo = p + 1
            count -= step + 1
        else
            count = step
        end
    end

    return lo
end

upperbound(xs::AbstractVector, value, ord::Ord = Forward) =
    upperbound(xs::AbstractVector, value, 1, length(xs), ord)

lowerbound(xs::AbstractVector, value, ord::Ord = Forward) =
    lowerbound(xs::AbstractVector, value, 1, length(xs), ord)

equalrange(xs::AbstractVector, value, ord::Ord = Forward) = 
    lowerbound(xs, value, ord):upperbound(xs, value, ord)
