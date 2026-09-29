"""
    Transit.parse(io::IO; format=:json, decoder=Decoder())
    Transit.parse(s::AbstractString; format=:json, decoder=Decoder())
    Transit.parse(bytes::AbstractVector{UInt8}; format=:json, decoder=Decoder())

Read one transit value. `format` is `:json`, `:json_verbose` (read the same
way as `:json`) or `:msgpack`.
"""
function parse(io::IO; format::Symbol=:json, decoder::Decoder=Decoder())
    check_format(format)
    decode(decoder, format === :msgpack ? unpack_msgpack(io) : JSON.parse(io))
end

function parse(s::AbstractString; format::Symbol=:json, decoder::Decoder=Decoder())
    check_format(format)
    format === :msgpack && return parse(IOBuffer(s); format=format, decoder=decoder)
    decode(decoder, JSON.parse(s))
end

function parse(bytes::AbstractVector{UInt8}; format::Symbol=:json, decoder::Decoder=Decoder())
    parse(IOBuffer(bytes); format=format, decoder=decoder)
end

# Finds the end of each top level JSON value in a stream as the data
# arrives, so each value can be parsed as soon as it is complete. JSON.parse
# on an IO reads to the end of the stream, which never comes on a pipe.
mutable struct JSONScanner
    io::IO
    buf::Vector{UInt8}
    pos::Int        # next byte to look at
    start::Int      # start of the current value, 0 between values
    depth::Int
    instring::Bool
    escaped::Bool
end

JSONScanner(io::IO) = JSONScanner(io, UInt8[], 1, 0, 0, false, false)

isjsonspace(b::UInt8) = b == UInt8(' ') || b == UInt8('\t') || b == UInt8('\n') || b == UInt8('\r')

# Returns the bytes of the next complete value in the buffer, or nothing.
function scan!(s::JSONScanner)
    buf = s.buf
    pos = s.pos
    while pos <= length(buf)
        b = buf[pos]
        if s.start == 0
            if isjsonspace(b)
                pos += 1
                continue
            end
            s.start = pos
            if b == UInt8('[') || b == UInt8('{')
                s.depth = 1
            elseif b == UInt8('"')
                s.instring = true
            else
                throw(ArgumentError("Expected a JSON array, object or string at byte $pos"))
            end
        elseif s.instring
            if s.escaped
                s.escaped = false
            elseif b == UInt8('\\')
                s.escaped = true
            elseif b == UInt8('"')
                s.instring = false
            end
        elseif b == UInt8('"')
            s.instring = true
        elseif b == UInt8('[') || b == UInt8('{')
            s.depth += 1
        elseif b == UInt8(']') || b == UInt8('}')
            s.depth -= 1
        end
        if s.depth == 0 && !s.instring
            value = buf[s.start:pos]
            deleteat!(buf, 1:pos)
            s.pos = 1
            s.start = 0
            return value
        end
        pos += 1
    end
    if s.start == 0
        empty!(buf)
        pos = 1
    end
    s.pos = pos
    nothing
end

# Returns the bytes of the next top level JSON value, or nothing at the end
# of the stream. Blocks only until enough data for the value has arrived.
function next_value!(s::JSONScanner)
    while true
        value = scan!(s)
        value === nothing || return value
        if eof(s.io)
            s.start == 0 || throw(ArgumentError("Stream ended in the middle of a JSON value"))
            return nothing
        end
        append!(s.buf, readavailable(s.io))
    end
end

struct EachValue
    scanner::JSONScanner
    decoder::Decoder
end

struct EachMsgPackValue
    io::IO
    decoder::Decoder
end

"""
    eachvalue(io::IO; format=:json, decoder=Decoder())

Iterate over the transit values in `io` (a sequence of values, as read from a
pipe or socket), producing each one as soon as it has arrived. Iteration ends
at the end of the stream. `format` is `:json`, `:json_verbose` or `:msgpack`.
"""
function eachvalue(io::IO; format::Symbol=:json, decoder::Decoder=Decoder())
    check_format(format)
    format === :msgpack ? EachMsgPackValue(io, decoder) : EachValue(JSONScanner(io), decoder)
end

Base.IteratorSize(::Type{EachMsgPackValue}) = Base.SizeUnknown()
Base.eltype(::Type{EachMsgPackValue}) = Any

function Base.iterate(it::EachMsgPackValue, state=nothing)
    eof(it.io) && return nothing
    (decode(it.decoder, unpack_msgpack(it.io)), nothing)
end

Base.IteratorSize(::Type{EachValue}) = Base.SizeUnknown()
Base.eltype(::Type{EachValue}) = Any

function Base.iterate(it::EachValue, state=nothing)
    bytes = next_value!(it.scanner)
    bytes === nothing && return nothing
    (decode(it.decoder, JSON.parse(bytes)), nothing)
end
