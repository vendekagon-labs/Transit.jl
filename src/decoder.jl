function decode_special_number(x)
    if x == "NaN"
        NaN
    elseif x == "INF"
        Inf
    elseif x == "-INF"
        -Inf
    else
        throw(ArgumentError("Don't know how to decode special number: $x"))
    end
end

# A uuid is a string, or two signed 64 bit ints (most significant first).
decode_uuid(x::AbstractString) = UUID(x)
decode_uuid(x::AbstractVector) =
    UUID((UInt128(reinterpret(UInt64, Int64(x[1]))) << 64) | reinterpret(UInt64, Int64(x[2])))

mutable struct Decoder
    decoderFunctions::Dict{String,Function}

    Decoder() = new(Dict{String,Function}(
                        "_"  => (x -> nothing),
                        ":"  => (x -> Symbol(x)),
                        "\$" => (x -> TSymbol(x)),
                        "?"  => (x -> x == "t"),
                        "b"  => base64decode,
                        "c"  => first,
                        "i"  => (x -> Base.parse(Int64, x)),
                        "d"  => (x -> Base.parse(Float64, x)),
                        "f"  => (x -> Base.parse(Decimal, x)),
                        "r"  => (x -> TURI(x)),
                        "n"  => (x -> Base.parse(BigInt, x)),
                        "u"  => decode_uuid,
                        "t"  => parsedatetime,
                        "m"  => millis_to_datetime,
                        "z"  => decode_special_number,

                        # tag decoders
                        "'"  => identity,
                        "set" => (x -> TSet(x)),
                        "link" => link_from_map,
                        "list" => tolist,
                        "ratio" => (x -> x[1]//x[2]),
                        "cmap" => (x -> Dict{Any,Any}(x[i] => x[i+1] for i in 1:2:length(x)))
                    ))
end

function getindex(d::Decoder, k::AbstractString)
    d.decoderFunctions[k]
end

function add_decoder(e::Decoder, tag::AbstractString, f::Function)
    e.decoderFunctions[tag] = f
end

function decode(e::Decoder, node::Any, cache::Cache=RollingCache(), as_map_key::Bool=false)
    decode_value(e, node, cache, as_map_key)
end

function decode_value(e::Decoder, node::Any, cache::Cache, as_map_key::Bool=false)
    node
end

function decode_value(e::Decoder, node::AbstractVector, cache::Cache, as_map_key::Bool=false)
    if !isempty(node)
        if node[1] == MAP_AS_ARRAY
            returned_dict = Dict{Any,Any}()
            for i in 2:2:length(node)
                key = decode_value(e, node[i], cache, true)
                value = decode_value(e, node[i+1], cache, as_map_key)
                returned_dict[key] = value
            end
            return returned_dict
        else
            # Each element must be decoded exactly once, in order, to keep
            # the cache in step with the writer.
            decoded = decode_value(e, node[1], cache, as_map_key)
            if isa(decoded, Tag)
                return decode_value(e, decoded, node[2], cache, as_map_key)
            end
            result = Any[decoded]
            for i in 2:length(node)
                push!(result, decode_value(e, node[i], cache, as_map_key))
            end
            return result
        end
    end

    Any[]
end


# Bytes (msgpack bin data) are left as they are.
function decode_value(e::Decoder, node::Vector{UInt8}, cache::Cache, as_map_key::Bool=false)
    node
end

function decode_value(e::Decoder, hash::AbstractDict, cache::Cache, as_map_key::Bool=false)
    decode_map(e, hash, cache, as_map_key)
end

# hash is anything with a length whose iteration gives key => value pairs in
# the order they were read.
function decode_map(e::Decoder, hash, cache::Cache, as_map_key::Bool)
    if length(hash) != 1
        h = Dict{Any,Any}()
        for kv in hash
            key = decode_value(e, kv[1], cache, true)
            val = decode_value(e, kv[2], cache, false)
            h[key] = val
        end
        return h
    else
        for (k,v) in hash
            key = decode_value(e, k, cache, true)
            if isa(key, Tag)
                return decode_value(e, key, v, cache, as_map_key)
            end
            return Dict{Any,Any}(key => decode_value(e, v, cache, false))
        end
    end
end

function decode_value(e::Decoder, s::AbstractString, cache::Cache, as_map_key::Bool=false)
    if iscachekey(s)
        return parse_string(e, cache_read(cache, s))
    end

    if iscacheable(s, as_map_key)
        cache_add!(cache, s)
    end

    parse_string(e, s)
end

function parse_string(e::Decoder, s::AbstractString)
    if !startswith(s, ESC) || length(s) < 2
        s
    elseif startswith(s, TAG)
        Tag(s[3:end])
    elseif multi_startswith(s, ESC_ESC, ESC_SUB, ESC_RES)
        s[2:end]
    else
        i = nextind(s, 1)
        tag = string(s[i])
        rep = s[nextind(s, i):end]
        if haskey(e.decoderFunctions, tag)
            e[tag](rep)
        else
            TaggedValue(tag, rep)
        end
    end
end

function decode_value(e::Decoder, tag::Tag, value, cache::Cache, as_map_key::Bool=false)
    if haskey(e.decoderFunctions, tag.rep)
        e[tag.rep](decode_value(e, value, cache, false))
    else
        TaggedValue(tag.rep, decode_value(e, value, cache, false))
    end
end
