module TestEncoder

using Test
using Transit
using Dates
import JSON

# Convert the value given to transit and then read
# back in the resulting JSON. Not a round trip, since
# we are just reading back in the raw JSON.
function square_trip(x, verbose=false)
    buf = IOBuffer()
    e = Encoder(buf, verbose)
    encode(e, x, false)
    s = String(take!(buf))
    #println(s)
    JSON.parse(s)
end

@test square_trip(1) == 1
@test square_trip(1.0) == 1.0
@test square_trip(1.5f0) == 1.5
@test square_trip("hello") == "hello"
@test square_trip("~hello") == "~~hello"
@test square_trip("^hello") == "~^hello"
@test square_trip("`hello") == "~`hello"
@test square_trip(true) == true
@test square_trip(false) == false
@test square_trip(2//3) == Any["~#ratio", Any[2, 3]]
@test square_trip([1,2,3]) == [1,2,3]
@test square_trip((1,2,"hello")) == Any["~#list", Any[1,2,"hello"]]
@test square_trip(typemax(Int64)) == "~i$(typemax(Int64))"
@test square_trip(Int128(typemax(Int64)) + 1) == "~n$(Int128(typemax(Int64)) + 1)"
@test square_trip(UInt8[0, 1, 255]) == "~bAAH/"
@test square_trip(DateTime(2000, 1, 1, 12)) == "~m946728000000"
@test square_trip(DateTime(2000, 1, 1, 12), true) == "~t2000-01-01T12:00:00.000Z"
@test square_trip(Transit.TaggedValue("x", "foo")) == "~xfoo"
@test square_trip(Transit.TaggedValue("point", [1, 2])) == Any["~#point", Any[1, 2]]
@test square_trip(Transit.TaggedValue("point", [1, 2]), true) == Dict("~#point" => Any[1, 2])

@test square_trip([:hello, :hello, :hello]) == ["~:hello", "^0", "^0"]
@test square_trip([:aaaa, :bbbb, :aaaa, :bbbb]) == ["~:aaaa", "~:bbbb", "^0", "^1"]

symbols = [Transit.TSymbol("hello"), Transit.TSymbol("hello"), Transit.TSymbol("hello")]

@test square_trip(symbols) == ["~\$hello", "^0", "^0"]
@test square_trip([:aaaa, :bbbb, :aaaa, :bbbb]) == ["~:aaaa", "~:bbbb", "^0", "^1"]

@test square_trip([:aaaa, :bbbb, :aaaa, :bbbb], true) == ["~:aaaa", "~:bbbb", "~:aaaa", "~:bbbb"]

@test square_trip(Dict([("aaa", 11), ("bbb", 22)]), true) == Dict([("aaa", 11), ("bbb", 22)])
@test square_trip(Dict(1 => "one"), true) == Dict("~i1" => "one")
@test square_trip(Dict([1] => "one")) == Any["~#cmap", Any[Any[1], "one"]]

@test Transit.to_transit(1) == "[\"~#'\",1]"
@test Transit.to_transit(1, true) == "{\"~#'\":1}"
@test Transit.to_transit(Transit.TSet([1])) == "[\"~#set\",[1]]"
@test Transit.to_transit(Transit.TSet([1]), true) == "{\"~#set\":[1]}"

# Custom encoders, including as map keys.
struct Point
    x::Int
    y::Int
end

let buf = IOBuffer(), e = Encoder(buf)
    Transit.add_encoder(e, Point, (e, p, askey) -> Transit.emit(e.emitter, "~p$(p.x),$(p.y)", askey), true)
    Transit.encode_top_level(e, Dict(Point(1, 2) => "a"))
    @test String(take!(buf)) == "[\"^ \",\"~p1,2\",\"a\"]"
end

@test_throws ArgumentError square_trip(Point(1, 2))

# URIs.jl URIs are written as transit uris (via the package extension).
import URIs
@test square_trip(URIs.URI("http://x.com/a")) == "~rhttp://x.com/a"
@test convert(URIs.URI, Transit.TURI("http://x.com/a")) == URIs.URI("http://x.com/a")
end
