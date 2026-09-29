struct Tag
    rep::String
end

struct TaggedValue
    tag::String
    value::Any

    TaggedValue(tag, value) = new(string(tag), value)
end

function Base.:(==)(tv::TaggedValue, other::TaggedValue)
    tv.value == other.value && tv.tag == other.tag
end

const hashttaggedvalue_seed = UInt === UInt64 ? 0x8ee14727cfcae1ce : 0x1f487ece

function Base.hash(tv::TaggedValue, h::UInt)
    h = hash(hashttaggedvalue_seed, h)
    h ⊻= hash(tv.tag)
    h ⊻= hash(tv.value)
    return h
end

function Base.string(tv::TaggedValue)
    "$(tv.tag): $(tv.value)"
end
