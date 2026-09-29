module TestDecoder

using Test
using Dates
import JSON
import Transit
using DataStructures: list

function square_trip(inval)
  Transit.parse(JSON.json(inval))
end


@test square_trip(["~~foo"]) == ["~foo"]
@test square_trip(["~#'","~~foo"]) == "~foo"

@test square_trip(["~#'",1]) == 1
@test square_trip(Dict{Any,Any}("~#'" => 1)) == 1

@test square_trip([1, 2, 3, 4]) == [1, 2, 3, 4]
@test square_trip(["some", "funny", "words"]) == ["some", "funny", "words"]
@test square_trip([1, "and", 2, "we", Dict{Any,Any}("mix"=>"it up")]) ==
                 [1, "and", 2, "we", Dict{Any,Any}("mix"=>"it up")]
@test square_trip(Dict{Any,Any}("a" => 1, "b" => 2)) == Dict{Any,Any}("a" => 1, "b" => 2)
@test square_trip(Dict{Any,Any}("a" => 1)) == Dict{Any,Any}("a" => 1)
@test square_trip(Dict{Any,Any}("a" => Dict{Any,Any}("b" => 2))) ==
                 Dict{Any,Any}("a" => Dict{Any,Any}("b" => 2))
@test square_trip(["~:aaaa", "~:bbbb"]) == [:aaaa, :bbbb]
@test square_trip([Dict{Any,Any}("~:b" => "~i3"), "~i2"]) == [Dict{Any,Any}(:b => 3), 2]
@test square_trip(["~zINF", "~z-INF"]) == [Inf, -Inf]
@test isnan(square_trip(["~zNaN"])[1])
@test square_trip(["~f3.14"])[1] == parse(Transit.Decimal, "3.14")
@test square_trip(["~f-1.1E-1"])[1] == parse(Transit.Decimal, "-0.11")
@test square_trip(["~ude305d54-75b4-431b-adb2-eb6b9e546014"]) == [Base.UUID("de305d54-75b4-431b-adb2-eb6b9e546014")]
# uuids as two signed 64 bit ints, most significant first
@test square_trip(["~#u", [6497777973583037067, -5393868542025081515]]) ==
    Base.UUID("5a2cbea3-e8c6-428b-b525-21239370dd55")
@test square_trip(["~#u", [-3324671396336286645, -6943191349067615607]]) ==
    Base.UUID("d1dc64fa-da79-444b-9fa4-d4412f427289")
@test square_trip(["~'ok"]) == ["ok"]
@test square_trip(["~_"]) == [nothing]
@test square_trip(["~ca", "~cé"]) == ['a', 'é']
@test square_trip(["~bAAH/"]) == [UInt8[0, 1, 255]]
@test square_trip(["~xfoo"]) == [Transit.TaggedValue("x", "foo")]
@test square_trip(["~éfoo"]) == [Transit.TaggedValue("é", "foo")]
@test square_trip(Any["~#list",Any[1,2,"five"]]) == list(1, 2, "five")
@test square_trip(Any["~#set", Any[1, 2, 3]]) == Transit.TSet([1, 2, 3])
@test square_trip(Any["~#cmap",Any[Any[2,2],"two",Any[1,1],"one"]]) == Dict{Any, Any}(Any[2,2] => "two", Any[1,1] => "one")
@test square_trip(Any["~#ratio", Any["~n1", "~n3"]]) == 1//3
@test square_trip(Any["~rhttp://example.com","~rftp://example.com"]) == Any[Transit.TURI("http://example.com"), Transit.TURI("ftp://example.com")]
@test square_trip(["~m-6106017600000","~m0","~m946728000000","~m1396909037000"]) ==
    [DateTime(1776, 7, 4, 12), DateTime(1970), DateTime(2000, 1, 1, 12), DateTime(2014, 4, 7, 22, 17, 17)]
@test square_trip(["~t2000-01-01T12:00:00.000Z", "~t2000-01-01T12:00:00Z",
                   "~t2000-01-01T07:00:00.000-05:00", "~t2000-01-01T13:30:00.123456+01:30"]) ==
    [DateTime(2000, 1, 1, 12), DateTime(2000, 1, 1, 12), DateTime(2000, 1, 1, 12),
     DateTime(2000, 1, 1, 12, 0, 0, 123)]
@test square_trip(Any["~#link", Any["^ ", "href", "~rhttp://x.com", "rel", "self", "name", "n"]]) ==
    Transit.Link("http://x.com", "self"; name="n")
@test_throws ArgumentError square_trip(["^0"])

end
