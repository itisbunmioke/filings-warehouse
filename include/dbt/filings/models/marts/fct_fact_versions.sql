{{ config(
    post_hook="
      create or replace function {{ this.database }}.{{ this.schema }}.facts_as_of(as_of timestamp_ntz)
      returns table (cik int, tag string, period_end date, qtrs int, uom string, value number(28,4),
                     known_from timestamp_ntz, filing_id string, form string, version_number int)
      as 'select cik, tag, period_end, qtrs, uom, value, known_from, filing_id, form, version_number
          from {{ this }} where known_from <= as_of and as_of < known_to'
    "
) }}
with reports as (
    -- every time a fact was reported, with the value reported just before it
    select
        *,
        {{ dbt_utils.generate_surrogate_key(['cik', 'tag', 'period_end', 'qtrs', 'uom']) }} as fact_key,
        lag(value) over (
            partition by cik, tag, period_end, qtrs, uom order by accepted_at, filing_id
        ) as previous_value
    from {{ ref('int_reported_facts') }}
),
changes as (
    -- keep the first report of a fact, and every report whose value differs from the one before
    select * from reports
    where previous_value is null or previous_value <> value
),
versions as (
    select
        *,
        row_number() over (partition by fact_key order by accepted_at, filing_id) as version_number,
        lead(accepted_at) over (partition by fact_key order by accepted_at, filing_id) as next_known_from
    from changes
)
select
    fact_key,
    cik,
    tag,
    period_end,                                             -- valid time: the period the number describes
    qtrs,
    uom,
    value,
    previous_value,
    version_number,
    accepted_at                                             as known_from,   -- knowledge time starts
    coalesce(next_known_from, '9999-12-31'::timestamp_ntz)  as known_to,     -- knowledge time ends (exclusive)
    next_known_from is null                                 as is_latest,
    filing_id,
    form,
    is_amendment
from versions