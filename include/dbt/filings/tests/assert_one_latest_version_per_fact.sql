-- A test passes when its query returns no rows.
-- Every fact must have exactly one version that is currently known.
select fact_key, count_if(is_latest) as latest_versions
from {{ ref('fct_fact_versions') }}
group by fact_key
having count_if(is_latest) <> 1