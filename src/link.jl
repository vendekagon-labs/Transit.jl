struct Link
    href::TURI
    rel::String
    name::Union{String,Nothing}
    prompt::Union{String,Nothing}
    render::Union{String,Nothing}
end

Link(href, rel; name=nothing, prompt=nothing, render=nothing) =
    Link(href isa TURI ? href : TURI(href), rel, name, prompt, render)

# A link's transit representation is a map with string keys.
function link_from_map(m::AbstractDict)
    get_string(k) = (v = get(m, k, nothing); v === nothing ? nothing : string(v))
    Link(m["href"], string(m["rel"]);
         name=get_string("name"), prompt=get_string("prompt"), render=get_string("render"))
end

function link_to_map(l::Link)
    m = Dict{String,Any}("href" => l.href, "rel" => l.rel)
    for (k, v) in (("name", l.name), ("prompt", l.prompt), ("render", l.render))
        v === nothing || (m[k] = v)
    end
    m
end
