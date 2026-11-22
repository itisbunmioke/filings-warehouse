-- 1. How common are revisions? Facts with more than one version, among facts reported at least twice.
WITH reported AS (
    SELECT cik, tag, period_end, qtrs, uom, COUNT(*) AS times_reported
    FROM FIN.ANALYTICS_STAGING.INT_REPORTED_FACTS GROUP BY 1, 2, 3, 4, 5
), versioned AS (
    SELECT cik, tag, period_end, qtrs, uom, MAX(version_number) AS versions
    FROM FIN.ANALYTICS_MARTS.FCT_FACT_VERSIONS GROUP BY 1, 2, 3, 4, 5
)
SELECT COUNT(*)                                             AS facts_reported_more_than_once,
       COUNT_IF(v.versions > 1)                             AS facts_revised,
       ROUND(100 * COUNT_IF(v.versions > 1) / COUNT(*), 2)  AS percent_revised
FROM reported r JOIN versioned v USING (cik, tag, period_end, qtrs, uom)
WHERE r.times_reported > 1;

-- 2. Which concepts get revised most, and by how much (median size of change)?
SELECT tag, COUNT(*) AS revisions, ROUND(100 * MEDIAN(ABS(relative_change)), 2) AS median_percent_change
FROM FIN.ANALYTICS_MARTS.FCT_REVISIONS
WHERE uom = 'USD' AND old_value <> 0
GROUP BY tag HAVING COUNT(*) >= 200
ORDER BY revisions DESC LIMIT 15;

-- 3. Look-ahead bias, measured: full-year 2024 revenue as known in mid-2025 against as known now.
WITH then_known AS (
    SELECT cik, value FROM TABLE(FIN.ANALYTICS_MARTS.FACTS_AS_OF('2025-06-30'::timestamp_ntz))
    WHERE tag = 'Revenues' AND period_end = '2024-12-31' AND qtrs = 4 AND uom = 'USD'
), now_known AS (
    SELECT cik, value FROM FIN.ANALYTICS_MARTS.FCT_FACT_VERSIONS
    WHERE tag = 'Revenues' AND period_end = '2024-12-31' AND qtrs = 4 AND uom = 'USD' AND is_latest
)
SELECT c.company_name, t.value AS known_mid_2025, n.value AS known_now,
       ROUND(100 * DIV0(n.value - t.value, ABS(t.value)), 2) AS percent_change
FROM then_known t JOIN now_known n USING (cik) JOIN FIN.ANALYTICS_MARTS.DIM_COMPANY c USING (cik)
WHERE n.value <> t.value
ORDER BY ABS(percent_change) DESC LIMIT 20;