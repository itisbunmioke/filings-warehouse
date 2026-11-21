-- One row per filing. accepted_at is the knowledge time of everything in it.
select
    adsh                                   as filing_id,
    cik::int                               as cik,
    name                                   as company_name,
    try_to_number(sic)::int                as sic_code,
    countryba                              as country,
    form,
    form like '%/A'                        as is_amendment,
    try_to_date(period, 'YYYYMMDD')        as report_period,
    try_to_number(fy)::int                 as fiscal_year,
    fp                                     as fiscal_period,
    try_to_date(filed, 'YYYYMMDD')         as filed_date,
    try_to_timestamp_ntz(accepted)         as accepted_at,
    source_quarter,
    loaded_at
from {{ source('raw', 'sub_raw') }}
qualify row_number() over (partition by adsh order by loaded_at desc) = 1