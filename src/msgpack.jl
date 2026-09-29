# A small msgpack reader and writer covering what transit needs. Maps are
# read with their entries in the order they were written, which transit's
# cache depends on, and values are written a piece at a time as the encoder
# walks them. (Transit defines its own write, so bytes go out via Base.write.)

## Reading

# A msgpack map as read off the wire, entries in order.
struct WireMap
    pairs::Vector{Pair{Any,Any}}
end

Base.length(m::WireMap) = length(m.pairs)
Base.iterate(m::WireMap, state...) = iterate(m.pairs, state...)

function decode_value(e::Decoder, m::WireMap, cache::Cache, as_map_key::Bool=false)
    decode_map(e, m, cache, as_map_key)
end

function read_exactly(io::IO, n::Integer)
    bytes = Base.read(io, n)
    length(bytes) == n || throw(EOFError())
    bytes
end

read_be(io::IO, ::Type{T}) where {T} = ntoh(Base.read(io, T))

unpack_array(io::IO, n::Integer) = Any[unpack_value(io) for _ in 1:n]

function unpack_map(io::IO, n::Integer)
    pairs = Vector{Pair{Any,Any}}(undef, n)
    for i in 1:n
        k = unpack_value(io)
        pairs[i] = k => unpack_value(io)
    end
    WireMap(pairs)
end

unpack_str(io::IO, n::Integer) = String(read_exactly(io, n))

function unpack_uint64(io::IO)
    u = read_be(io, UInt64)
    u <= typemax(Int64) ? Int64(u) : u
end

# Reads one msgpack value from io.
function unpack_value(io::IO)
    b = Base.read(io, UInt8)
    if b <= 0x7f
        Int64(b)
    elseif b >= 0xe0
        Int64(reinterpret(Int8, b))
    elseif b <= 0x8f
        unpack_map(io, b & 0x0f)
    elseif b <= 0x9f
        unpack_array(io, b & 0x0f)
    elseif b <= 0xbf
        unpack_str(io, b & 0x1f)
    elseif b == 0xc0
        nothing
    elseif b == 0xc2
        false
    elseif b == 0xc3
        true
    elseif b == 0xc4
        read_exactly(io, Base.read(io, UInt8))
    elseif b == 0xc5
        read_exactly(io, read_be(io, UInt16))
    elseif b == 0xc6
        read_exactly(io, read_be(io, UInt32))
    elseif b == 0xca
        Float64(reinterpret(Float32, read_be(io, UInt32)))
    elseif b == 0xcb
        reinterpret(Float64, read_be(io, UInt64))
    elseif b == 0xcc
        Int64(Base.read(io, UInt8))
    elseif b == 0xcd
        Int64(read_be(io, UInt16))
    elseif b == 0xce
        Int64(read_be(io, UInt32))
    elseif b == 0xcf
        unpack_uint64(io)
    elseif b == 0xd0
        Int64(Base.read(io, Int8))
    elseif b == 0xd1
        Int64(read_be(io, Int16))
    elseif b == 0xd2
        Int64(read_be(io, Int32))
    elseif b == 0xd3
        read_be(io, Int64)
    elseif b == 0xd9
        unpack_str(io, Base.read(io, UInt8))
    elseif b == 0xda
        unpack_str(io, read_be(io, UInt16))
    elseif b == 0xdb
        unpack_str(io, read_be(io, UInt32))
    elseif b == 0xdc
        unpack_array(io, read_be(io, UInt16))
    elseif b == 0xdd
        unpack_array(io, read_be(io, UInt32))
    elseif b == 0xde
        unpack_map(io, read_be(io, UInt16))
    elseif b == 0xdf
        unpack_map(io, read_be(io, UInt32))
    elseif b == 0xc1
        throw(ArgumentError("Invalid msgpack data (0xc1)"))
    else
        throw(ArgumentError("msgpack extension types aren't used by transit (type byte 0x$(string(b, base=16)))"))
    end
end

# Reads one msgpack value, with a clear error if the stream ends part way.
function unpack_msgpack(io::IO)
    try
        unpack_value(io)
    catch ex
        ex isa EOFError && throw(ArgumentError("Stream ended in the middle of a msgpack value"))
        rethrow()
    end
end

## Writing

mutable struct MsgPackEmitter <: AbstractEmitter
    io::IO
    cache::Cache
end

MsgPackEmitter(io::IO) = MsgPackEmitter(io, RollingCache())

write_be(io::IO, x) = Base.write(io, hton(x))

function pack_int(io::IO, x::Integer)
    if 0 <= x <= 127
        Base.write(io, UInt8(x))
    elseif -32 <= x < 0
        Base.write(io, reinterpret(UInt8, Int8(x)))
    elseif x >= 0
        if x <= typemax(UInt8)
            Base.write(io, 0xcc, UInt8(x))
        elseif x <= typemax(UInt16)
            Base.write(io, 0xcd); write_be(io, UInt16(x))
        elseif x <= typemax(UInt32)
            Base.write(io, 0xce); write_be(io, UInt32(x))
        else
            Base.write(io, 0xcf); write_be(io, UInt64(x))
        end
    else
        if x >= typemin(Int8)
            Base.write(io, 0xd0, Int8(x))
        elseif x >= typemin(Int16)
            Base.write(io, 0xd1); write_be(io, Int16(x))
        elseif x >= typemin(Int32)
            Base.write(io, 0xd2); write_be(io, Int32(x))
        else
            Base.write(io, 0xd3); write_be(io, Int64(x))
        end
    end
    nothing
end

function pack_header(io::IO, n::Integer, fix::UInt8, fixmax::Integer, c16::UInt8, c32::UInt8)
    if n <= fixmax
        Base.write(io, fix | UInt8(n))
    elseif n <= typemax(UInt16)
        Base.write(io, c16); write_be(io, UInt16(n))
    else
        Base.write(io, c32); write_be(io, UInt32(n))
    end
    nothing
end

function pack_str(io::IO, s::AbstractString)
    n = ncodeunits(s)
    if n <= 31
        Base.write(io, 0xa0 | UInt8(n))
    elseif n <= typemax(UInt8)
        Base.write(io, 0xd9, UInt8(n))
    elseif n <= typemax(UInt16)
        Base.write(io, 0xda); write_be(io, UInt16(n))
    else
        Base.write(io, 0xdb); write_be(io, UInt32(n))
    end
    Base.write(io, s)
    nothing
end

function emit(e::MsgPackEmitter, x::AbstractString, cacheable::Bool)
    pack_str(e.io, iscacheable(x, cacheable) ? write!(e.cache, x) : x)
end

emit(e::MsgPackEmitter, x::Integer) = pack_int(e.io, x)

emit(e::MsgPackEmitter, x::Bool) = (Base.write(e.io, x ? 0xc3 : 0xc2); nothing)

function emit_null(e::MsgPackEmitter, askey::Bool)
    askey ? emit_tag(e, "_") : (Base.write(e.io, 0xc0); nothing)
end

emit_float(e::MsgPackEmitter, x::AbstractFloat) = (Base.write(e.io, 0xcb); write_be(e.io, Float64(x)); nothing)

emit_array_start(e::MsgPackEmitter, size::Integer) = pack_header(e.io, size, 0x90, 15, 0xdc, 0xdd)
emit_array_end(e::MsgPackEmitter) = nothing
emit_map_start(e::MsgPackEmitter, size::Integer) = pack_header(e.io, size, 0x80, 15, 0xde, 0xdf)
emit_map_end(e::MsgPackEmitter) = nothing

function emit_tagged_start(e::MsgPackEmitter, tag::AbstractString)
    emit_array_start(e, 2)
    emit_tag(e, "#$tag")
end

emit_tagged_end(e::MsgPackEmitter) = nothing

int_range(::MsgPackEmitter) = (MIN_INT64, MAX_INT64)
prefer_strings(::MsgPackEmitter) = false
native_maps(::MsgPackEmitter) = true
