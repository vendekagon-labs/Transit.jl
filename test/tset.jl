module TestTSet

using Test
using Transit


a = Transit.TSet([1,2])
a1 = Transit.TSet([1,2])

b = Transit.TSet([3,4])
b1 = Transit.TSet([4,3])

c = Transit.TSet(Any[a, b])
c1 = Transit.TSet(Any[a,b])

s0 = Transit.TSet([Transit.TSymbol("aaa"), Transit.TSymbol("bbb"),  Transit.TSymbol("ccc")])
s1 = Transit.TSet([Transit.TSymbol("aaa"), Transit.TSymbol("bbb"),  Transit.TSymbol("ccc")])

s2 = Transit.TSet([Transit.TSymbol("aaa"), Transit.TSymbol("ccc"),  Transit.TSymbol("bbb")])
s3 = Transit.TSet([Transit.TSymbol("ccc"), Transit.TSymbol("aaa"),  Transit.TSymbol("bbb")])

@test s0 == s0
@test s0 == s1
@test s1 == s2
@test s2 == s1
@test s3 == s2
@test s3 == s3

@test a == a
@test a == a1
@test b == b
@test b == b1
@test a != b
@test b != a

@test c == c
@test c == c1

# 1 == true in Julia, but a TSet keeps them apart.
mixed = Transit.TSet(Any[1, true])
@test length(mixed) == 2
@test 1 in mixed && true in mixed
@test !(2 in mixed)
@test hash(a) == hash(a1)
@test isempty(Transit.TSet())
@test sort(collect(b)) == [3, 4]
@test repr(Transit.TSet([1])) == "TSet(1)"

end
