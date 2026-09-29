function multi_startswith(str::AbstractString, pats...)
    any(pat -> startswith(str, pat), pats)
end

function tolist(a::AbstractArray)
  l = nil()
  for item in Iterators.reverse(a)
    l = cons(item, l)
  end
  l
end

const UNIX_EPOCH = DateTime(1970)

const RFC3339 = r"^(\d{4}-\d\d-\d\d)[Tt ](\d\d:\d\d:\d\d)(?:\.(\d+))?([Zz]|[+-]\d\d:\d\d)?$"

# Parses an RFC 3339 date/time into a DateTime in UTC (DateTime has no time
# zone; transit dates are points in time, which Transit.jl keeps as UTC).
# Precision beyond milliseconds is dropped.
function parsedatetime(s::AbstractString)
    m = match(RFC3339, s)
    m === nothing && throw(ArgumentError("Don't know how to parse date/time: $s"))
    date, time, frac, offset = m.captures
    dt = DateTime(string(date, "T", time), dateformat"yyyy-mm-ddTHH:MM:SS")
    if frac !== nothing
        dt += Millisecond(Base.parse(Int, rpad(first(frac, 3), 3, '0')))
    end
    if offset !== nothing && offset != "Z" && offset != "z"
        minutes = 60 * Base.parse(Int, offset[2:3]) + Base.parse(Int, offset[5:6])
        dt -= Minute(offset[1] == '-' ? -minutes : minutes)
    end
    dt
end

function millis_to_datetime(ms::Integer)
    UNIX_EPOCH + Millisecond(ms)
end

function millis_to_datetime(ms::AbstractString)
    millis_to_datetime(Base.parse(Int64, ms))
end

function datetime_to_millis(x::DateTime)
    Dates.value(x - UNIX_EPOCH)
end

function format_datetime(x::DateTime)
    Dates.format(x, dateformat"yyyy-mm-ddTHH:MM:SS.sss") * "Z"
end
