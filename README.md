# SEC Filings Warehouse

A bitemporal data warehouse for company financial statements, built on **Airflow, Snowflake and dbt**.

Companies often re-report past periods, and the numbers change. A warehouse that keeps only the latest value quietly rewrites history, so anyone testing a model on 2025 would be using numbers nobody knew in 2025. This warehouse keeps every version of every reported number, records when each version became known, and can answer "what did we know on this date?" for any past moment.

The data is the SEC's public [Financial Statement Data Sets](https://www.sec.gov/dera/data/financial-statement-data-sets), published quarterly.

## Results so far (2025 Q1 and 2026 Q1 loaded)

- **595,205** facts were reported more than once, and **24,370 of them (4.09%)** later changed value.
- The most revised concepts were diluted and basic earnings per share (421 and 408 revisions).
- Full-year 2024 revenue as known on 30 June 2025, compared with the latest figure, moved by up to 248% for a single company. That gap is the look-ahead bias a backtest would silently carry.

Queries and full tables: [`docs/findings.md`](docs/findings.md) and [`include/dbt/filings/analyses/findings.sql`](include/dbt/filings/analyses/findings.sql).

## How it works

```
SEC quarterly zip
      |
      v
load_quarter.py  (Airflow task load_raw)
      |  header contract, one transaction per quarter, row reconciliation
      v
Snowflake FIN.RAW: SUB_RAW, NUM_RAW, LOAD_LOG
      |
      v
dbt build  (Airflow task dbt_build, runs straight after the load)
      staging (views):        stg_filings, stg_numbers
      intermediate (table):   int_reported_facts
      marts (tables):         fct_fact_versions, fct_revisions, dim_company
                              + facts_as_of(ts) table function
```

### Loading

- The loader checks that every column it needs is in the file header and selects columns by name, so a reordered or wider file still loads and a missing column fails loudly.
- Each quarter is deleted and reloaded inside one transaction, so a re-run is safe.
- File rows are reconciled against loaded rows in `LOAD_LOG`, and the whole quarter is rolled back if more than 0.05% of rows are rejected.

### Modelling

- Staging types the raw text, keeps one row per filing and one row per documented key (the source contains a few duplicates under that key), and stamps every number with the SEC acceptance time of its filing.
- `int_reported_facts` keeps company-wide figures from 10-K and 10-Q reports and their amendments.
- `fct_fact_versions` is the core. It keeps every distinct value of each fact (company, concept, period, unit), with `known_from` (the filing's acceptance time) and `known_to` (when the next version arrived, or 9999-12-31). Re-reports that repeat the previous value are dropped. A correction that is later undone is still recorded.
- `facts_as_of(ts)` returns exactly what was known at any moment.
- `fct_revisions` lists every change with its old value, new value and relative size.

### Testing

- **Data tests** check the promises of the design: one latest version per fact, versions that chain with no gaps or overlaps, `facts_as_of()` far in the future equal to the latest versions, and no loaded quarter losing more than 0.05% of its rows. Schema tests cover keys, valid intervals, form types and the link to `dim_company`.
- **Unit tests** feed hand-made rows to the versioning logic, for example 100, 100, 120 must give two versions, and 50, 55, 50 must give three.
- `dbt build` runs models and tests together, so a quarter that breaks an invariant fails the Airflow run instead of reaching the marts.

### Orchestration

`filings_quarterly` runs at 06:00 UTC on the 15th of January, April, July and October and loads the quarter that just ended. A `quarter` parameter loads any quarter by hand. Catch-up is off (history is loaded with a deliberate backfill), only one run is active at a time, and failed tasks retry twice, 10 minutes apart.

### Security and cost

- The pipeline signs in as a Snowflake service user with key-pair authentication. It has no password, and its role owns one database only.
- dbt uses the same role and key, never a personal login.
- The extra-small warehouse suspends after 60 idle seconds, and a resource monitor suspends it at 20 credits a month.
- `.env`, key files and local settings have been in `.gitignore` since the first commit.

## Repository layout

```
dags/filings_quarterly.py        Airflow DAG: load_raw, then dbt_build
include/load_quarter.py          quarter loader
include/dbt/filings/             dbt project (models, tests, analyses)
snowflake/                       setup scripts: roles, warehouse, monitor, user, raw tables
docs/findings.md                 results
Dockerfile                       Airflow image with dbt in its own virtual environment
```

## Running it

You need Docker, the [Astro CLI](https://www.astronomer.io/docs/astro/cli/overview) and a Snowflake account.

1. In Snowflake, run `snowflake/01_setup.sql` as ACCOUNTADMIN. It creates the warehouse, resource monitor, pipeline role, database and service user.
2. Create an RSA key pair, keep the private key outside Git, and register the public key with `snowflake/02_key.sql`.
3. Run `snowflake/02_raw.sql` to create the raw tables and the load log.
4. Put the private key in `include/keys/` (ignored by Git) and create a `.env` file with:
   - `SNOWFLAKE_ACCOUNT` and `SNOWFLAKE_USER`
   - `SNOWFLAKE_PRIVATE_KEY_PATH`, the key's path inside the container, for example `/usr/local/airflow/include/keys/rsa_key.p8`
   - `SEC_USER_AGENT`, your name and email address. The SEC refuses downloads without it, and the loader stops with a clear message if it is missing.
5. Start Airflow with `astro dev start`, open http://localhost:8080 and trigger `filings_quarterly`, optionally with `quarter` set to a value such as `2025q1`.

## Next

Extending the project to an AWS data lake (S3, Glue, Athena, Apache Iceberg, Terraform).
