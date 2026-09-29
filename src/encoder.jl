mutable struct Encoder{E<:AbstractEmitter}
    verbose::Bool
    encoder_functions::Dict{DataType,Function}
    encodes_to_string::Dict{DataType,Bool}
    emitter::E
end

# format is :json, :json_verbose or :msgpack; verbose=true means :json_verbose.
function Encoder(io, format::Symbol)
    emitter = make_emitter(io, format)
    Encoder(format === :json_verbose, Dict{DataType,Function}(), Dict{DataType,Bool}(), emitter)
end

Encoder(io, verbose::Bool=false) = Encoder(io, verbose ? :json_verbose : :json)

# Registers f(encoder, x, askey) to encode values of type t. encodes_to_string
# says whether f writes a string, which lets values of type t be map keys
# without resorting to a cmap.
function add_encoder(e::Encoder, t::DataType, f::Function, encodes_to_string::Bool)
    e.encoder_functions[t] = f
    e.encodes_to_string[t] = encodes_to_string
end

function encode(e::Encoder, x::Any, askey=false)
    f = get(e.encoder_functions, typeof(x), nothing)
    if f === nothing
        encode_value(e, x, askey)
    else
        f(e, x, askey)
    end
end

# Whether x is written as a string, taking registered encoders into account.
function stringable(e::Encoder, x::Any)
    get(() -> encodes_to_string(e, x), e.encodes_to_string, typeof(x))
end

function encode_top_level(e::Encoder, x::Any)
    if stringable(e, x)
        encode_quoted(e, x)
    else
        encode(e, x, false)
    end
end

function encode_quoted(e::Encoder, x::Any)
    emit_tagged_start(e.emitter, QUOTE)
    encode(e, x, false)
    emit_tagged_end(e.emitter)
end

function encode_value(e::Encoder, s::AbstractString, askey::Bool)
    if multi_startswith(s, ESC, SUB, RES)
        emit(e.emitter, "~$s", askey)
    else
        emit(e.emitter, s, askey)
    end
end

function encode_value(e::Encoder, s::Symbol, askey::Bool)
    emit(e.emitter, "~:$s", true)
end

function encode_value(e::Encoder, ts::TSymbol, askey::Bool)
    emit(e.emitter, "~\$$(ts.s)", true)
end

function encode_value(e::Encoder, b::Bool, askey::Bool)
    if askey
        emit(e.emitter, b ? "~?t" : "~?f", askey)
    else
        emit(e.emitter, b)
    end
end

function encode_value(e::Encoder, x::AbstractChar, askey::Bool)
    emit(e.emitter, "~c$x", askey)
end

function encode_value(e::Encoder, u::TURI, askey::Bool)
    s = u.value
    emit(e.emitter, "~r$s", askey)
end

function encode_value(e::Encoder, u::UUID, askey::Bool)
    if askey || prefer_strings(e.emitter)
        s = string(u)
        emit(e.emitter, "~u$s", askey)
    else
        # two signed 64 bit ints, most significant first
        n = u.value
        encode_tagged_enumerable(e, "u", (reinterpret(Int64, UInt64(n >> 64)),
                                          reinterpret(Int64, UInt64(n & typemax(UInt64)))), 2)
    end
end

function encode_value(e::Encoder, x::Nothing, askey::Bool)
    emit_null(e.emitter, askey)
end

function encode_value(e::Encoder, i::Integer, askey::Bool)
    min_int, max_int = int_range(e.emitter)
    if i > MAX_INT64 || i < MIN_INT64
        emit(e.emitter, "~n$i", askey)
    elseif askey
        emit(e.emitter, "~i$i", askey)
    elseif min_int <= i <= max_int
        emit(e.emitter, i)
    else
        emit(e.emitter, "~i$i", askey)
    end
end

function encode_value(e::Encoder, x::BigInt, askey::Bool)
    let s = string(x)
      emit(e.emitter, "~n$s", askey)
    end
end

function encode_special_float(emitter::AbstractEmitter, x::AbstractFloat, askey::Bool)
    if isnan(x)
        emit(emitter, "~zNaN", askey)
    elseif x == Inf
        emit(emitter, "~zINF", askey)
    elseif x == -Inf
        emit(emitter, "~z-INF", askey)
    else
        return false
    end
    return true
end

function encode_value(e::Encoder, x::Decimal, askey::Bool)
    let s = string(x)
        emit(e.emitter, "~f$s", askey)
    end
end

function encode_value(e::Encoder, x::BigFloat, askey::Bool)
    if !encode_special_float(e.emitter, x, askey)
        let s = string(x)
            emit(e.emitter, "~f$s", askey)
        end
    end
end

function encode_value(e::Encoder, x::AbstractFloat, askey::Bool)
    if !encode_special_float(e.emitter, x, askey)
        if askey
             emit(e.emitter, "~d$x", askey)
         else
             emit_float(e.emitter, x)
         end
    end
end

function encode_tagged_enumerable(e::Encoder, tag::AbstractString, iter, size::Integer)
    emit_tagged_start(e.emitter, tag)
    emit_array_start(e.emitter, size)
    for x in iter
        encode(e, x, false)
    end
    emit_array_end(e.emitter)
    emit_tagged_end(e.emitter)
end

function encode_value(e::Encoder, a::AbstractArray, askey::Bool)
    emit_array_start(e.emitter, length(a))
    for x in a
        encode(e, x, false)
    end
    emit_array_end(e.emitter)
end

function encodes_to_string(e::Encoder, x::AbstractArray)
    false
end

# Bytes
function encode_value(e::Encoder, x::AbstractVector{<:Union{UInt8,Int8}}, askey::Bool)
    encoded = base64encode(x)
    emit(e.emitter, "~b$encoded", askey)
end

function encodes_to_string(e::Encoder, x::AbstractVector{<:Union{UInt8,Int8}})
    true
end

function encode_value(e::Encoder, r::Rational, askey::Bool)
    encode_tagged_enumerable(e, "ratio", (numerator(r), denominator(r)), 2)
end

function encodes_to_string(e::Encoder, x::Rational)
    false
end

function encode_value(e::Encoder, x::DateTime, askey::Bool)
    if e.verbose
        emit(e.emitter, "~t$(format_datetime(x))", askey)
    elseif askey || prefer_strings(e.emitter)
        emit(e.emitter, "~m$(datetime_to_millis(x))", askey)
    else
        emit_tagged_start(e.emitter, "m")
        emit(e.emitter, datetime_to_millis(x))
        emit_tagged_end(e.emitter)
    end
end

function encode_value(e::Encoder, x::Date, askey::Bool)
    encode_value(e, DateTime(x), askey)
end

function encode_value(e::Encoder, x::Tuple, askey::Bool)
    encode_tagged_enumerable(e, "list", x, length(x))
end

function encodes_to_string(e::Encoder, x::Tuple)
    false
end

function encode_value(e::Encoder, x::Cons, askey::Bool)
    encode_tagged_enumerable(e, "list", x, length(x))
end

function encodes_to_string(e::Encoder, x::Cons)
    false
end

function encode_value(e::Encoder, x::Nil, askey::Bool)
    encode_tagged_enumerable(e, "list", (), 0)
end

function encodes_to_string(e::Encoder, x::Nil)
    false
end

function encode_value(e::Encoder, x::AbstractSet, askey::Bool)
    encode_tagged_enumerable(e, "set", x, length(x))
end

function encode_value(e::Encoder, x::TSet, askey::Bool)
    encode_tagged_enumerable(e, "set", x, length(x))
end

function encodes_to_string(e::Encoder, x::AbstractSet)
    false
end

function encodes_to_string(e::Encoder, x::TSet)
    false
end

function encode_value(e::Encoder, x::Link, askey::Bool)
    emit_tagged_start(e.emitter, "link")
    encode(e, link_to_map(x), false)
    emit_tagged_end(e.emitter)
end

function encodes_to_string(e::Encoder, x::Link)
    false
end

# A tagged value with a one character tag and a string rep (as read from an
# unrecognized "~x..." string) is written back as a string.
function scalar_tagged_value(x::TaggedValue)
    length(x.tag) == 1 && x.value isa AbstractString
end

function encode_value(e::Encoder, x::TaggedValue, askey::Bool)
    if scalar_tagged_value(x)
        emit(e.emitter, "~$(x.tag)$(x.value)", askey)
    else
        emit_tagged_start(e.emitter, x.tag)
        encode(e, x.value, false)
        emit_tagged_end(e.emitter)
    end
end

function encodes_to_string(e::Encoder, x::TaggedValue)
    scalar_tagged_value(x)
end

function has_stringable_keys(e::Encoder, x::AbstractDict)
    all(k -> stringable(e, k), keys(x))
end

function encode_map(e::Encoder, x::AbstractDict)
    emit_array_start(e.emitter, 2 * length(x) + 1)
    emit(e.emitter, MAP_AS_ARRAY, false)

    for (k, v) in x
        encode(e, k, true)
        encode(e, v, false)
    end

    emit_array_end(e.emitter)
end

function encode_cmap(e::Encoder, x::AbstractDict)
    emit_tagged_start(e.emitter, "cmap")
    emit_array_start(e.emitter, 2 * length(x))
    for (k, v) in x
        encode(e, k, false)
        encode(e, v, false)
    end
    emit_array_end(e.emitter)
    emit_tagged_end(e.emitter)
end

# A map as a JSON object (json-verbose) or msgpack map.
function encode_native_map(e::Encoder, x::AbstractDict)
    emit_map_start(e.emitter, length(x))
    for (k, v) in x
        encode(e, k, true)
        encode(e, v, false)
    end
    emit_map_end(e.emitter)
end

function encode_value(e::Encoder, x::AbstractDict, askey::Bool)
    if !has_stringable_keys(e, x)
        encode_cmap(e, x)
    elseif native_maps(e.emitter)
        encode_native_map(e, x)
    else
        encode_map(e, x)
    end
end

function encodes_to_string(e::Encoder, x::AbstractDict)
    false
end

# Default encoder raises exception.
function encode_value(e::Encoder, x::Any, askey::Bool)
    throw(ArgumentError("Don't know how to encode: $x of type $(typeof(x))."))
end

# Default is to claim we do encode to string.
function encodes_to_string(e::Encoder, x::Any)
    true
end
