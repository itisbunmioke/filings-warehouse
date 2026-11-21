-- Every company-wide number from annual and quarterly reports, stamped with when the SEC accepted it.
select
    f.cik,
    n.tag,
    n.period_end,
    n.qtrs,
    n.uom,
    n.value,
    f.accepted_at,
    f.filing_id,
    f.form,
    f.is_amendment
from {{ ref('stg_numbers') }} n
join {{ ref('stg_filings') }} f on f.filing_id = n.filing_id
where n.segments is null and n.coreg is null            -- company-wide figures, not breakdowns
  and f.form in ('10-K', '10-Q', '10-K/A', '10-Q/A')    -- periodic reports and their amendments
  and n.value is not null and n.period_end is not null and f.accepted_at is not null
-- the same number can be tagged under two taxonomy years in one filing: keep one
qualify row_number() over (
    partition by f.filing_id, n.tag, n.period_end, n.qtrs, n.uom order by n.taxonomy desc
) = 1