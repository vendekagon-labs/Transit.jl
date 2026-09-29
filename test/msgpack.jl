# The msgpack reader and writer, checked against an independent msgpack
# implementation (MsgPack.jl, a test-only dependency).
module TestMsgPack

using Test
using Dates
import MsgPack
import Transit
using DataStructures: OrderedDict, list

mp(x) = Transit.to_transit(x, :msgpack)
rt(x) = Transit.parse(mp(x); format=:msgpack)

# Every size class of int, string, array and map header.
ints = Any[0, 1, 127, 128, 255, 256, 65535, 65536, typemax(UInt32), Int64(typemax(UInt32)) + 1,
           typemax(Int64), -1, -32, -33, -128, -129, -32768, -32769, typemin(Int32),
           Int64(typemin(Int32)) - 1, typemin(Int64)]
strings = Any["", "a", "x"^31, "x"^32, "x"^255, "x"^256, "x"^65535, "x"^65536, "é\U0001f600"]
others = Any[1.5, -0.0, 6.626e-34, true, false, nothing]

for v in vcat(ints, strings, others)
    # MsgPack.jl reads what we write ...
    @test isequal(MsgPack.unpack(mp(Any[v])), Any[v])
    # ... and we read what MsgPack.jl writes.
    @test isequal(Transit.parse(MsgPack.pack(Any[v]); format=:msgpack), Any[v])
    @test isequal(rt(v), v)
end

for n in (0, 15, 16, 65535, 65536)
    a = collect(1:n)
    @test MsgPack.unpack(mp(a)) == a
    @test rt(a) == a
    d = Dict("k$i" => i for i in 1:n)
    @test rt(d) == d
end

@test Transit.parse(MsgPack.pack(Float32(1.5)); format=:msgpack) === 1.5

# Map entries are read in order: the cache codes depend on it.
@test Transit.parse(MsgPack.pack(Any[OrderedDict("~:abcd" => 1, "~:efgh" => 2), OrderedDict("^1" => 3, "^0" => 4)]);
                    format=:msgpack) == Any[Dict(:abcd => 1, :efgh => 2), Dict(:efgh => 3, :abcd => 4)]

# The representations transit-java uses for msgpack.
@test mp(DateTime(2000, 1, 1, 12)) == MsgPack.pack(Any["~#'", Any["~#m", 946728000000]])
@test mp(Base.UUID("5a2cbea3-e8c6-428b-b525-21239370dd55")) ==
    MsgPack.pack(Any["~#'", Any["~#u", Any[6497777973583037067, -5393868542025081515]]])
@test mp(Dict(:a => 1)) == MsgPack.pack(OrderedDict("~:a" => 1))
@test Transit.parse(MsgPack.pack(OrderedDict(1 => "one", 2 => "two")); format=:msgpack) ==
    Dict{Any,Any}(1 => "one", 2 => "two")
@test rt(Dict(DateTime(2000) => 1, Base.UUID(1) => 2)) == Dict(DateTime(2000) => 1, Base.UUID(1) => 2)
@test rt(Any[typemax(Int64), Int128(typemax(Int64)) + 1, big(2)^100]) ==
    Any[typemax(Int64), Int128(typemax(Int64)) + 1, big(2)^100]
@test rt(list(1, 2)) == list(1, 2)
@test rt(Transit.TSet(Any[1, true])) == Transit.TSet(Any[1, true])
@test rt(Dict([1] => 2)) == Dict([1] => 2)
@test rt(Any[NaN, Inf, -Inf])[2:3] == [Inf, -Inf]

# Things transit writers don't produce are still read sensibly.
@test Transit.parse(UInt8[0x91, 0xc4, 0x02, 0x01, 0x02]; format=:msgpack) == Any[UInt8[1, 2]]
@test Transit.parse(UInt8[0x91, 0xcf, fill(0xff, 8)...]; format=:msgpack) == Any[typemax(UInt64)]

@test_throws ArgumentError Transit.parse(UInt8[0xd4, 0x01, 0x00]; format=:msgpack)  # ext type
@test_throws ArgumentError Transit.parse(UInt8[0x92, 0x01]; format=:msgpack)        # truncated
@test_throws ArgumentError Transit.to_transit(1, :yaml)
@test_throws ArgumentError Transit.parse(IOBuffer("[1]"); format=:yaml)

end
