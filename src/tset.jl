# A set that keeps values of different types apart, even when they compare
# equal: in Julia 1 == true, so a Set can't hold both, but transit sets can.
struct TSet
    dict::Dict{Tuple{Any,DataType},Any}

    TSet() = new(Dict{Tuple{Any,DataType},Any}())
    TSet(itr) = new(Dict{Tuple{Any,DataType},Any}((x, typeof(x)) => x for x in itr))
end

Base.in(x, s::TSet) = haskey(s.dict, (x, typeof(x)))
Base.:(==)(s::TSet, t::TSet) = s.dict == t.dict
Base.length(s::TSet) = length(s.dict)
Base.isempty(s::TSet) = isempty(s.dict)
Base.eltype(::Type{TSet}) = Any
Base.iterate(s::TSet, state...) = iterate(values(s.dict), state...)

function Base.show(io::IO, s::TSet)
    print(io, "TSet(")
    join(io, (repr(a) for a in s), ", ")
    print(io, ")")
end

const hashtset_seed = UInt === UInt64 ? 0x852ada37cfe8e0ce : 0xcfe8e0ce
function Base.hash(s::TSet, h::UInt)
    h = hash(hashtset_seed, h)
    for x in s
        h ⊻= hash(x)
    end
    return h
end
