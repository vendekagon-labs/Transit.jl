struct TSymbol
  s::String

  TSymbol(x) = new(string(x))
end

function Base.:(==)(ts::TSymbol, other::TSymbol)
    ts.s == other.s
end

const hashtsymbol_seed = UInt === UInt64 ? 0x8ee11137cfaae3ce : 0x2f28e1ce

function Base.hash(ts::TSymbol, h::UInt)
    h = hash(hashtsymbol_seed, h)
    h ⊻= hash(ts.s)
    return h
end

function Base.string(ts::TSymbol)
    ts.s
end
