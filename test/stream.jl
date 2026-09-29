# Reading a sequence of values from a stream as the data arrives.
module TestStream

using Test
import Transit

const VALUES = Any[1, "~tilde", Any[:abcd, :abcd],
                   Dict{Any,Any}(:abcd => "quote \" and backslash \\ é \U0001f600"),
                   Transit.TSet([1, 2]), nothing]

function written(values, verbose)
    buf = IOBuffer()
    for v in values
        Transit.write(buf, v, verbose)
    end
    take!(buf)
end

# A stream that data trickles into n bytes at a time, like a pipe.
function trickle(data::Vector{UInt8}, n::Int)
    s = Base.BufferStream()
    @async begin
        for i in 1:n:length(data)
            write(s, data[i:min(i + n - 1, length(data))])
            yield()
        end
        close(s)
    end
    s
end

for verbose in (false, true)
    data = written(VALUES, verbose)
    # sizes that split escapes and multi-byte characters
    for n in (1, 2, 3, 7, length(data))
        @test collect(Transit.eachvalue(trickle(data, n))) == VALUES
    end
end

@test collect(Transit.eachvalue(IOBuffer(" [\"~#'\",1]\n\t{\"~#'\":2}  \n"))) == [1, 2]
@test isempty(collect(Transit.eachvalue(IOBuffer(""))))
@test_throws ArgumentError collect(Transit.eachvalue(IOBuffer("[1,\"a]")))

# bin/roundtrip is what transit-format's verify harness drives.
const REPO = joinpath(@__DIR__, "..")
for (encoding, verbose) in (("json", false), ("json-verbose", true))
    data = written(VALUES, verbose)
    cmd = `$(Base.julia_cmd()) --project=$REPO --startup-file=no $(joinpath(REPO, "bin", "read-write")) $encoding`
    out = read(pipeline(cmd; stdin=IOBuffer(data)))
    @test out == data
end

end
