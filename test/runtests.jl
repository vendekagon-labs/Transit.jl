using Test

@testset "Transit" begin
    @testset "tset" begin include("tset.jl") end
    @testset "decoder" begin include("decoder.jl") end
    @testset "encoder" begin include("encoder.jl") end
    @testset "roundtrip" begin include("roundtrip.jl") end
    @testset "cache" begin include("cache.jl") end
    @testset "stream" begin include("stream.jl") end
    @testset "exemplar" begin include("exemplar.jl") end
end
