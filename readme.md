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
method_in_some_package!(xs::AbstractVector, ord) = my_sort!(xs, Rev(By(abs, ord)))

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
> my_sort!(xs, effective_ord)
```

The above is completely equivalent to:

```julia
> my_sort!(xs, ord)
```

#### Example: sorting products by weight

| n      | `sort!`  | `my_sort!` | speedup |
|--------|----------|-------------|---------|
| 10_000 | 1.113 ms | 560.6 μs    | 2.0x    |
| 1_000  | 66.00 μs | 11.66 μs    | 5.7x    |
| 100    | 2.021 μs | 615.6 ns    | 3.3x    |

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
    snd = @benchmark my_sort!(ps, $(By(weight))) setup = (ps = copy($products))

    fst, snd
end
```

#### Example: sorting complex numbers by absolute magnitude

| n      | `sort!`  | `my_sort!` | speedup |
|--------|----------|-------------|---------|
| 10_000 | 1.128 ms | 722.3 μs    | 1.6x    |
| 1_000  | 49.62 μs | 28.16 μs    | 1.8x    |
| 100    | 2.296 μs | 787.5 ns    | 2.9x    |

```julia
using SortingSortingOut, BenchmarkTools

function sort_by_magnitude(n = 1_000)
    xs = rand(ComplexF64, n)

    fst = @benchmark sort!(ys, by = $abs2) setup = (ys = copy($xs))
    snd = @benchmark my_sort!(ys, $(By(abs2))) setup = (ys = copy($xs))

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

### `maximum` and `minimum` accept `Ord` instances

Two changes to these methods:
1. They return `nothing` when an empty collection is passed
2. They accept `Ord` instances and satisfy 
   `my_maximum(xs, ord) == my_sort(Vector(xs), ord)[end]` and 
   `my_minimum(xs, ord) === my_sort(Vector(xs), ord)[1]`.

```julia
using SortingSortingOut

my_maximum([1, -2, 3, -5], By(abs)) # -5
my_maximum((i for i = 1 : 10), Forward) # 10
my_maximum([]) # nothing
```

### Make search convenient -- search by (transformed) value, not by specific vector element

Currently there is an [unresolved issue](https://github.com/JuliaLang/julia/issues/9429)
in Julia Base where one has to construct a "fake" vector element in order to search. For 
instance:

```julia
julia> struct Product
         name::String
         price::Int
       end;

julia> products = [Product("Apple", 75), Product("Book", 1200), Product("Car", 50000)];

julia> searchsortedfirst(products, 100, by = p -> p.price)
ERROR: type Int64 has no field price

julia> searchsortedfirst(products, Product("Fake product", 100), by = p -> p.price)
2
```

A solution to this problem is to implement a new comparison function:

```julia
julia> is_price_less(product::Product, price::Int) = isless(product.price, price);
julia> is_price_less(price::Int, product::Product) = isless(price, product.price);
julia> searchsortedfirst(products, 100, lt = is_price_less)
2
```

but this seems more verbose than necessary and will not work whenever the type of the 
transformed value is equal to the original element type of the vector. 

For instance, suppose we have a vector of integers sorted by absolute magnitude, and we 
naively search for the index of the first value greater than or equal to `-2`. This should 
obvioulsy be the first index. The following does *not* work as (maybe?) expected

```julia
julia> searchsortedfirst([1, 2, 2, 3, 3, 4], -2, by = abs)
2
```
since `-2` gets transformd to `2`. To solve this we have to provide a different comparison
operator and build a `Wrapper` struct to make multiple dispatch work:

```julia
julia> struct Wrapper
         value
       end;
julia> abs_lt(a, b::Wrapper) = isless(abs(a), b.value)
julia> abs_lt(a::Wrapper, b) = isless(a.value, abs(b))
julia> searchsortedfirst([1, 2, 2, 3, 3, 4], Wrapper(-2), lt = abs_lt)
1
```

But this is very verbose and hard to untangle. Also it does not seem to compose well.

To address this, this package provides a wrapper type called `Value` which allows you to 
write simple one-liners:

```julia
julia> lowerbound(products, 100, By(p -> p.price))
ERROR: type Int64 has no field price

julia> lowerbound(products, Value(100), By(p -> p.price))
2

julia> lowerbound([1, 2, -2, 3, 3, 4], -2, By(abs)) # transformation applies to -2
2

julia> lowerbound([1, 2, -2, 3, 3, 4], Value(-2), By(abs)) # no transformation of -2
1
```

Also note that the functions have been renamed a bit:

- `searchsortedfirst` -> `lowerbound`
- `searchsortedlast` -> `upperbound`
- `searchsorted` -> `equalrange`