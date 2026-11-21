-- The most recently reported name and industry code for each company.
select cik, company_name, sic_code, country
from {{ ref('stg_filings') }}
qualify row_number() over (partition by cik order by accepted_at desc) = 1