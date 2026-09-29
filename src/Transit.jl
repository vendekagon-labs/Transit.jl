module Transit
  import JSON
  import Base: getindex

  using Base64
  using DataStructures: Cons, Nil, cons, list, nil
  using Dates
  using Decimals: Decimal
  using UUIDs: UUID

  export Encoder, encode, decode

  include("tagged_value.jl")
  include("tsymbol.jl")
  include("tset.jl")
  include("turi.jl")
  include("link.jl")
  include("constants.jl")
  include("cache.jl")
  include("utilities.jl")
  include("decoder.jl")
  include("emitter.jl")
  include("msgpack.jl")
  include("encoder.jl")
  include("writer.jl")
  include("reader.jl")
end
