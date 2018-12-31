"""
    my_maximum(xs, ord::Ord = Forward) → Union{Nothing,eltype(xs)}

Returns the maximum of the iterable `xs` under the order defined by `ord`. Linear-time
implementation of `my_sort(xs, ord)[end]`.

If `xs` is empty, returns `nothing`.
"""
function my_maximum(xs, less::Ord = Forward)
    y = iterate(xs)

    # Empty iterator
    y === nothing && return nothing

    # Extract the first value
    max, state = y

    # Manually iterate the rest
    y = iterate(xs, state)

    while y !== nothing
        val, state = y

        if less(max, val)
            max = val
        end
        
        y = iterate(xs, state)
    end

    return max
end

@inline my_minimum(xs, o::Ord = Forward) = my_maximum(xs, Rev(o))
