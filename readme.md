# SortingSortingOut.jl

Experiments with a new sorting & ordering API for Julia.

## Features

### Composable order types

Exports functor-like objects `By`, `Rev` and `Op` and the predefined ordering

```julia
const Forward = Op(isless)
const Backward = Rev(Forward)
```

These objects compose well:

```julia
method_in_some_package!(xs::AbstractVector, ord) = sortsort!(xs, Rev(By(abs, ord)))

xs = randn(7)
perm = collect(1:7)
ord = By(i -> xs[i])
method_in_some_package!(perm, ord)

@show xs[perm]
# xs[perm] = [-1.20628, 1.03054, -0.929885, -0.620184, 0.391168, -0.29274, 0.172728]
```

### Better dispatch of specialized algorithms
Currently we have an advanced sorting algorithm to sort `Float64` and `Float32` by the order
induced by `isless`, but the downside is that we *almost never* dispatch on it in practice 
because of the restrictive signature:

```julia
sort!(v::AbstractVector{<:Union{Float32,Float64}}, ...)
```

For instance `sort([1.0, 2.0, -3.0], by = abs)` will not match the signature.

**The proposed fix** in this package is to canonicalize the order instances such that we can
dispatch on (a) the inferred type that goes into the comparison function, (b) the comparison
function itself and (c) the direction (forward or backward). 

Internally it works by summarizing composed ordering types in a linearized fashion via a 
function called `flatten`. This function takes an ordering and element type of the vector 
and returns a `TrivialOrder{T,F,R<:Bool,B} <: Ord` instance (and sometimes the original
order if it thinks the order is nontrivial). Here `T` is the type that goes into the 
comparison function, `F` is the type of the comparison function itself, `R` is true when 
sorting in reverse and `B` is a tuple of types of all the gathered `by` functions / 
transformations. An explicit example:

```julia
> xs = [6, 5, 2, 7]
> ord = By(inv, Rev(By(abs, Backward))) # 2 by functions
> effective_ord = SortingSortingOut.flatten(ord, eltype(xs))
TrivialOrder{Float64,typeof(isless),false,Tuple{typeof(inv),typeof(abs)}}(isless, (inv, abs))
# Effectively this order comes down to sorting `Float64` with `isless`, so sorting will
# automatically dispatch on the efficient algorithm for this order.
> sortsort!(xs, effective_ord)
```

The above is completely equivalent to:

```julia
> sortsort!(xs, ord)
```

#### Example: sorting products by weight

+--------+----------+-------------+----------+
| n      | `sort!`  | `sortsort!` | % faster |
+--------+----------+-------------+----------+
| 10_000 | 1.113 ms | 560.6 μs    | 50%      |
| 1_000  | 66.00 μs | 11.66 μs    | 82%      |
| 100    | 2.021 μs | 615.6 ns    | 70%      |
+--------+----------+-------------+----------+

```julia
using SortingSortingOut, BenchmarkTools

struct Product
    price::Int
    weight::Float64
end

weight(p::Product) = p.weight

function sort_products(n = 100)
    products = [Product(rand(1:100), 100rand()) for i = 1 : n]

    fst = @benchmark sort!(ps, by = $weight) setup = (ps = copy($products))
    snd = @benchmark sortsort!(ps, $(By(weight))) setup = (ps = copy($products))

    fst, snd
end
```

#### Example: sorting complex numbers by absolute magnitude

+--------+----------+-------------+----------+
| n      | `sort!`  | `sortsort!` | % faster |
+--------+----------+-------------+----------+
| 10_000 | 1.128 ms | 722.3 μs    | 35%      |
| 1_000  | 49.62 μs | 28.16 μs    | 43%      |
| 100    | 2.296 μs | 787.5 ns    | 65%      |
+--------+----------+-------------+----------+

```
using SortingSortingOut, BenchmarkTools

function sort_by_magnitude(n = 1_000)
    xs = rand(ComplexF64, n)

    fst = @benchmark sort!(ys, by = $abs2) setup = (ys = copy($xs))
    snd = @benchmark sortsort!(ys, $(By(abs2))) setup = (ys = copy($xs))

    fst, snd
end
```

#### Sorting vectors of small unions

Via the exact same logic as the fast floating point sort code, we could potentially also
efficiently sort `Vector{Union{T,Nothing}}` by partitioning the vector in `[T..., Nothing...]`
first, and subsequently calling a fast sort method on the first bit with just `T`'s.

And this package would then allow to also sort `sort!(v, by = maybe_something)` where the
function `maybe_something` returns for instance `Union{T,Missing}` values.

However, AFAIK this cannot yet work because we cannot convince the compiler (without 
overhead) that a value of type `Union{T,Nothing}` is actually a `T`  -- even when we're 
100% sure it is.