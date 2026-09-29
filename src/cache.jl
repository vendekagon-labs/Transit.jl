abstract type Cache end

# Do nothing cache used in verbose mode.
struct NoopCache <: Cache
end

function write!(rc::NoopCache, name::AbstractString)
    name
end

# Real caching. Readers and writers must agree on cache codes, so this
# follows the transit spec (and transit-java): codes are assigned in order
# from "^0", and once CACHE_SIZE entries are in use the cache starts over.
mutable struct RollingCache <: Cache
    key_to_value::Dict{String,String}
    value_to_key::Dict{String,String}
    index::Int

    RollingCache() = new(Dict{String,String}(), Dict{String,String}(), 0)
end

const FIRST_ORD = 48
const LAST_ORD  = 91
const CACHE_CODE_DIGITS = 44;
const CACHE_SIZE = CACHE_CODE_DIGITS * CACHE_CODE_DIGITS;
const MIN_SIZE_CACHEABLE = 4

# Reading: the value a cache code stands for.
function cache_read(rc::RollingCache, key::AbstractString)
    v = get(rc.key_to_value, key, nothing)
    v === nothing && throw(ArgumentError("Unknown cache code: $key"))
    v
end

# Reading: remember a cacheable value that was sent in full.
function cache_add!(rc::RollingCache, name::AbstractString)
    if iscachefull(rc)
        clear!(rc)
    end

    key = encode_key(rc.index)
    rc.index += 1
    rc.key_to_value[key] = name
    rc.value_to_key[name] = key

    name
end

# Writing: returns the name the first time and the code after that.
function write!(rc::RollingCache, name::AbstractString)
    key = get(rc.value_to_key, name, nothing)
    key === nothing || return key
    cache_add!(rc, name)
end

function iscachefull(rc::RollingCache)
    rc.index >= CACHE_SIZE
end

function clear!(rc::RollingCache)
    empty!(rc.key_to_value)
    empty!(rc.value_to_key)
    rc.index = 0
end

function iscachekey(str::AbstractString)
    startswith(str, SUB) && str != MAP_AS_ARRAY
end

function iscacheable(str::AbstractString, key=false)
    length(str) >= MIN_SIZE_CACHEABLE && (key || multi_startswith(str, "~#", "~\$", "~:"))
end

function encode_key(i::Integer)
    let hi = div(i, CACHE_CODE_DIGITS),
        lo = i % CACHE_CODE_DIGITS,
        ch = Char(lo+FIRST_ORD)
        if hi == 0
            "^$ch"
        else
            ch1 = Char(hi+FIRST_ORD)
            "^$ch1$ch"
        end
    end
end
