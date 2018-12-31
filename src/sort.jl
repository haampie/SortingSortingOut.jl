
using Base.Sort: Algorithm, QuickSortAlg, InsertionSortAlg, SMALL_THRESHOLD,
                 SMALL_ALGORITHM

# General API (without kwargs so far)

my_sort(xs, o::Ord = Forward) = 
    my_sort!(copy(xs), o)

my_sort!(xs, o::Ord = Forward) = 
    my_sort!(xs, first(axes(xs, 1)), last(axes(xs, 1)), QuickSort, o)

my_sort!(xs::AbstractVector{T}, lo::Int, hi::Int, a::Algorithm, o::Ord) where {T} = 
    _my_sort!(xs, lo, hi, a, flatten(o, T))


# Some implementations

###
### Insertion sort
###
function _my_sort!(v::AbstractVector, lo::Int, hi::Int, ::InsertionSortAlg, less::Ord)
    @inbounds for i = lo+1:hi
        j = i
        x = v[i]
        while j > lo
            if less(x, v[j-1])
                v[j] = v[j-1]
                j -= 1
                continue
            end
            break
        end
        v[j] = x
    end
    return v
end

###
### Quicksort
###
function _my_sort!(v::AbstractVector, lo::Int, hi::Int, a::QuickSortAlg, less::Ord)
    @inbounds while lo < hi
        hi-lo <= SMALL_THRESHOLD && return _my_sort!(v, lo, hi, SMALL_ALGORITHM, less)
        j = partition!(v, lo, hi, less)
        if j-lo < hi-j
            # recurse on the smaller chunk
            # this is necessary to preserve O(log(n))
            # stack space in the worst case (rather than O(n))
            lo < (j-1) && _my_sort!(v, lo, j-1, a, less)
            lo = j+1
        else
            j+1 < hi && _my_sort!(v, j+1, hi, a, less)
            hi = j-1
        end
    end
    return v
end

@inline function selectpivot!(v::AbstractVector, lo::Int, hi::Int, less::Ord)
    @inbounds begin
        mi = (lo+hi)>>>1

        # sort the values in v[lo], v[mi], v[hi]

        if less(v[mi], v[lo])
            v[mi], v[lo] = v[lo], v[mi]
        end
        if less(v[hi], v[mi])
            if less(v[hi], v[lo])
                v[lo], v[mi], v[hi] = v[hi], v[lo], v[mi]
            else
                v[hi], v[mi] = v[mi], v[hi]
            end
        end

        # move v[mi] to v[lo] and use it as the pivot
        v[lo], v[mi] = v[mi], v[lo]
        pivot = v[lo]
    end

    # return the pivot
    return pivot
end

# partition!
#
# select a pivot, and partition v according to the pivot

function partition!(v::AbstractVector, lo::Int, hi::Int, less::Ord)
    pivot = selectpivot!(v, lo, hi, less)
    # pivot == v[lo], v[hi] > pivot
    i, j = lo, hi
    @inbounds while true
        i += 1; j -= 1
        while less(v[i], pivot); i += 1; end;
        while less(pivot, v[j]); j -= 1; end;
        i >= j && break
        v[i], v[j] = v[j], v[i]
    end
    v[j], v[lo] = pivot, v[j]

    # v[j] == pivot
    # v[k] >= pivot for k > j
    # v[i] <= pivot for i < j
    return j
end
