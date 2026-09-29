function write(io::IO, x::Any, verbose=false)
    e = Encoder(io, verbose)
    encode_top_level(e, x)
end

function to_transit(x::Any, verbose=false)
    let buf = IOBuffer()
        write(buf, x, verbose)
        String(take!(buf))
    end
end
