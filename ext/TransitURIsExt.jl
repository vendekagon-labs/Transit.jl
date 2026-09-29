module TransitURIsExt

import Transit
import URIs

function Transit.encode_value(e::Transit.Encoder, u::URIs.URI, askey::Bool)
    Transit.emit(e.emitter, "~r$(u)", askey)
end

Base.convert(::Type{URIs.URI}, turi::Transit.TURI) = URIs.URI(turi.value)

URIs.URI(turi::Transit.TURI) = URIs.URI(turi.value)

end
