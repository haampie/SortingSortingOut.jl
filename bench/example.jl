using SortingSortingOut, BenchmarkTools, Random

# n = 10_000: 1.128 ms vs 722.3 μs (35%)
# n =  1_000: 49.62 μs vs 28.16 μs (43%)
# n =    100: 2.296 μs vs 787.5 ns (65%)
function sort_by_magnitude(n = 1_000)
    xs = rand(ComplexF64, n)

    @info "Sanity check" sort(xs, by=abs2) == sortsort(xs, By(abs2))

    fst = @benchmark sort!(ys, by = $abs2) setup = (ys = copy($xs))
    snd = @benchmark sortsort!(ys, $(By(abs2))) setup = (ys = copy($xs))

    fst, snd
end

struct Product
    price::Int
    weight::Float64
end

weight(p::Product) = p.weight

# n = 10_000: 1.113 ms vs 560.6 μs (50%)
# n =  1_000: 66.00 μs vs 11.66 μs (82%)
# n =    100: 2.021 μs vs 615.6 ns (70%)
function sort_products(n = 100)
    products = [Product(rand(1:100), 100rand()) for i = 1 : n]

    @info "Sanity check" sort(products, by=weight) == sortsort(products, By(weight))

    fst = @benchmark sort!(ps, by = $weight) setup = (ps = copy($products))
    snd = @benchmark sortsort!(ps, $(By(weight))) setup = (ps = copy($products))

    fst, snd
end