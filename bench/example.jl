using SortingSortingOut, BenchmarkTools

function bench()
    is = rand(Int, 1000)
    f = x -> x * (1 - x) / (x + 100)

    fst = @benchmark sort!(js, by = $f) setup = (js = copy($is))
    snd = @benchmark serioussort!(js, $(By(f))) setup = (js = copy($is))

    fst, snd
end