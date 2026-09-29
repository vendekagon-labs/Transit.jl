# Emitters write the pieces of a transit value in a particular encoding. The
# JSON emitter (for json and json-verbose) is here; msgpack is in msgpack.jl.
abstract type AbstractEmitter end

mutable struct Emitter <: AbstractEmitter
  io::IO
  cache::Cache
  verbose::Bool
  counts::Vector{Int}   # elements written so far in each open array/map
  inmap::Vector{Bool}   # whether each open container is a JSON object
end

const FORMATS = (:json, :json_verbose, :msgpack)

function check_format(format::Symbol)
  format in FORMATS || throw(ArgumentError("Unknown transit format :$format (expected one of $FORMATS)"))
  format
end

function make_emitter(io, format::Symbol)
  check_format(format)
  if format === :msgpack
    MsgPackEmitter(io)
  else
    let verbose = format === :json_verbose,
        cache = verbose ? NoopCache() : RollingCache()
      Emitter(io, cache, verbose, Int[], Bool[])
    end
  end
end

make_emitter(io, verbose::Bool) = make_emitter(io, verbose ? :json_verbose : :json)

# The range of ints written as numbers rather than "~i" strings.
int_range(::Emitter) = (JSON_MIN_INT, JSON_MAX_INT)
# Whether values like dates and uuids are written as strings rather than as
# tagged values with a non-string representation.
prefer_strings(::Emitter) = true
# Whether maps are written as native maps rather than ["^ ", k, v, ...].
native_maps(e::Emitter) = e.verbose

# Writes the separator due before the next element, if any.
function emit_sep(e::Emitter)
  isempty(e.counts) && return
  n = e.counts[end]
  if n > 0
    print(e.io, e.inmap[end] && isodd(n) ? ':' : ',')
  end
  e.counts[end] = n + 1
end

function emit_raw(e::Emitter, s::AbstractString)
  emit_sep(e)
  print(e.io, s)
end

function emit_tag(e::AbstractEmitter, x::AbstractString)
  emit(e, "~$x", true)
end

function emit(e::Emitter, x::AbstractString, cacheable::Bool)
  let value = iscacheable(x, cacheable) ? write!(e.cache, x) : x
    emit_raw(e, JSON.json(value))
  end
end

function emit(e::Emitter, x::Integer)
  emit_raw(e, string(x))
end

function emit(e::Emitter, x::Bool)
  emit_raw(e, x ? "true" : "false")
end

function emit_float(e::Emitter, x::AbstractFloat)
  emit_raw(e, string(x))
end

function emit_null(e::Emitter, askey::Bool)
  askey ? emit_tag(e, "_") : emit_raw(e, "null")
end

function emit_array_start(e::Emitter, size::Integer=0)
  emit_sep(e)
  print(e.io, "[")
  push!(e.counts, 0)
  push!(e.inmap, false)
end

function emit_array_end(e::Emitter)
  pop!(e.counts)
  pop!(e.inmap)
  print(e.io, "]")
end

function emit_map_start(e::Emitter, size::Integer=0)
  emit_sep(e)
  print(e.io, "{")
  push!(e.counts, 0)
  push!(e.inmap, true)
end

function emit_map_end(e::Emitter)
  pop!(e.counts)
  pop!(e.inmap)
  print(e.io, "}")
end

# A tagged value is ["~#tag", rep], or {"~#tag": rep} in verbose mode;
# the rep is written between these two calls.
function emit_tagged_start(e::Emitter, tag::AbstractString)
  if e.verbose
    emit_map_start(e, 1)
  else
    emit_array_start(e, 2)
  end
  emit_tag(e, "#$tag")
end

function emit_tagged_end(e::Emitter)
  e.verbose ? emit_map_end(e) : emit_array_end(e)
end
