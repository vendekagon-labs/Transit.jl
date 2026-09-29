# To run this, BenchmarkTools needs to be available, e.g. in your default
# environment:
#
# julia -e 'using Pkg; Pkg.add("BenchmarkTools")'
# julia --project test/seattle_benchmark.jl

using BenchmarkTools
import Transit

const SEATTLEDIR = joinpath(get(ENV, "TRANSIT_FORMAT_DIR", joinpath(@__DIR__, "..", "..", "transit-format")),
                            "examples", "0.8")
const JSONFILE = joinpath(SEATTLEDIR, "example.json")
const JSONVERBOSEFILE = joinpath(SEATTLEDIR, "example.verbose.json")

println("Transit JSON parse")
display(@benchmark Transit.parse(data) setup=(data = read(JSONFILE, String)))
println("\n")
println("Transit JSON verbose parse")
display(@benchmark Transit.parse(data) setup=(data = read(JSONVERBOSEFILE, String)))
println()
