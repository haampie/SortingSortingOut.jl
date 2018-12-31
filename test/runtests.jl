using SortingSortingOut
using Test

@testset "maximum" begin
    @test my_maximum([])                          === nothing
    @test my_maximum([1, 2, 3, -1, -2])           === 3
    @test my_maximum([1, 2, 3, -1, -2], Backward) === -2
    @test my_maximum([-5, 0, 2], By(abs))         === -5
    @test my_maximum([1, 3, 2], Forward)          === my_sort([1, 3, 2], Forward)[end]

    @test my_minimum([])                          === nothing
    @test my_minimum([1, 2, 3, -1, -2])           === -2
    @test my_minimum([1, 2, 3, -1, -2], Backward) === 3
    @test my_minimum([-5, 0, 2], By(abs))         === 0
    @test my_minimum([2, 1, 3], Forward)          === my_sort([2, 1, 3], Forward)[1]
end

@testset "iterators" begin
    @test my_maximum((i for i = 1 : 10))           === 10
    @test my_maximum((i for i = 1 : 10), Backward) === 1
end

