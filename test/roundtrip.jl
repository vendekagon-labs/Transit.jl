module TestRoundTrip

using Test
using Transit
using Dates

import DataStructures: list, nil

# Write the value as transit and read it back in.
function round_trip(x, verbose=false)
    buf = IOBuffer()
    Transit.write(buf, x, verbose)
    s = String(take!(buf))
    Transit.parse(IOBuffer(s))
end

function test_round_trip(value, verbose=false)
    x = round_trip(value, verbose)
    x == value
end

for verbose in (false, true)
    @test test_round_trip(1, verbose)
    @test test_round_trip(1.0, verbose)
    @test test_round_trip("hello", verbose)
    @test test_round_trip("~hello", verbose)
    @test test_round_trip("^ ", verbose)
    @test test_round_trip("`hello", verbose)
    @test test_round_trip(true, verbose)
    @test test_round_trip(false, verbose)
    @test test_round_trip(nothing, verbose)
    @test test_round_trip(2//3, verbose)
    @test test_round_trip([1,2,3], verbose)
    @test test_round_trip(list(1,2,"hello"), verbose)
    @test test_round_trip(nil(), verbose)
    @test test_round_trip('c', verbose)
    @test test_round_trip(UInt8[0, 1, 255], verbose)
    @test test_round_trip(big(2)^100, verbose)
    @test test_round_trip(parse(Transit.Decimal, "190234710272.2394720347203642836434"), verbose)
    @test test_round_trip(DateTime(1776, 7, 4, 12, 0, 0, 1), verbose)
    @test test_round_trip(Base.UUID("5a2cbea3-e8c6-428b-b525-21239370dd55"), verbose)
    @test test_round_trip(Transit.TURI("http://www.詹姆斯.com/"), verbose)
    @test test_round_trip(Transit.Link("http://x.com", "self"; render="link"), verbose)
    @test test_round_trip(Transit.TaggedValue("point", Any[1, 2]), verbose)
    @test test_round_trip(Dict{Any,Any}(nothing => 1, true => 2, 1 => 3, 1.5 => 4, 'c' => 5), verbose)
    @test test_round_trip(Dict{Any,Any}(Any[1] => 1, :a => Dict{Any,Any}(:b => 2)), verbose)

    @test test_round_trip([:hello, :hello, :hello], verbose)
    @test test_round_trip([:aaaa, :bbbb, :aaaa, :bbbb], verbose)
    @test test_round_trip([Transit.TSymbol("hello"), Transit.TSymbol("hello")], verbose)

    @test test_round_trip(Dict([("aaa", 11), ("bbb", 22)]), verbose)

    @test test_round_trip(Transit.TSet([1,2,3]), verbose)
    @test test_round_trip(Transit.TSet(Any[1, true, 1.0]), verbose)
    @test test_round_trip(Transit.TSet(Any[Transit.TSet([1,2]), Transit.TSet([2,3])]), verbose)
end

# Several values written to one stream read back one at a time.
let buf = IOBuffer()
    Transit.write(buf, [1, :aaaa])
    Transit.write(buf, :aaaa)
    Transit.write(buf, Dict("a" => 1), true)
    @test collect(Transit.eachvalue(IOBuffer(take!(buf)))) == [[1, :aaaa], :aaaa, Dict("a" => 1)]
end
end
