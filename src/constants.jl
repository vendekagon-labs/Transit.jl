const JSON_MAX_INT = 2^53 - 1
const JSON_MIN_INT = -JSON_MAX_INT

const MAX_INT64 = typemax(Int64)
const MIN_INT64 = typemin(Int64)

const MAP_AS_ARRAY = "^ "
const ESC = "~"
const SUB = "^"
const RES = "`"
const TAG = "~#"
const QUOTE = "'"

const ESC_ESC = string(ESC, ESC)
const ESC_SUB = string(ESC, SUB)
const ESC_RES = string(ESC, RES)
