# Readers and writers in different languages must assign cache codes the
# same way, including when the cache fills up and starts over. Julia to
# Julia roundtrips can't show that, so these check against the payloads
# transit-clj produces.
module TestCache

using Test
import JSON
import MsgPack
import Transit
using DataStructures: OrderedDict
using Transit: RollingCache, CACHE_SIZE, encode_key, write!, cache_add!, cache_read

@test encode_key(0) == "^0"
@test encode_key(43) == "^["
@test encode_key(44) == "^10"
@test encode_key(CACHE_SIZE - 1) == "^[["

let cache = RollingCache()
    for i in 0:CACHE_SIZE-1
        write!(cache, "~:k$i")
    end
    @test write!(cache, "~:k0") == "^0"
    @test write!(cache, "~:new") == "~:new"
    @test write!(cache, "~:new") == "^0"
    @test write!(cache, "~:k0") == "~:k0"
    @test write!(cache, "~:k0") == "^1"
end

@test_throws ArgumentError cache_read(RollingCache(), "^0")

const N = CACHE_SIZE + 1
keyname(i) = Symbol("key" * lpad(i, 4, '0'))

# A map with one more cacheable key than the cache holds, followed by maps
# reusing the last and first keys (in order, so the output is predictable).
wrapping_value() = Any[OrderedDict(keyname(i) => i for i in 0:N-1),
                       Dict(keyname(N-1) => :last),
                       Dict(keyname(0) => :first),
                       Dict(keyname(N-1) => Symbol("last-again"))]

# What transit-clj writes for this value: the last key of the big map is the
# first entry after the cache starts over, so it is "^0", while key0000 has
# been dropped and is written out again.
bigmap = Any["^ "]
for i in 0:N-1
    push!(bigmap, "~:$(keyname(i))", i)
end
const WRAPPING_JSON = JSON.json(Any[bigmap,
                                    Any["^ ", "^0", "~:last"],
                                    Any["^ ", "~:key0000", "~:first"],
                                    Any["^ ", "^0", "~:last-again"]])

expected = Any[Dict{Any,Any}(keyname(i) => i for i in 0:N-1),
               Dict{Any,Any}(keyname(N-1) => :last),
               Dict{Any,Any}(keyname(0) => :first),
               Dict{Any,Any}(keyname(N-1) => Symbol("last-again"))]

@test Transit.parse(WRAPPING_JSON) == expected
@test Transit.to_transit(wrapping_value()) == WRAPPING_JSON

# The same in msgpack, where maps are msgpack maps (built here with MsgPack.jl;
# this matches transit-clj's output byte for byte).
const WRAPPING_MSGPACK = MsgPack.pack(Any[OrderedDict(bigmap[i] => bigmap[i+1] for i in 2:2:length(bigmap)),
                                          OrderedDict("^0" => "~:last"),
                                          OrderedDict("~:key0000" => "~:first"),
                                          OrderedDict("^0" => "~:last-again")])

@test Transit.parse(WRAPPING_MSGPACK; format=:msgpack) == expected
@test Transit.to_transit(wrapping_value(), :msgpack) == WRAPPING_MSGPACK

# The first element of an array is inspected for a tag; it must still only
# be added to the read cache once.
@test Transit.parse("[[\"~:aaaa\",\"~:bbbb\"],\"^1\"]") == Any[Any[:aaaa, :bbbb], :bbbb]

end
