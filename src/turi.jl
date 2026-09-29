struct TURI
    value::String

    TURI(x) = new(string(x))
end

function Base.:(==)(u1::TURI, u2::TURI)
    (u1.value == u2.value)
end

const hashturi_seed = UInt === UInt64 ? 0x3ce1a5e7cfcae1ce : 0x3ce1a5e7

function Base.hash(u::TURI, h::UInt)
    h = hash(hashturi_seed, h)
    h ⊻= hash(u.value)
    return h
end

function Base.string(turi::TURI)
    turi.value
end
