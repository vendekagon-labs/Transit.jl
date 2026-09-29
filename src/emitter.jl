mutable struct Emitter
  io::IO
  cache::Cache
  verbose::Bool
  counts::Vector{Int}   # elements written so far in each open array/map
  inmap::Vector{Bool}   # whether each open container is a JSON object
end

function make_emitter(io, verbose::Bool)
  let cache = verbose ? NoopCache() : RollingCache()
    Emitter(io, cache, verbose, Int[], Bool[])
  end
end

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

function emit_tag(e::Emitter, x::AbstractString)
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
