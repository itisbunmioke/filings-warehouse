-- Each version must end exactly when the next one starts: no gap, no overlap.
with ordered as (
    select fact_key, version_number, known_to,
           lead(known_from) over (partition by fact_key order by version_number) as next_known_from
    from {{ ref('fct_fact_versions') }}
)
select * from ordered
where next_known_from is not null and known_to <> next_known_from