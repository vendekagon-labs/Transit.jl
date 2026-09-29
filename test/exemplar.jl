module TestExemplar

using Test
using Dates
using Printf
using DataStructures: cons, list

import Transit
import Transit.TSymbol
import Transit.TSet
import Transit.TaggedValue


function range_centered_on(n)
  range_centered_on(n, 5)
end

function range_centered_on(n, m)
  (n-m):(m+n)
end

function array_of_symbols(n, m)
  syms = map(x -> Symbol(@sprintf("key%04d", x)), 0:(n-1))
  collect(Iterators.take(Iterators.cycle(syms), m))
end

function dict_of_size(n)
  m = Dict{Any,Any}()
  for i in 0:(n-1)
      m[Symbol(@sprintf("key%04d", i))] = i
  end
  m
end

function list_of(a)
  list(a...)
end

function dict_of(a...)
  keys = a[1:2:length(a)]
  vals = a[2:2:length(a)]

  result = Dict{Any,Any}()

  for i in 1:length(keys)
    result[keys[i]] = vals[i]
  end

  result
end

function nested_dict(n)
  Dict{Any,Any}(:f => dict_of_size(n), :s => dict_of_size(n))
end

function nested_dict_exemplar(n)
    Exemplar("map_$(n)_nested", "Map of two nested $n maps", nested_dict(n))
end
 
map_simple = Dict{Any,Any}(:a => 1, :b => 2, :c => 3)

map_mixed = Dict{Any,Any}(:a => 1, :b => "a string", :c => true)

map_nested = Dict{Any,Any}(:simple => map_simple, :mixed => map_mixed)

vector_simple  = Any[1, 2, 3]

vector_mixed  = Any[0, 1, 2.0, true, false, "five", :six, TSymbol(:seven), "~eight", nothing]

vector_nested = Any[vector_simple, vector_mixed]

small_strings  = ["", "a", "ab", "abc", "abcd", "abcde", "abcdef"]

powers_two =
[1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384,
   32768, 65536, 131072, 262144, 524288, 1048576, 2097152, 4194304,
   8388608, 16777216, 33554432, 67108864, 134217728, 268435456,
   536870912, 1073741824, 2147483648, 4294967296, 8589934592,
   17179869184, 34359738368, 68719476736, 137438953472,
   274877906944, 549755813888, 1099511627776, 2199023255552,
   4398046511104, 8796093022208, 17592186044416, 35184372088832,
   70368744177664, 140737488355328, 281474976710656,
   562949953421312, 1125899906842624, 2251799813685248,
   4503599627370496, 9007199254740992, 18014398509481984,
   36028797018963968, 72057594037927936, 144115188075855872,
   288230376151711744, 576460752303423488, 1152921504606846976,
   2305843009213693952, 4611686018427387904, 9223372036854775808,
   18446744073709551616, 36893488147419103232]


interesting_ints = foldl(vcat, map(x-> collect(range_centered_on(x, 2)), powers_two); init=Any[])

uuids = [Base.UUID( "5a2cbea3-e8c6-428b-b525-21239370dd55"),
         Base.UUID( "d1dc64fa-da79-444b-9fa4-d4412f427289"),
         Base.UUID( "501a978e-3a3e-4060-b3be-1cf2bd4b1a38"),
         Base.UUID( "b3ba141a-a776-48e4-9fae-a28ea8571f58")]

uris = [Transit.TURI("http://example.com"),
        Transit.TURI("ftp://example.com"),
        Transit.TURI("file:///path/to/file.txt"),
        Transit.TURI("http://www.詹姆斯.com/")
]

keywords = [:a, :ab, :abc, :abcd, :abcde, :a1, :b2, :c3, :a_b]

symbols = map(x->TSymbol(x), keywords)

dates =  map(x-> Dates.unix2datetime(x), [-6106017600, 0, 946728000, 1396909037])

struct Exemplar
  file_name::String
  description::String
  value::Any
end

exemplars = [
    Exemplar( "nil", "The nil/null/ain't there value", nothing),
    Exemplar( "true", "True", true),
    Exemplar( "false", "False", false),
    Exemplar( "zero", "Zero (integer)", 0),
    Exemplar( "one", "One (integer)", 1),
    Exemplar( "one_string", "A single string", "hello"),
    Exemplar( "one_keyword", "A single keyword", :hello),
    Exemplar( "one_symbol", "A single symbol", TSymbol(:hello)),
    Exemplar( "one_date", "A single date", Dates.unix2datetime(946728000)),
    Exemplar( "vector_simple", "A simple vector", vector_simple),
    Exemplar( "vector_empty", "An empty vector", []),
    Exemplar( "vector_mixed", "A ten element vector with mixed values", vector_mixed),
    Exemplar( "vector_nested", "Two vectors nested inside of an outter vector", vector_nested),

    Exemplar( "small_strings", "A vector of small strings", small_strings),

    Exemplar( "strings_tilde", "A vector of strings starting with ~", 
	      map(x -> "~$x", small_strings)),

    Exemplar( "strings_hash", "A vector of strings starting with #",
	      map(x -> "#$x", small_strings)),

    Exemplar( "strings_hat", "A vector of strings starting with ^",
	      map(x -> "^$x", small_strings)),

    Exemplar( "small_ints", "A vector of eleven small integers", collect(range_centered_on(0))),

    Exemplar( "ints", "vector of ints", collect(0:127)),

    Exemplar( "ints_interesting", "A vector of possibly interesting positive integers",
              interesting_ints),

    Exemplar("ints_interesting_neg",
	     "A vector of possibly interesting negative integers",
	     map(x-> -1 * x, interesting_ints)),

    Exemplar( "doubles_small", "A vector of eleven doubles from -5.0 to 5.0",
      map(x->Float64(x), range_centered_on(0))),

    Exemplar( "doubles_interesting", "A vector of interesting doubles",
      [-3.14159, 3.14159, 4E11, 2.998E8, 6.626E-34]),

    Exemplar( "one_uuid", "A single UUID", first(uuids)),

    Exemplar( "uuids", "A vector of uuids", uuids),


    Exemplar( "one_uri", "A single URI", first(uris)),

    Exemplar( "uris", "A vector of URIs", uris),


    Exemplar(
      "dates_interesting",
      "A vector of interesting dates: 1776-07-04, 1970-01-01, 2000-01-01, 2014-04-07",
      dates),

    Exemplar( "symbols", "A vector of symbols", symbols),
    Exemplar( "keywords", "A vector of keywords", keywords),

    Exemplar( "list_simple", "A simple list", list_of(vector_simple)),
    Exemplar( "list_empty", "An empty list", list()),
    Exemplar( "list_mixed", "A ten element list with mixed values", 
	      list_of(vector_mixed)),

    Exemplar( "list_nested", "Two lists nested inside an outter list",
      list(list_of(vector_simple), list_of(vector_mixed))),

    Exemplar( "set_simple", "A simple set", TSet(vector_simple)),
    Exemplar( "set_empty", "An empty set", TSet()),
    Exemplar( "set_mixed", "A ten element set with mixed values", TSet(vector_mixed)),
    Exemplar( "set_nested", "Two sets nested inside an outter set",
      TSet([TSet(vector_simple), TSet(vector_mixed)])),

    Exemplar( "map_simple", "A simple map", map_simple),
    Exemplar( "map_mixed", "A mixed map", map_mixed),
    Exemplar( "map_nested", "A nested map", map_nested),

    Exemplar( "map_string_keys", "A map with string keys", 
              dict_of("first", 1, "second", 2, "third", 3)),

    Exemplar( "map_numeric_keys", "A map with numeric keys",
	      dict_of(1, "one", 2, "two")),

    Exemplar( "map_vector_keys", "A map with vector keys",
	      dict_of(Any[1,1], "one", Any[2,2], "two")),

    Exemplar( "map_10_items", "10 item map",  dict_of_size(10)),

    nested_dict_exemplar(10),
    nested_dict_exemplar(1935),
    nested_dict_exemplar(1936),
    nested_dict_exemplar(1937),

    Exemplar(
      "maps_two_char_sym_keys",
      "Vector of maps with identical two char symbol keys",
      [dict_of(TSymbol(:aa), 1, TSymbol(:bb), 2),
       dict_of(TSymbol(:aa), 3, TSymbol(:bb), 4),
       dict_of(TSymbol(:aa), 5, TSymbol(:bb), 6)]),

    Exemplar(
      "maps_three_char_sym_keys",
      "Vector of maps with identical three char symbol keys",
      [dict_of(TSymbol(:aaa), 1, TSymbol(:bbb), 2),
       dict_of(TSymbol(:aaa), 3, TSymbol(:bbb), 4),
       dict_of(TSymbol(:aaa), 5, TSymbol(:bbb), 6)]),

    Exemplar(
      "maps_four_char_sym_keys",
      "Vector of maps with identical four char symbol keys",
      [dict_of(TSymbol(:aaaa), 1, TSymbol(:bbbb), 2),
       dict_of(TSymbol(:aaaa), 3, TSymbol(:bbbb), 4),
       dict_of(TSymbol(:aaaa), 5, TSymbol(:bbbb), 6)]),


    Exemplar(
      "maps_two_char_keyword_keys",
      "Vector of maps with identical two char keyword keys",
      [dict_of(:aa, 1, :bb, 2),
       dict_of(:aa, 3, :bb, 4),
       dict_of(:aa, 5, :bb, 6)]),

    Exemplar(
      "maps_three_char_keyword_keys",
      "Vector of maps with identical three char keyword keys",
      [dict_of(:aaa, 1, :bbb, 2),
       dict_of(:aaa, 3, :bbb, 4),
       dict_of(:aaa, 5, :bbb, 6)]),

    Exemplar(
      "maps_four_char_keyword_keys",
      "Vector of maps with identical four char keyword keys",
      [dict_of(:aaaa, 1, :bbbb, 2),
       dict_of(:aaaa, 3, :bbbb, 4),
       dict_of(:aaaa, 5, :bbbb, 6)]),



    Exemplar(
      "maps_two_char_string_keys",
      "Vector of maps with identical two char string keys",
      [dict_of("aa", 1, "bb", 2),
       dict_of("aa", 3, "bb", 4),
       dict_of("aa", 5, "bb", 6)]),

    Exemplar(
      "maps_three_char_string_keys",
      "Vector of maps with identical three char string keys",
      [dict_of("aaa", 1, "bbb", 2),
       dict_of("aaa", 3, "bbb", 4),
       dict_of("aaa", 5, "bbb", 6)]),

    Exemplar(
      "maps_four_char_string_keys",
      "Vector of maps with identical four char string keys",
      [dict_of("aaaa", 1, "bbbb", 2),
       dict_of("aaaa", 3, "bbbb", 4),
       dict_of("aaaa", 5, "bbbb", 6)]),

    Exemplar(
      "maps_unrecognized_keys",
      "Vector of maps with keys with unrecognized encodings",
      [TaggedValue("abcde", :anything),
       TaggedValue("fghij", Symbol("anything-else"))]),

    Exemplar( "map_unrecognized_vals", "Map with vals with unrecognized encodings",
              dict_of(:key, "~Unrecognized")),

    Exemplar(
      "vector_1935_keywords_repeated_twice",
      "Vector of 1935 keywords, repeated twice",
      array_of_symbols(1935,3870)),

    Exemplar(
      "vector_1936_keywords_repeated_twice",
      "Vector of 1936 keywords, repeated twice",
      array_of_symbols(1936,3872)),

    Exemplar(
      "vector_1937_keywords_repeated_twice",
      "Vector of 1937 keywords, repeated twice",
      array_of_symbols(1937,3874)),

    Exemplar(
      "vector_unrecognized_vals",
      "Vector with vals with unrecognized encodings",
      ["~Unrecognized"]),

    Exemplar( "vector_special_numbers", "Vector with special numbers", Any[NaN, Inf, -Inf]),

    Exemplar(
      "cmap_pathological",
      "cmap pathological case discovered in transit-js and transit-cljs",
      Any[Dict(Symbol("any-value") => Dict(Any["this vector makes this a cmap"] => "any value", "any string" => :victim)),
          Dict(:victim => Symbol("any-other-value"))]),

    Exemplar(
      "cmap_null_key",
      "cmap with a null key",
      Dict{Any,Any}(nothing => "null as map key", Any[1,2] => "Array as key to force cmap"))
]

function issame(x::Any, y::Any)
    if x == y
        true
    else
	false
    end
end

function issame(x::TSet, y::TSet)
    if length(x) != length(y)
        return false
    else
        if x != y
            for a in y
                if !in(a, x)
                    println("Failed: $a with type $(typeof(a)) not in $x")
                end
            end
            false
        else
            true
        end
    end
end

function issame(x::AbstractFloat, y::AbstractFloat)
    if isnan(x) && isnan(y)
        true
    else
        x == y
    end
end

function issame(x::Array, y::Array)
  if length(x) != length(y)
    false
  elseif length(x) == 0
    true
  else
    for i in 1:length(x)
        if !issame(x[i], y[i])
            return false
        end
    end
    true
  end
end

function findsame(x, col)
    for item in col
	if issame(x, item)
            return true
        end
    end
    false
end

# transit-format is expected at $TRANSIT_FORMAT_DIR, or checked out next to
# this repo.
function transit_format_dir()
  get(ENV, "TRANSIT_FORMAT_DIR", joinpath(@__DIR__, "..", "..", "transit-format"))
end

exemplar_path(name) = joinpath(transit_format_dir(), "examples", "0.8", "simple", name)

function check(e::Exemplar, how, actual)
  if !issame(e.value, actual)
      println("\n$how: $(e.file_name): Expected:\n$(e.value)\nBut got:\n$actual")
      return false
  end
  true
end

function roundtrip(value, verbose)
  Transit.parse(Transit.to_transit(value, verbose))
end

for e in exemplars
  @testset "$(e.file_name)" begin
    @test check(e, "READ", open(Transit.parse, exemplar_path("$(e.file_name).json")))
    @test check(e, "READ VERBOSE", open(Transit.parse, exemplar_path("$(e.file_name).verbose.json")))
    @test check(e, "ROUNDTRIP", roundtrip(e.value, false))
    @test check(e, "ROUNDTRIP VERBOSE", roundtrip(e.value, true))
  end
end

# Every exemplar in transit-format is covered.
covered = Set(e.file_name for e in exemplars)
available = Set(replace(f, ".edn" => "") for f in readdir(dirname(exemplar_path("x"))) if endswith(f, ".edn"))
@test setdiff(available, covered) == Set()

end
