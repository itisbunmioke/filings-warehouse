# Findings: two quarters loaded (2025 Q1 and 2026 Q1)

Queries: [`include/dbt/filings/analyses/findings.sql`](../include/dbt/filings/analyses/findings.sql), run against the marts.

## 1. How common are revisions?

| Measure | Value |
|---|---:|
| Facts reported more than once | 595,205 |
| Facts whose value changed | 24,370 |
| Share revised | 4.09% |

## 2. Most revised concepts (top 5)

| Concept (XBRL tag) | Revisions | Median change |
|---|---:|---:|
| EarningsPerShareDiluted | 421 | 150.00% |
| EarningsPerShareBasic | 408 | 249.92% |
| OperatingIncomeLoss | 404 | 10.03% |
| IncomeLossFromContinuingOperationsBeforeIncomeTaxesExtraordinaryItemsNoncontrollingInterest | 363 | 8.20% |
| OtherNoncashIncomeExpense | 336 | 63.12% |

## 3. Look-ahead bias: full-year 2024 revenue, as known on 30 June 2025 vs now (top 5 by size of change)

| Company | Known on 30 Jun 2025 (USD) | Known now (USD) | Change |
|---|---:|---:|---:|
| American Bitcoin Corp. | 20,539,000 | 71,537,000 | +248.30% |
| Sow Good Inc. | 31,992,511 | 0 | -100.00% |
| Tiptree Inc. | 2,042,854,000 | 1,520,000 | -99.93% |
| Rythm, Inc. | 9,680,000 | 18,000 | -99.81% |
| Pixelworks, Inc. | 43,206,000 | 690,000 | -98.40% |

The as-of value comes from `facts_as_of('2025-06-30')` and the current value from the latest version in `fct_fact_versions`. Changes this large are not all restatements: some come from a company later reporting a different revenue line under the same tag, or a narrower scope. Checking each against the original filings is the next step before drawing conclusions about any single company.
