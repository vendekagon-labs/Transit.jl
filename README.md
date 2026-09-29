# Transit.jl

Transit is a data format and a set of libraries for conveying values between applications written in different languages. This library provides support for marshalling Transit data to/from [Julia](http://julialang.org).

* [Rationale](http://blog.cognitect.com/blog/2014/7/22/transit)
* [Specification](http://github.com/cognitect/transit-format)

This implementation's major.minor version number corresponds to the version of the Transit specification it supports.

All three transit encodings are implemented: JSON, JSON-verbose and
MessagePack. msgpack support is built in, with no extra dependencies.

Transit.jl supports Julia 1.10 and later.

_NOTE: Transit is a work in progress and may evolve based on feedback. As a result, while Transit is a great option for transferring data between applications, it should not yet be used for storing data durably over time. This recommendation will change when the specification is complete._

## Installation

Transit.jl is not in the General registry; add it from GitHub:

```julia
using Pkg
Pkg.add(url="https://github.com/vendekagon-labs/Transit.jl")
```

## Usage

To use Transit in a project, import it:

```julia
import Transit
```

Transit will read or write data using any IO interface in Julia. To write:

```julia
Transit.write(stdout, [123, "hello world", :value, 0, nothing])
# [123,"hello world","~:value",0,null]

Transit.write(stdout, Dict(:a => 1), :json_verbose)  # or true for verbose
# {"~:a":1}

Transit.write(io, [1, 2], :msgpack)

Transit.to_transit([1, 2])            # to a String
Transit.to_transit([1, 2], :msgpack)  # to bytes
```

The format is `:json` (the default), `:json_verbose` or `:msgpack`.

To read:

```julia
iobuf = IOBuffer("[123, \"hello world\", \"~:value\",0,null]")
Transit.parse(iobuf)

# 5-element Array{Any,1}:
#   123             
#   "hello world"
#   :value       
#   0             
#   nothing
```

To read msgpack, pass the format: `Transit.parse(io; format=:msgpack)`.

`Transit.parse` reads a single value (a whole stream or string). To read a
sequence of values as they arrive, e.g. from a pipe or socket, use
`Transit.eachvalue`, which produces each value as soon as it has been read
and stops at the end of the stream:

```julia
for value in Transit.eachvalue(stdin)                     # or format=:msgpack
    Transit.write(stdout, value)
end
```

### Custom types

Register an encoder for a type with `Transit.add_encoder` on an `Encoder`,
and a decoder for a tag with `Transit.add_decoder` on a `Transit.Decoder`,
which `Transit.parse` and `Transit.eachvalue` take as a `decoder` keyword:

```julia
d = Transit.Decoder()
Transit.add_decoder(d, "point", rep -> (rep[1], rep[2]))
Transit.parse("[\"~#point\",[1,2]]"; decoder=d)
# (1, 2)
```

## Default Type Mapping

_NOTE: The type mapping may change in the short term for Transit.jl if any types proves to be a mismatch with typical Julia expectations._


| Semantic Type | write accepts | read produces |
|:--------------|:--------------|:--------------|
| null| nothing | nothing |
| string| AbstractString | String |
| boolean | Bool | Bool |
| integer, signed 64 bit| any signed or unsigned int type | Int64 |
| floating pt decimal| Float16, Float32 or Float64 | Float64 |
| bytes| Vector{UInt8}, Vector{Int8} | Vector{UInt8} |
| keyword | Symbol | Symbol |
| symbol | Transit.TSymbol | Transit.TSymbol |
| arbitrary precision decimal| Decimals.Decimal, BigFloat | Decimals.Decimal|
| arbitrary precision integer| BigInt, or any int outside Int64 | BigInt |
| point in time | DateTime, Date | DateTime (UTC) |
| uuid | UUIDs.UUID | UUIDs.UUID |
| uri | Transit.TURI, URIs.URI (with URIs.jl loaded) | Transit.TURI |
| char | Char | Char |
| special numbers | Inf, NaN| Inf, NaN |
| array | arrays | Vector{Any} |
| map | AbstractDict | Dict{Any,Any} |
| set |  Transit.TSet, AbstractSet | Transit.TSet |
| list | Tuple, DataStructures.Cons | DataStructures.Cons |
| map w/ composite keys |  AbstractDict |  Dict{Any,Any} |
| link | Transit.Link | Transit.Link |
| ratio | Rational | Rational |

Values with tags Transit.jl doesn't know are read as `Transit.TaggedValue`s
and written back out unchanged.

`Transit.TSet` exists because `1 == true` in Julia, so a `Set` can't hold both
while a transit set can.

## Development

Run the tests with:

```sh
julia --project -e 'using Pkg; Pkg.test()'
```

The exemplar tests read the example files from
[transit-format](http://github.com/cognitect/transit-format), which is
expected to be checked out next to Transit.jl, or at `$TRANSIT_FORMAT_DIR`.

transit-format's verify harness drives `bin/roundtrip`. Install the
dependencies once with `julia --project -e 'using Pkg; Pkg.instantiate()'`.


## Copyright and License
Copyright © 2016 Russ Olsen, Ben Kamphaus

This library is a Julia port of the Java and Ruby versions created and maintained by Cognitect, therefore

Copyright © 2014 Cognitect

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

This README file is based on the README from transit-csharp, therefore:

Copyright © 2014 NForza.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
