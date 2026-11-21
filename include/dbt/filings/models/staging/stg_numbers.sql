-- One row per reported number. The source documents an 8-column key and still contains a few duplicates.
select
    adsh                                   as filing_id,
    tag,
    version                                as taxonomy,
    try_to_date(ddate, 'YYYYMMDD')         as period_end,
    try_to_number(qtrs)::int               as qtrs,
    uom,
    segments,
    coreg,
    try_to_decimal(value, 28, 4)           as value,
    source_quarter,
    loaded_at
from {{ source('raw', 'num_raw') }}
qualify row_number() over (
    partition by adsh, tag, version, ddate, qtrs, uom, segments, coreg
    order by loaded_at desc, file_row
) = 1