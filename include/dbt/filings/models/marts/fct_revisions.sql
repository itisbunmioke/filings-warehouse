-- One row per time the known value of a fact changed.
select
    v.fact_key,
    v.cik,
    v.tag,
    v.period_end,
    v.qtrs,
    v.uom,
    v.previous_value                                            as old_value,
    v.value                                                     as new_value,
    v.value - v.previous_value                                  as change,
    div0(v.value - v.previous_value, abs(v.previous_value))     as relative_change,
    v.known_from                                                as revised_at,
    v.form                                                      as revised_by_form,
    v.is_amendment,
    v.filing_id
from {{ ref('fct_fact_versions') }} v
where v.version_number > 1