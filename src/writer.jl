"""
    Transit.write(io::IO, x, format::Symbol=:json)
    Transit.write(io::IO, x, verbose::Bool)

Write `x` to `io` as transit. `format` is `:json`, `:json_verbose` or
`:msgpack`; `verbose=true` is the same as `:json_verbose`.
"""
function write(io::IO, x::Any, format::Symbol=:json)
    e = Encoder(io, format)
    encode_top_level(e, x)
end

write(io::IO, x::Any, verbose::Bool) = write(io, x, verbose ? :json_verbose : :json)

"""
    Transit.to_transit(x, format::Symbol=:json)
    Transit.to_transit(x, verbose::Bool)

`x` as transit: a String for the JSON formats, bytes for `:msgpack`.
"""
function to_transit(x::Any, format::Symbol=:json)
    let buf = IOBuffer()
        write(buf, x, format)
        format === :msgpack ? take!(buf) : String(take!(buf))
    end
end

to_transit(x::Any, verbose::Bool) = to_transit(x, verbose ? :json_verbose : :json)
