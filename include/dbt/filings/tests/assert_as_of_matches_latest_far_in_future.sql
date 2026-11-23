-- Asking "as of the far future" must return exactly the latest versions.
select 'as_of' as side, count(*) as n from table({{ ref('fct_fact_versions').database }}.{{ ref('fct_fact_versions').schema }}.facts_as_of('2999-01-01'::timestamp_ntz))
having count(*) <> (select count(*) from {{ ref('fct_fact_versions') }} where is_latest)