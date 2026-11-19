FROM astrocrpublic.azurecr.io/runtime:3.3-12
# dbt gets its own Python environment so its libraries cannot clash with Airflow's
RUN python -m venv dbt_venv && source dbt_venv/bin/activate && \
    pip install --no-cache-dir "dbt-core==1.12.*" "dbt-snowflake==1.12.*" && deactivate
ENV PATH="${PATH}:/usr/local/airflow/dbt_venv/bin"